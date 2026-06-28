# Ambilight Hue — Web App

A tiny REST backend plus installable PWA that turns a Philips TV's ambilight
(`HueLamp`) on and off. It is a dependency-free Go port of the TV-control logic
from the tvOS app in this repo. Stdlib only, single static binary, ~10-15 MB
container.

The Philips JointSpace protocol (pairing via HMAC-SHA1 signature, then HTTP
Digest auth over HTTPS on port 1926 with the TV's self-signed cert) is
reimplemented in `internal/tv`. See `docs/adr/0001-*.md` for the rationale.

## Layout

```
webapp/
  main.go                  entrypoint: env config + embeds web/ + wires deps
  internal/tv/             JointSpace client: signature, digest auth, pair, state
  internal/store/          JSON-file credential persistence (survives restarts)
  internal/server/         REST handlers + static PWA serving
  web/                     PWA: index.html, app.js, style.css, manifest, sw.js, icons
  Dockerfile               multi-stage -> distroless/static
mise.toml                  (repo root) pins Go + build/test/run/docker tasks
```

## Build, test, run (via mise)

Go is provided by mise; nothing else is required.

```bash
mise install                 # installs Go 1.26.4 (pinned in mise.toml)

# Tasks (run from repo root):
mise run build               # go build ./...
mise run test                # go test ./...
mise run run                 # runs locally on :8080, config in ./webapp/data/config.json
mise run docker-build        # docker build (requires Docker)

# Or directly:
mise exec -- go test ./...   # from inside webapp/
```

## Configuration (environment variables)

| #  | Var           | Default              | Purpose                                                  |
|----|---------------|----------------------|----------------------------------------------------------|
| 1  | `PORT`        | `8080`               | Listen port (plain HTTP).                                 |
| 2  | `CONFIG_PATH` | `/data/config.json`  | Where paired credentials are persisted.                  |
| 3  | `API_TOKEN`   | _(unset)_            | If set, all `/api/*` except `/api/health` require it.    |

When `API_TOKEN` is set, send it as the `X-API-Token` header (or `?token=...`
query param for convenience).

## REST API

All responses are JSON.

| #  | Method & Path          | Body / Query                  | Description                                    |
|----|------------------------|-------------------------------|------------------------------------------------|
| 1  | `GET  /api/health`     | —                             | `{"status":"ok"}`. Always token-exempt.        |
| 2  | `GET  /api/state`      | —                             | `{"power":"on"\|"off"\|"unknown","configured":bool}` |
| 3  | `POST /api/power`      | `{"power":"on"}` or `?power=on` | Sets power; returns new state.               |
| 4  | `POST /api/on`         | _(empty)_                     | Convenience: turn on.                          |
| 5  | `POST /api/off`        | _(empty)_                     | Convenience: turn off.                         |
| 6  | `POST /api/pair/start` | `{"tvIp":"192.168.1.x"}`      | Begins pairing; TV shows a PIN.                |
| 7  | `POST /api/pair/confirm` | `{"pin":"1234"}`            | Completes pairing; persists credentials.       |
| 8  | `POST /api/pair/reset` | _(empty)_                     | Clears stored credentials.                     |

Status codes: `409` if not paired (for power) or no pairing in progress (for
confirm), `400` for bad input, `502` if the TV call fails, `401` for a bad/missing
API token.

### curl examples

```bash
BASE=http://homelab.local:8080

# Pair (do this once):
curl -s -X POST $BASE/api/pair/start   -d '{"tvIp":"192.168.1.50"}'
# ... read the PIN off the TV screen ...
curl -s -X POST $BASE/api/pair/confirm -d '{"pin":"1234"}'

# Control:
curl -s $BASE/api/state
curl -s -X POST $BASE/api/on
curl -s -X POST $BASE/api/off
curl -s -X POST "$BASE/api/power?power=on"

# With an API token:
curl -s -H "X-API-Token: $TOKEN" -X POST $BASE/api/on
```

## Apple Shortcuts

The convenience endpoints are designed for one-action Shortcuts on
iOS/macOS/watchOS:

1. Add a **Get Contents of URL** action.
2. URL: `https://homelab.example.com/api/on` (or `/api/off`).
3. Method: **POST**.
4. If you set `API_TOKEN`, add a header `X-API-Token` with the value.

Name the shortcut "Ambilight On" / "Ambilight Off" and it works with Siri.

> watchOS Shortcuts require **HTTPS**. The Go server speaks plain HTTP to stay
> simple — front it with a reverse proxy that terminates TLS (recommended:
> Caddy, which auto-provisions certs). A minimal Caddyfile:
>
> ```
> ambilight.example.com {
>     reverse_proxy localhost:8080
> }
> ```
>
> If you cannot use a public domain, a self-signed cert works for iOS Shortcuts
> on the same LAN once the cert is trusted on the device, but watchOS is stricter
> — a real cert via reverse proxy is the reliable path.

## PWA install

1. Open the service URL in Safari on iPhone/iPad.
2. Pair the TV via the **Settings & Pairing** panel (enter IP → Start → enter
   PIN → Confirm).
3. Share sheet → **Add to Home Screen**. The app installs with its own icon and
   launches full-screen. The service worker caches the shell so the UI loads
   offline (control actions still need the TV reachable).

## Docker

```bash
docker build -t ambilighthue-web webapp/
docker run -d --name ambilight \
  -p 8080:8080 \
  -v ambilight-data:/data \
  -e API_TOKEN=optional-secret \
  ambilighthue-web
```

The image is a multi-stage build: a Go builder stage produces a static,
CGO-disabled, stripped binary that is copied onto `gcr.io/distroless/static`.
Expected size **~10-15 MB** (binary + distroless base).

> **Unverified:** Docker is not installed in the development sandbox, so the
> image has not been built/run here. The Dockerfile is provided as-is; the size
> estimate is a projection from the binary size plus the distroless base.

The `/data` volume holds `config.json` (paired credentials) so pairing survives
restarts. The default image runs as root for simple volume writes; switch the
base to `gcr.io/distroless/static:nonroot` and chown the volume to uid 65532 for
a non-root runtime.

## Security notes

- TLS verification to the TV is **disabled** (`InsecureSkipVerify`) because the
  TV presents a self-signed certificate. This is LAN-only by design.
- Stored credentials (deviceId + auth_key) are plaintext JSON on the mounted
  volume — protect the volume accordingly.
- The optional `API_TOKEN` is a simple shared secret, not a full auth system;
  pair it with the reverse-proxy TLS for anything beyond a trusted LAN.
