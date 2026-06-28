# Deployment & Repository Proposal

> **Historical / partially superseded.** This proposal's §2 ("keep the Xcode
> project where it is") was reversed by [ADR-0003](adr/0003-archive-native-app-webapp-first-repo.md),
> which moved the native app into `archive/`. The publish/deploy work it describes
> is complete; the document is retained for the credential-audit record in §3.

Plan for publishing this project to GitHub and deploying the web app to the homelab, while keeping the tvOS and iOS/watchOS apps around. Companion to [`../archive/STRATEGY.md`](../archive/STRATEGY.md) and [`../archive/APPLE_TV_CONTROL_OPTIONS.md`](../archive/APPLE_TV_CONTROL_OPTIONS.md).

## 1. Decisions (resolved)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Repo structure | **Monorepo, single `main`** — apps separated by directory (not branch-per-app) |
| 2 | GitHub repo | name `ambilighthue`, **private repo**, **public** GHCR package |
| 3 | Git history | **Keep the history, but a rewrite is REQUIRED first** — a real TV credential was committed in early commits (see §3). Purge before the first push. |
| 4 | Image architecture | **Multi-arch `linux/amd64` + `linux/arm64`** (homelab is Intel/AMD; cross-built via QEMU in CI) |
| 5 | Reverse-proxy base path | **Configurable** via `BASE_PATH`, default `/ambilight` in the homelab compose |

## 2. Repository layout (monorepo on `main`)

Keep the Xcode project where it is — relocating it requires `pbxproj` path surgery that can't be verified without Xcode.

```
/ambilighthue              tvOS app (unchanged)
/AmbilightCore /Platforms  iOS + iPadOS + watchOS port (from port/ios)
/webapp                    Go backend + PWA (the deployable, from port/webapp)
/deploy                    docker-compose, Caddy snippet, Homebridge config example
/docs                      research, STRATEGY, ADRs, this proposal
/.github/workflows         CI
mise.toml, README.md
```

Consolidation steps:

| # | Step |
|---|------|
| 1 | Merge `port/webapp` and `port/ios` into `main` (changes are in disjoint directories — expect clean merges) |
| 2 | Renumber the colliding ADRs (both ports added `docs/adr/0001-*`); one becomes `0002` |
| 3 | Commit the loose docs currently on `experiments` (`STRATEGY.md`, `APPLE_TV_CONTROL_OPTIONS.md`, this file, `CLAUDE.md`, `README.md`) and the modified `project.pbxproj` |
| 4 | Add `/deploy` (compose + Caddy + Homebridge example) and `/.github/workflows` |

## 3. Credential audit & history rewrite — REQUIRED

A read-only audit scanned all 45 commits across every ref. **Verdict: a history rewrite is required before the first push.** Early app source committed a real Philips TV pairing credential in plaintext. The values are not in any current branch tip (they were removed when config moved to `UserDefaults`), but they remain reachable in history, so a normal `git push` would publish them.

**Strings to purge from all history:**

| # | String | What | Action |
|---|--------|------|--------|
| 1 | `REDACTED` | Real paired TV password / auth_key | **REQUIRED** |
| 2 | `REDACTED` | Real paired TV username | **REQUIRED** |
| 3 | `TV_IP` | Home LAN IP (Fritz!Box range) | Recommended (same lines; low risk — private/non-routable) |

Found in early files `helloworld/NetworkCall.swift`, `ambilighthue/ambilightHueApp.swift`, `ambilighthue/AmbilightHueControlView.swift` (commits `adb2e24`, `b11bda8`, `b2c071e`, `a91216e` and intermediate snapshots). The HMAC key `oEC9…=` and the pylips sample `a8d1b59…` auth_key are **expected public constants** — no action.

**Rewrite procedure (before first push):**

1. Install/use **`git filter-repo`** (preferred over BFG). Run against a fresh `--mirror` clone.
2. `replacements.txt`:
   ```
   REDACTED==>REDACTED
   REDACTED==>REDACTED
   TV_IP==>TV_IP
   ```
   then `git filter-repo --replace-text replacements.txt`.
3. Drop the stale `worktree-agent-*` branches and `refs/stash` so they don't reintroduce the strings.
4. Verify with a pickaxe search (`git log --all -S<string>` returns nothing) before pushing.

**⚠️ Rotation is also required — purging is not enough.** The leaked username/password may already exist in a clone or backup. **Re-pair the TV** (reset its pairing / re-run the app's pairing flow) so the leaked `REDACTED` + auth_key are invalidated. This is a manual step only you can do on the TV. The IP is low-risk but scrubbed for hygiene.

## 4. CI — build & publish the Docker image (GitHub Actions → GHCR)

| # | Item | Choice |
|---|------|--------|
| 1 | Registry / image | `ghcr.io/<owner>/ambilighthue/webapp`, package made **public** (no secrets baked in — TV creds are mounted at runtime) |
| 2 | Auth | built-in `GITHUB_TOKEN` with `permissions: packages: write` — no extra secrets |
| 3 | Triggers | push to `main` filtered to `paths: webapp/**`; `v*` tags; manual `workflow_dispatch` |
| 4 | Build | `docker/setup-qemu-action` + `setup-buildx-action`, `--platform linux/amd64,linux/arm64`, build context `webapp/`, `docker/metadata-action` for tags (`latest`, `sha-<short>`, semver) |

Workflow file: `.github/workflows/webapp-docker.yml`.

(Optional, later: a macOS-runner job to at least `swift build` the `AmbilightCore` package. Building/signing the full Apple apps in CI is out of scope.)

## 5. Homelab deployment

One docker network; three services. **Homebridge calls the webapp directly** (`http://webapp:8080`), bypassing Caddy, so it never deals with base paths. Caddy fronts only the human/Shortcuts-facing UI and provides TLS.

```yaml
# deploy/docker-compose.yml (sketch)
services:
  webapp:
    image: ghcr.io/<owner>/ambilighthue/webapp:latest
    pull_policy: always
    environment: [ "BASE_PATH=/ambilight", "CONFIG_PATH=/data/config.json", "API_TOKEN=..." ]
    volumes: [ "webapp-data:/data" ]
  homebridge:
    # http-switch plugin → http://webapp:8080/api/{on,off,state} (+ X-API-Token)
  caddy:
    # TLS + reverse proxy; one entry per homelab service
```

Optional **Watchtower** to auto-pull new images on push.

## 6. Caddy sub-path support — webapp change required

The Go app + PWA currently assume they are served at root `/`. Behind Caddy at e.g. `https://home.example.tld/ambilight/`, the API URLs, asset paths, PWA `manifest` `scope`/`start_url`, and the **service-worker scope** all break unless the app is base-path aware.

Webapp work item (`port/webapp`):

| # | Change |
|---|--------|
| 1 | `BASE_PATH` env (default `""` = root); register routes under it |
| 2 | Inject base path into served HTML so `app.js` builds correct `/<base>/api/...` calls (`<base href>` or `window.BASE_PATH`) |
| 3 | Set manifest `scope` + `start_url` to the base path |
| 4 | Serve `sw.js` within scope and register it with the base-path scope |
| 5 | Optionally honor Caddy's `X-Forwarded-Prefix` header so the prefix isn't hard-coded |

Caddy side:
```
handle /ambilight/* {
  reverse_proxy webapp:8080 { header_up X-Forwarded-Prefix /ambilight }
}
```

Side benefit: **Caddy's automatic HTTPS resolves the watchOS-Shortcuts HTTPS requirement** noted in `STRATEGY.md`.

## 7. Proposed sequence

| # | Phase | Depends on |
|---|-------|------------|
| 1 | **History rewrite** to purge the leaked credential (§3) + **re-pair the TV** to rotate it | — |
| 2 | Consolidate branches into `main` (§2) — do this *after* the rewrite so it's not reintroduced | #1 |
| 3 | Add `BASE_PATH` support to the webapp (§6) + tests | — |
| 4 | Add `/deploy` compose + Caddy + Homebridge example (§5) | #3 |
| 5 | Add GH Actions workflow (§4) | #2 |
| 6 | Create the GitHub repo and push (needs explicit go-ahead — `gh` creates a remote) | #1–#5 |

Nothing in phases 2–6 is started yet; this document is for review.
