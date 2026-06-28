---
date: 2026-06-28T15:32:17+00:00
git_commit: f0351ba1db7b3d26fefcc44b805f167b46e8b8c1
branch: experiments
topic: "Publish to GitHub & deploy the web app (history rewrite, monorepo consolidation, CI, homelab deploy)"
tags: [plan, git-history, ci, docker, deployment, webapp]
status: draft
---

# Publish & Deploy Implementation Plan

## Overview

Turn this never-released local repo into a published GitHub monorepo whose **web app** (Go REST backend + PWA) is the default deployment to a homelab (Docker via GHCR, fronted by Caddy, controlled through Homebridge → HomeKit), while keeping the **tvOS** and **iOS/iPadOS/watchOS** apps in the same repo for the future.

A **real Philips TV credential was committed in early history**, so the repo must be **rewritten and the credential rotated before the first push**. The two agent worktrees from prior sessions must be removed first (their branches are already committed and are kept).

## Execution model (IMPORTANT — read first)

This plan is executed **in a fresh session** by a lean **orchestrator** that runs each phase via a **dedicated subagent** for context management. Rules for the orchestrator:

- Do **one phase per subagent**. Give each subagent only the context in that phase plus the files it names. Do not let the orchestrator accumulate file contents — keep its context for decisions and verification only.
- Phases **0 → 4** are sequential and order-critical (backup → cleanup → **destructive rewrite** → rotate → consolidate). Do not parallelize them.
- Phases **5, 6, 7** (webapp `BASE_PATH`, deploy assets, CI workflow) are independent of each other and of the rewrite; they may run as parallel subagents **after** Phase 4, or even before the rewrite on their branches — but they MUST be merged into `main` only *after* Phase 2 so rewritten history is the base.
- Phase **8** (create repo + push) is last and is a hard manual-confirmation gate.
- Each subagent commits its own work (conventional commits) and reports a short summary back; the orchestrator verifies success criteria before starting the next phase.
- The orchestrator must **stop and ask** at every Manual Confirmation Point (see end of plan) — these involve destructive or irreversible/outward-facing actions.

## Current State Analysis

Verified git state at planning time (hashes are **pre-rewrite** and will change in Phase 2):

- Branches: `experiments` (current, `f0351ba`), `main` (`2d784e8`), `port/ios` (`af1dd0e`), `port/webapp` (`de7b844`), plus stale `worktree-agent-a3bb4874e2314b1cb` and `worktree-agent-a811ce518f153b794`.
- **Worktrees still mounted**: `.claude/worktrees/agent-a3bb4874e2314b1cb` (port/webapp) and `.claude/worktrees/agent-a811ce518f153b794` (port/ios). These block `git filter-repo`.
- `main` ↔ `experiments` **diverged** by one commit each (not ancestor): experiments has `f0351ba` (pairing empty-response bugfix); main has `2d784e8` (ViewInspector `.alert2/.sheet2` test work). Both wanted.
- `port/ios` and `port/webapp` are each `experiments` + 1 commit (based on experiments, in disjoint dirs: `AmbilightCore/`+`Platforms/` vs `webapp/`+root `mise.toml`).
- **Stash** `stash@{0}` = user WIP on main (adds `README.md` +100 lines, `project.pbxproj` +2). **Verified clean** of leaked strings. Keep unless the user says otherwise.
- Uncommitted on `experiments`: `M ambilighthue.xcodeproj/project.pbxproj`; untracked `APPLE_TV_CONTROL_OPTIONS.md`, `STRATEGY.md`, `CLAUDE.md`, `README.md`, `docs/`, `.claude/`.
- `git filter-repo` is **NOT installed** (pip package; sandbox/container install is fine).
- Existing docs to reuse as source of truth: `docs/deployment-proposal.md`, `STRATEGY.md`, `APPLE_TV_CONTROL_OPTIONS.md`, `webapp/README.md` (on `port/webapp`), `IOS_PORTING.md` (on `port/ios`).

### Key Discoveries
- Leaked, reachable-in-history credentials to purge (`docs/deployment-proposal.md` §3): password/auth_key `REDACTED`, username `REDACTED`, home IP `TV_IP`. Not in any current tip; only in history (`adb2e24`, `b11bda8`, `b2c071e`, `a91216e`).
- Expected public constants, **do not touch**: HMAC key `oEC9Uhg5xbg566mpYPjhoWUwFtFAwTFoTW1By0vaOD4=`, pylips sample auth_key `a8d1b59…`.
- Both ports added a `docs/adr/0001-*.md` → ADR-number collision to resolve in consolidation.
- Homelab is **Intel/AMD**; build multi-arch `linux/amd64,linux/arm64`.

## Desired End State

- A GitHub repo `ambilighthue` (private) on a single `main` branch containing all three apps + docs + `deploy/` + CI, with **no leaked credential anywhere in history** (`git log --all -S<string>` returns nothing for all three strings).
- The leaked TV pairing **rotated** (re-paired) so the old credential is dead.
- A GH Actions workflow that builds & pushes a multi-arch web-app image to GHCR on `webapp/**` changes.
- The web app supports a configurable `BASE_PATH` so it works behind Caddy at a sub-path, with a working PWA and Shortcuts-friendly REST API.
- A `deploy/` compose stack (webapp + Homebridge + Caddy) ready to run on the homelab.

## What We're NOT Doing

- Not relocating the Xcode project into a subdir (would require unverifiable `pbxproj` surgery — no Xcode here).
- Not building/signing the Apple apps in CI (no macOS runners in scope; tvOS/iOS stays source-only as documented in `IOS_PORTING.md`).
- Not building the Docker image locally (no Docker in the dev sandbox — CI builds it).
- Not implementing watch↔phone config sync, HA, or the Homebridge plugin code itself (we only provide config/compose; Homebridge uses the existing `homebridge-http-switch`).
- Not deleting the user's `stash@{0}` unless explicitly confirmed.

## Implementation Approach

Backup → make the tree safe for a rewrite (commit pending work, remove worktrees) → rewrite history to purge the credential → rotate the credential (human) → consolidate everything onto `main` → build the deployment-enabling changes (BASE_PATH, deploy assets, CI) → create the repo and push. Destructive/irreversible steps are gated behind manual confirmation and a verified backup.

---

## Phase 0: Safety backup & tooling

### Overview
Make the destructive rewrite reversible and install tooling. **Nothing here is destructive.**

### Changes Required:

#### [x] 1. Full mirror backup of the repo
**Action**: Create a complete backup outside the working tree before any later phase mutates history.
```bash
git -C /Users/silas.graffy/Projects/ambilighthue bundle create /tmp/ambilighthue-backup-pre-rewrite.bundle --all
cp -r /Users/silas.graffy/Projects/ambilighthue/.git /tmp/ambilighthue-git-backup   # belt-and-suspenders
```

#### [x] 2. Install git-filter-repo
```bash
pip3 install git-filter-repo && git filter-repo --version
```

### Success Criteria:
#### Automated Verification:
- [x] `git bundle verify /tmp/ambilighthue-backup-pre-rewrite.bundle` succeeds
- [x] `git filter-repo --version` prints a version
#### Manual Verification:
- [x] Backup location noted and confirmed restorable (`/tmp/ambilighthue-backup-pre-rewrite.bundle` + `/tmp/ambilighthue-git-backup`)

### Execution (subagent)
Single short subagent: "Create the bundle + .git backup, install git-filter-repo, report versions and backup paths." Read-only w.r.t. project files.

---

## Phase 1: Commit pending work & remove worktrees

### Overview
Get to a clean working tree on every branch and remove the two agent worktrees so `git filter-repo` can run. Branch refs `port/ios` / `port/webapp` are kept.

### Changes Required:

#### [x] 1. Ignore agent/worktree dirs
**File**: `.gitignore`
**Changes**: Append `.claude/` so the worktrees/settings are never committed.

#### [x] 2. Commit loose work on `experiments`
**Changes**: Stage the specific files (NEVER `git add -A`) and commit:
```bash
git add .gitignore APPLE_TV_CONTROL_OPTIONS.md STRATEGY.md CLAUDE.md README.md docs/ ambilighthue.xcodeproj/project.pbxproj
git commit -m "docs: add control-options research, strategy, deployment plan; ignore .claude"
```
Note: a different `README.md` exists in the stash; reconcile in Phase 4, not here.

#### [x] 3. Remove the two agent worktrees (keep their branches)
```bash
git worktree remove .claude/worktrees/agent-a3bb4874e2314b1cb --force
git worktree remove .claude/worktrees/agent-a811ce518f153b794 --force
git worktree prune
```

#### [x] 4. Delete the stale worktree-agent branches
```bash
git branch -D worktree-agent-a3bb4874e2314b1cb worktree-agent-a811ce518f153b794
```

#### [x] 5. Drop the superseded stash (Decision A)
```bash
git stash drop stash@{0}
```
It's an older README draft (superseded by the root `README.md` on `experiments`) plus a trivial 2-line `pbxproj` change; fully recoverable from the Phase 0 `.git` backup if ever needed.

### Success Criteria:
#### Automated Verification:
- [x] `git worktree list` shows only the main working tree
- [x] `git branch` lists `experiments`, `main`, `port/ios`, `port/webapp` and no `worktree-agent-*`
- [x] `git status --short` is clean (except the intentionally-kept stash)
- [x] `git rev-parse port/ios port/webapp` still resolve
#### Manual Verification:
- [x] Confirm `.claude/` is gitignored and not staged

### Execution (subagent)
One subagent with this phase's commands + the file list. Must use explicit `git add <paths>` (per repo git rules), not `-A`.

---

## Phase 2: Rewrite history to purge the leaked credential  ⚠️ DESTRUCTIVE

### Overview
Purge the three strings from all reachable history across all refs. Requires Phase 0 backup and Phase 1 clean state. No stop-and-ask gate (per user: backup is sufficient) — proceeds on automated verification, but MUST confirm the Phase 0 backup exists before running filter-repo.

### Changes Required:

#### [x] 1. Replacement spec
**File**: `/tmp/replacements.txt`
```
REDACTED==>REDACTED
REDACTED==>REDACTED
TV_IP==>TV_IP
```

#### [x] 2. Run the rewrite (all refs)
```bash
git filter-repo --replace-text /tmp/replacements.txt --force
```
Note: filter-repo removes any configured remote (none yet) and rewrites the stash ref. If the kept stash is mangled, re-create it from the Phase 0 backup or accept its loss per Manual Confirmation Point A.

#### [x] 3. Verify purge across all refs
```bash
for s in REDACTED REDACTED TV_IP; do
  echo "== $s =="; git log --all -S"$s" --oneline; done   # each must print nothing
```

### Success Criteria:
#### Automated Verification:
- [x] All three `git log --all -S<string>` searches return empty
- [x] `git grep -n REDACTED $(git rev-list --all) -- 2>/dev/null | head` shows the redaction took effect in the historical commits
- [x] All kept branches still exist (`git branch` shows experiments/main/port/ios/port/webapp)
- [x] Repo builds/tests still pass on `port/webapp` tip: `mise exec -- go test ./...` (run from webapp dir)
#### Manual Verification:
- [x] Spot-check an early commit shows `REDACTED`/`TV_IP`, not the secrets (verified `1096b4c:helloworld/NetworkCall.swift`)

### Execution (subagent)
One subagent. It must re-verify the Phase 0 backup exists before running filter-repo, then run and verify. If verification fails, STOP and report — do not proceed.

---

## Phase 3: Rotate the leaked credential  (✅ ALREADY DONE)

### Overview
Purging history is insufficient; the credential may already be cloned/backed up, so it had to be invalidated on the TV. **The user completed this before this plan runs** — the TV pairing (username `REDACTED` + its auth_key) has been reset/re-paired and the old credential is dead.

### Changes Required:
#### [x] 1. Re-pair the TV — DONE by the user.

### Success Criteria:
#### Manual Verification:
- [x] TV re-paired; old credential no longer valid (confirmed by user).

### Execution
No action for the orchestrator — already satisfied. No longer gates Phase 8.

---

## Phase 4: Consolidate everything onto `main` (monorepo)

### Overview
Reconcile the `main`/`experiments` divergence and fold both ports into `main` as the single integration branch, on top of rewritten history.

### Changes Required:

#### [x] 1. Merge the divergent line + ports into `main`
**Recommended strategy** (preserves all commits):
```bash
git switch main
git merge experiments      # brings the pairing bugfix + the new docs commit
git merge port/webapp      # webapp/ + mise.toml
git merge port/ios         # AmbilightCore/ + Platforms/ + IOS_PORTING.md
```
Expect clean merges (disjoint dirs); resolve any `README.md`/`project.pbxproj` overlap by keeping the most complete version.

#### [x] 2. Resolve the ADR-number collision
**Files**: `docs/adr/0001-*.md` (two of them) → renumber one to `0002-*.md`; fix any cross-references.

#### [x] 3. Reconcile README / docs
Merge the stash's README content (if kept) and the experiments README into one root `README.md` describing the monorepo (apps + webapp + deploy).

#### [x] 4. Confirm target layout exists
`/ambilighthue` (tvOS), `/AmbilightCore` + `/Platforms` (iOS/watchOS), `/webapp`, `/docs`, `mise.toml`. (`/deploy` and `/.github` arrive in later phases.)

### Success Criteria:
#### Automated Verification:
- [x] `git switch main && git status` clean; all three apps' dirs present on `main`
- [x] Exactly one ADR per number under `docs/adr/`
- [x] `mise exec -- go test ./...` passes from `webapp/` on `main`
- [x] No leaked strings on `main`: the three `-S` searches still empty
#### Manual Verification:
- [x] `main` is the intended monorepo state; tvOS sources untouched/intact

### Execution (subagent)
One subagent given: this phase, `docs/deployment-proposal.md` §2, and the branch facts. It performs the merges, ADR renumber, README reconcile; commits; reports conflicts it resolved.

---

## Phase 5: Add `BASE_PATH` support to the web app

### Overview
Make the Go backend + PWA work behind Caddy at a sub-path (e.g. `/ambilight`). Independent of the rewrite. TDD.

### Changes Required:

#### [x] 1. Base-path-aware server
**Files**: `webapp/main.go`, `webapp/internal/server/*`
**Changes**: Read `BASE_PATH` env (default `""`). Register all routes under it. Optionally honor `X-Forwarded-Prefix` from Caddy.

#### [x] 2. Inject base path into the served frontend
**Files**: `webapp/internal/server/*` (HTML templating/serving), `webapp/web/index.html`, `webapp/web/app.js`
**Changes**: Emit the base path to the page (`<base href>` or `window.BASE_PATH`); `app.js` builds API URLs as `${BASE_PATH}/api/...`.

#### [x] 3. PWA scope under the base path
**Files**: `webapp/web/manifest.webmanifest` (or generated), `webapp/web/sw.js`
**Changes**: `scope` and `start_url` = base path; serve and register `sw.js` within scope.

### Success Criteria:
#### Automated Verification:
- [x] New tests written first and passing: `mise exec -- go test ./...` (cover routing with and without `BASE_PATH`, manifest scope, SW path)
- [x] `mise exec -- go build ./...` succeeds
- [x] Smoke run with `BASE_PATH=/ambilight`: `/ambilight/api/health` 200, `/ambilight/` serves the PWA, manifest `scope` = `/ambilight/` (orchestrator re-verified independently)
#### Manual Verification:
- [ ] PWA installs and controls state when served behind a sub-path

### Execution (subagent)
One subagent on `main` (or a short-lived branch merged into main). Must follow TDD (tests first) and build/test via mise. Reads `webapp/README.md` for current structure.

---

## Phase 6: Deployment assets (`deploy/`)

### Overview
Provide a ready-to-run homelab stack: webapp + Homebridge + Caddy.

### Changes Required:

#### [x] 1. Compose stack
**File**: `deploy/docker-compose.yml` — `webapp` (GHCR image, `pull_policy: always`, env `BASE_PATH`/`CONFIG_PATH`/`API_TOKEN`, volume for `/data`), `homebridge`, `caddy`; one network.

#### [x] 2. Caddy config
**File**: `deploy/Caddyfile` — TLS + `handle /ambilight/* { reverse_proxy webapp:8080 { header_up X-Forwarded-Prefix /ambilight } }`.

#### [x] 3. Homebridge example
**File**: `deploy/homebridge/config.example.json` — `homebridge-http-switch` accessory pointing at `http://webapp:8080/api/{on,off,state}` (+ `X-API-Token`), with status polling.

#### [x] 4. Env example + README
**Files**: `deploy/.env.example`, `deploy/README.md` (bring-up steps, GHCR pull, HomeKit add-to-Home, Shortcuts examples).

### Success Criteria:
#### Automated Verification:
- [x] Docker unavailable here; instead: compose YAML parses (PyYAML — 3 services), Homebridge `config.example.json` passes `json.tool`, Caddyfile/compose/README agree on the `/ambilight` BASE_PATH approach
#### Manual Verification:
- [ ] On the homelab: stack comes up, ambilight appears in Home app via Homebridge, on/off works

### Execution (subagent)
One subagent. Reads `STRATEGY.md` + `docs/deployment-proposal.md` §5–§6. Cannot fully verify without Docker — must say so.

---

## Phase 7: CI — build & publish web-app image to GHCR

### Overview
GitHub Actions builds a multi-arch image on `webapp/**` changes and pushes to GHCR.

### Changes Required:

#### [ ] 1. Workflow
**File**: `.github/workflows/webapp-docker.yml`
**Changes**: triggers `push` to `main` with `paths: [webapp/**]`, `v*` tags, `workflow_dispatch`; `permissions: { contents: read, packages: write }`; QEMU + buildx; `docker/login-action` to `ghcr.io` with `GITHUB_TOKEN`; `docker/metadata-action` (`latest`, `sha-`, semver); `docker/build-push-action` context `webapp/`, `platforms: linux/amd64,linux/arm64`.

### Success Criteria:
#### Automated Verification:
- [ ] `actionlint .github/workflows/webapp-docker.yml` passes (if available) or YAML lints
#### Manual Verification:
- [ ] After first push, the workflow succeeds and a multi-arch image appears at `ghcr.io/<owner>/ambilighthue/webapp`
- [ ] GHCR package set to public

### Execution (subagent)
One subagent. Cannot run Actions locally — validates syntax and documents the post-push check.

---

## Phase 8: Create GitHub repo & push  (MANUAL GATE)

### Overview
Publish. **Only after Phase 2 (verified) and Phase 3 (credential rotated).** Irreversible/outward-facing — Manual Confirmation Point D.

### Changes Required:

#### [ ] 1. Create the repo (needs explicit go-ahead — `gh` has side effects)
```bash
gh repo create ambilighthue --private --source . --remote origin
```
(filter-repo removed remotes; re-add `origin` as needed.)

#### [ ] 2. Final pre-push secret scan
```bash
for s in REDACTED REDACTED TV_IP; do git log --all -S"$s" --oneline; done   # all empty
```

#### [ ] 3. Push
```bash
git push -u origin main
# optionally: git push origin port/ios port/webapp   # or delete them post-merge
git push --tags
```

#### [ ] 4. Post-push
- [ ] Set the GHCR package visibility to public after the first image build.

### Success Criteria:
#### Manual Verification:
- [ ] Repo visible on GitHub with clean history (no secrets)
- [ ] First Actions run green; image published
- [ ] Homelab can `docker compose pull` the image

### Execution
Orchestrator-driven with explicit user confirmation per command that has side effects (repo create, push). No autonomous pushing.

---

## Manual Confirmation Points

The implementing agent MUST pause for explicit user confirmation at:

- **D — Create repo & push (Phase 8):** outward-facing/irreversible; confirm per side-effecting command, and only after Phase 2 (rewrite) is verified.

Resolved / removed (per user):
- **A — Stash disposition:** decided — **drop `stash@{0}`** in Phase 1 (it's an older, superseded README draft + a trivial pbxproj change; preserved in the Phase 0 `.git` backup). No pause needed.
- **B — Pre-rewrite pause:** not required; Phase 0 backup is sufficient. Phase 2 runs on automated verification.
- **C — Credential rotation:** already completed by the user (Phase 3 done). No longer gates push.

All other phases (0, 1, 4, 5, 6, 7) proceed on automated verification, reporting back to the orchestrator.

## Testing Strategy

### Automated:
- Phase 2/4/8: pickaxe searches for the three strings return empty across all refs.
- Phase 4/5: `mise exec -- go test ./...` green in `webapp/`.
- Phase 5: new routing/manifest/SW tests (written first) for `BASE_PATH` on and off.
- Phase 6/7: compose/Caddyfile/workflow lint/validate where tooling exists.

### Manual:
- Phase 3: TV re-pair confirmed.
- Phase 5/6: PWA installs and toggles behind the Caddy sub-path; HomeKit tile works from the Apple TV Home app.
- Phase 7/8: first CI run publishes the multi-arch image; homelab pulls and runs it.

## Migration / Rollback Notes

- Rollback for the rewrite: restore from `/tmp/ambilighthue-backup-pre-rewrite.bundle` (`git clone` the bundle) or the `.git` copy. Keep the backup until after a successful, verified push.
- The rewrite changes all commit hashes; any external reference to old hashes (including this plan's "pre-rewrite" hashes) is historical only.

## References

- `docs/deployment-proposal.md` — the agreed proposal (decisions, §3 audit, §4–§6 CI/deploy/Caddy).
- `STRATEGY.md` — the chosen lightweight control strategy.
- `APPLE_TV_CONTROL_OPTIONS.md` — options research.
- `webapp/README.md` (on `port/webapp`) — current web app structure & REST API.
- `IOS_PORTING.md` (on `port/ios`) — manual Xcode steps for the Apple ports.
- Credential audit verdict: this conversation's history-scan (purge + rotate).
