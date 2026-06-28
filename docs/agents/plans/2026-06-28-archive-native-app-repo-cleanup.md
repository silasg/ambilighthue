---
date: 2026-06-28T19:06:19Z
git_commit: 0ba5ac65413898f492d5237535830898fe1c333d
branch: main
topic: "Archive native Apple app + web-app-first repo cleanup"
tags: [plan, archive, docs, native-app, webapp, repo-structure]
status: draft
---

# Archive native Apple app + web-app-first repo cleanup — Implementation Plan

## Overview

Move the frozen native Apple app (tvOS/iOS/watchOS) and its strategy/porting docs
into `archive/`, delete a dead duplicate source file, and reframe the repo root
around the Go web app — rewriting `README.md` to be web-app-first, surfacing the
Apple-Home-via-Apple-TV use case, and pointing at the existing `deploy/` compose
stack as the canonical homelab example. Records the decision as ADR-0003.

## Current State Analysis

- Native app lives at repo root: `ambilighthue/`, `ambilighthueTests/`,
  `ambilighthue.xcodeproj/`, `ambilighthuetests.xctestplan`, `Platforms/`,
  `AmbilightCore/`, `Podfile`, `Podfile.lock`, `icon/`, `build/` (gitignored).
- Native strategy/porting docs at root: `STRATEGY.md`,
  `APPLE_TV_CONTROL_OPTIONS.md`, `IOS_PORTING.md`. Stale `todo.md` (tvOS, mostly
  "done"; its open item "publish on github and remove this todo" is satisfied).
- Stray dead duplicate `SessionFactory.swift` at root (real one is
  `ambilighthue/SessionFactory.swift`, per CLAUDE.md).
- `README.md` is monorepo-style but ~110 of 129 lines document the tvOS app.
- `deploy/README.md` already documents the Apple-Home use case (strand 3) and the
  Homebridge `HTTP-SWITCH` compose stack (strand 4) thoroughly.

### Key Discoveries

- `project.pbxproj` has `projectDirPath = ""` / `projectRoot = ""` and **no
  absolute `/Users/...` paths** — fully relocatable.
- pbxproj references files by group paths relative to the `.xcodeproj`'s own
  directory; `packageReferences` lists **only the remote Mocker** package —
  `AmbilightCore`/`Platforms` are not wired into it by name (`grep` returns
  nothing), so there is no local-SPM-path to rewrite.
- The scheme and `ambilighthuetests.xctestplan` use **relative** container refs
  (`container:ambilighthue.xcodeproj`, `container:ambilighthuetests.xctestplan`,
  `container:../ambilighthue.xctestplan`) — all stay valid **iff the whole bundle
  moves together** preserving internal arrangement.
- pbxproj navigator references root `README.md`/`CLAUDE.md`/`todo.md` — these
  become dangling after the move (cosmetic, non-build).
- `AmbilightCore/Package.swift` deps are remote URLs only (Alamofire, Mocker) — no
  local path deps to fix.
- No native path references in `.github/`, `webapp/`, or `deploy/` — CI and the
  web app are unaffected.
- Inbound references to moving files exist in: `README.md`, `CLAUDE.md`,
  `deploy/README.md`, `docs/deployment-proposal.md`, and `docs/adr/0002-*`.
  Historical snapshots (`docs/agents/**`) are intentionally left untouched.

### ⚠️ Verification constraint

This is a **Linux environment with no `xcodebuild` and no `pod`**. The native move
**cannot be compiled or tested here**. Per the user's decision ("do everything
blind now"), the move is performed and committed unverified; the maintainer must
run `pod install` + `xcodebuild build`/`test` on macOS as a follow-up. This
mirrors ADR-0002's unverified status.

## Desired End State

```
ambilighthue/                 (repo root)
├── README.md                 ← web-app-first; use-case + deploy pointer
├── CLAUDE.md                 ← File Organization + commands updated to archive/
├── mise.toml  .github/  .gitignore
├── webapp/    deploy/    docs/
└── archive/                  ← frozen native app, self-contained
    ├── README.md             ← "archived; see /webapp"
    ├── ambilighthue/  ambilighthueTests/  ambilighthue.xcodeproj/
    ├── ambilighthuetests.xctestplan
    ├── Platforms/  AmbilightCore/  icon/
    ├── Podfile  Podfile.lock
    └── STRATEGY.md  APPLE_TV_CONTROL_OPTIONS.md  IOS_PORTING.md
```

Verify: web app still builds/tests via `mise run build` / `mise run test`; all
markdown cross-links resolve (no dangling relative links to moved files); root
`SessionFactory.swift` is gone; `git mv` preserved file history.

## What We're NOT Doing

- Not editing the body of ADR-0001/0002 (immutable records; ADR-0003 documents the
  move and relates to them).
- Not editing `docs/agents/**` handoffs/plans (historical snapshots).
- Not changing any `webapp/`, `deploy/`, or `.github/` code or workflows.
- Not building/testing the native app (impossible here — maintainer follow-up).
- Not rewriting git history, squashing, pushing, or creating PRs/tags.
- Not authoring a new compose stack — `deploy/` already has it.

## Implementation Approach

Do the verifiable doc work as its own commit first (Phases 1–3), then the unverified
native move as a separate commit (Phase 4) so the risky change is isolated and easy
to revert. ADR-0003 already drafted (Phase 0, done). All moves use `git mv` to
preserve history.

---

## Phase 1: Delete dead file + relocate native docs

### Overview
Low-risk file ops that the doc rewrite (Phase 2) depends on.

### Changes Required:

#### [x] 1. Delete stray duplicate
**File**: `SessionFactory.swift` (repo root)
**Changes**: `git rm SessionFactory.swift` (dead duplicate; real file moves with the app in Phase 4).

#### [x] 2. Create `archive/` and move native docs into it
**Changes**: `git mv STRATEGY.md APPLE_TV_CONTROL_OPTIONS.md IOS_PORTING.md archive/` (creates `archive/`).

#### [x] 3. Decide `todo.md`
**Changes**: `git rm todo.md` — deleted (user decision); its sole open actionable ("publish on github and remove this todo") is satisfied.

### Success Criteria:

#### Automated Verification:
- [x] `test ! -e SessionFactory.swift` (root copy gone)
- [x] `test -e ambilighthue/SessionFactory.swift` (real copy still present, pre-move)
- [x] `ls archive/STRATEGY.md archive/APPLE_TV_CONTROL_OPTIONS.md archive/IOS_PORTING.md` all exist
- [x] `git status` shows renames (R), not delete+add (history preserved)

#### Manual Verification:
- [x] `todo.md` deleted per user decision

---

## Phase 2: Rewrite root `README.md` (web-app-first + use case + compose pointer)

### Overview
Covers strands 2 (docs), 3 (use-case note), 4 (compose example) in the top-level README.

### Desired README shape (mockup)

```
# Ambilight Hue Control

Self-hostable web service (+ archived native Apple apps) to control a
Philips TV's ambilight over the local JointSpace API.

## Repository Layout
| # | Path        | What it is                                            |
| 1 | webapp/     | Go stdlib backend + vanilla PWA + REST API (the product) |
| 2 | deploy/     | Docker Compose: webapp + Homebridge + Caddy (homelab)    |
| 3 | docs/       | ADRs, deployment proposal, agent plans/handoffs          |
| 4 | archive/    | Frozen native Apple apps (tvOS/iOS/watchOS) — unmaintained|

## Quick start  → webapp/README.md ; deploy/ for homelab

## Use case: Apple Home via Apple TV
webapp REST API → Homebridge (homebridge-http-switch) → HomeKit →
Apple TV home hub → Home app / Siri / Watch / Shortcuts.
Canonical example: deploy/  (see deploy/README.md).

## Archived native apps  → archive/README.md
```

### Changes Required:

#### [x] 1. Replace `README.md`
**File**: `README.md`
**Changes**: Rewrite to web-app-first: lead with the web service; Repository
Layout table pointing at `webapp/`, `deploy/`, `docs/`, `archive/`; a concise
**Use case** section (the Homebridge→HomeKit→Apple TV chain) linking
`deploy/README.md` as the canonical compose example; an **Archived native apps**
section linking `archive/README.md`. Drop the long tvOS build/pairing prose (it
lives with the app in `archive/`).

### Success Criteria:

#### Automated Verification:
- [x] `grep -q 'archive/' README.md` and `grep -q 'deploy/README.md' README.md`
- [x] No link in `README.md` points to a root-level moved file

#### Manual Verification:
- [ ] README reads web-app-first; a newcomer lands on the web app
- [ ] Use-case section accurately describes the Apple-Home chain

---

## Phase 3: Fix inbound cross-links + add `archive/README.md`

### Overview
Repair links in live docs that point at moved files; add the archive landing note.

### Changes Required:

#### [x] 1. `archive/README.md` (new)
**Changes**: Short note: "This is the frozen native Apple app (tvOS/iOS/watchOS).
Unmaintained — the maintained product is the web app at `/webapp`." Link
`../README.md`, `../webapp/README.md`, and the local `STRATEGY.md` /
`APPLE_TV_CONTROL_OPTIONS.md` / `IOS_PORTING.md`. Note the macOS build needs
`pod install` from `archive/`.

#### [x] 2. `deploy/README.md`
**File**: `deploy/README.md`
**Changes**: `../STRATEGY.md` → `../archive/STRATEGY.md` (line ~5). Leave
`../docs/deployment-proposal.md` (unchanged location).

#### [x] 3. `docs/deployment-proposal.md`
**File**: `docs/deployment-proposal.md`
**Changes**: Update links `../STRATEGY.md` → `../archive/STRATEGY.md` and
`../APPLE_TV_CONTROL_OPTIONS.md` → `../archive/APPLE_TV_CONTROL_OPTIONS.md`. Add a
one-line **superseded** banner at top: this proposal's §2 ("keep the Xcode project
where it is") is reversed by ADR-0003; retained for the credential-audit history.

#### [x] 4. Verify intra-`archive/` links still resolve
**Changes**: `grep` the three moved docs for links to `webapp/`, `deploy/`,
`docs/`, or `ambilighthue/` that now need a `../` prefix; fix any found. Links
*between* the three moved docs are unchanged (they moved together).

### Success Criteria:

#### Automated Verification:
- [x] `test -e archive/README.md`
- [x] No live doc links to a root path that no longer exists
- [x] Link-check moved docs: no bare `webapp/`/`deploy/`/`docs/` links in `archive/*.md`

#### Manual Verification:
- [ ] Click through README → deploy/README → archive/README; all links resolve

---

## Phase 4: Move the native app bundle (unverified — maintainer builds on macOS)

### Overview
The single risky structural change, isolated in its own commit. Move the whole
Xcode/SPM bundle into `archive/` as one unit so all relative refs survive.

### Changes Required:

#### [x] 1. Move tracked native files with history
**Changes**:
```bash
git mv ambilighthue ambilighthueTests ambilighthue.xcodeproj \
       ambilighthuetests.xctestplan Platforms AmbilightCore \
       Podfile Podfile.lock icon archive/
```
(`Pods/`, `build/`, `ambilighthue.xcworkspace/` are gitignored and not moved by
git; the maintainer regenerates `Pods/` + workspace via `pod install` in `archive/`.)

#### [x] 2. Update `.gitignore`
**File**: `.gitignore`
**Changes**: `Pods/`→`archive/Pods/`, `ambilighthue.xcworkspace/`→
`archive/ambilighthue.xcworkspace/`, `build/`→`archive/build/`. Leave `.chroma/`,
`.vscode/`, `.claude/`.

#### [x] 3. Update `CLAUDE.md`
**File**: `CLAUDE.md`
**Changes**: Prefix native paths with `archive/` in "File Organization", the
build/test commands (`-workspace archive/ambilighthue.xcworkspace ...`, run from
`archive/`), the stray-`SessionFactory.swift` note (now deleted — update or
remove), and `ambilighthue/SessionFactory.swift` → `archive/ambilighthue/...`.
Add a note that the web app is the primary product.

### Success Criteria:

#### Automated Verification:
- [x] `git status` shows the moves as renames (R)
- [x] `ls archive/ambilighthue.xcodeproj/project.pbxproj` exists
- [x] CLAUDE.md native path refs all show `archive/` prefix
- [x] `mise run build && mise run test` (web app) still pass — proves no web-app regression
- [x] `.gitignore` bare entries re-scoped to `archive/` (stale root artifacts removed)

#### Manual Verification (maintainer, on macOS — REQUIRED before relying on the archive):
- [ ] `cd archive && pod install` regenerates `archive/ambilighthue.xcworkspace`
- [ ] `xcodebuild -workspace archive/ambilighthue.xcworkspace -scheme ambilighthue -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build` succeeds
- [ ] `xcodebuild test ...` runs the xctestplan's `selectedTests`
- [ ] If a path ref broke, fix in `project.pbxproj`/Podfile and amend the Phase 4 commit

---

## Manual Confirmation Points

The implementing agent runs all four phases, then pauses for manual confirmation
after the final phase (no per-phase pauses). The native build itself still
requires the separate macOS verification listed under Phase 4.

## Testing Strategy

### Automated (here):
- Web app unaffected: `mise run build`, `mise run test`.
- Link/grep assertions per phase (above).
- `git status` rename checks for history preservation.

### Manual (maintainer, macOS):
- `pod install` + `xcodebuild build`/`test` from `archive/` — the only way to
  confirm the Xcode move; cannot be done in this environment.

## Performance Considerations

None — pure file relocation + docs.

## Migration Notes

- All moves via `git mv` (history preserved). The Xcode bundle moves as one unit so
  relative scheme/testplan/pbxproj refs stay valid.
- Reversal: `git mv archive/<each> .` + revert `.gitignore`/doc edits (ADR-0003
  §Reversibility).
- Commit grouping: Phases 1–3 (verifiable docs) in one commit; Phase 4 (unverified
  native move) in a separate commit. Commit only when you ask.

## References

- ADR: `docs/adr/0003-archive-native-app-webapp-first-repo.md`
- Handoff: `docs/agents/handoffs/2026-06-28-repo-cleanup.md`
- Related ADRs: `docs/adr/0001-*` (webapp), `docs/adr/0002-*` (shared core/port)
- Existing use-case + compose docs: `deploy/README.md`
- Superseded layout guidance: `docs/deployment-proposal.md` §2
