# Ambilight Hue — Homelab Deployment

A ready-to-run Docker Compose stack that lets you control your Philips TV's
ambilight from the Apple **Home app**, **Siri**, **Apple Watch**, and **Apple
Shortcuts**. See [`../STRATEGY.md`](../STRATEGY.md) and
[`../docs/deployment-proposal.md`](../docs/deployment-proposal.md) for the design
rationale.

The homelab is assumed **Intel/AMD (linux/amd64)**; the webapp image is
multi-arch, so arm64 hosts also work unchanged.

## Stack

| # | Service | Image | Role |
|---|---------|-------|------|
| 1 | `webapp` | `ghcr.io/OWNER/ambilighthue/webapp` | Go REST backend + PWA that talks to the TV. |
| 2 | `homebridge` | `homebridge/homebridge` | Exposes the ambilight as a HomeKit switch by calling the webapp directly. |
| 3 | `caddy` | `caddy` | TLS termination + reverse proxy for the human/Shortcuts-facing UI. |

How traffic flows:

- **Browser / Apple Shortcuts → Caddy (HTTPS) → webapp** under `/ambilight/*`.
- **Homebridge → webapp** *directly* over the internal docker network
  (`http://webapp:8080`), bypassing Caddy so it never deals with the base path.

### Base-path approach (why `/ambilight` is preserved, not stripped)

The webapp is **`BASE_PATH`-aware**. When started with `BASE_PATH=/ambilight`
(set in `docker-compose.yml`) it expects the **full** `/ambilight/...` prefix in
the request path and serves `/ambilight/api/...`, `/ambilight/` (the PWA), the
manifest `scope`/`start_url`, and the service-worker scope all under that prefix.

So the Caddyfile uses **`handle` + `reverse_proxy`** (which *preserves* the path)
— **not** `handle_path` (which would strip `/ambilight` and break the app). It
also forwards `X-Forwarded-Prefix: /ambilight`, which the app tolerates. The
three files agree: `BASE_PATH` in `.env`/compose == the `handle` path in the
Caddyfile == the prefix the README documents. If you want a different prefix (or
root), change all three together.

## Bring-up

```bash
cd deploy

# 1. Configure
cp .env.example .env
#    - set WEBAPP_IMAGE (replace OWNER with your GitHub owner/org)
#    - set API_TOKEN to an unguessable value (or leave empty to disable auth)
#    - keep BASE_PATH=/ambilight unless you also change the Caddyfile

# 2. Homebridge config
cp homebridge/config.example.json homebridge/config.json
#    - replace TOKEN-CHANGE-ME with the same API_TOKEN you set in .env
#    (or remove the X-API-Token headers if API_TOKEN is empty)

# 3. Edit the Caddyfile site address (home.example.lan) to your hostname.
#    See the comments there for real-domain vs internal-CA vs self-signed TLS.

# 4. Launch
docker compose pull
docker compose up -d
docker compose logs -f webapp
```

The webapp package on GHCR is **public**, so no registry login is needed to
pull. Pin a specific image tag in `.env` for reproducible deploys.

## Pair with the TV (once)

Credentials persist in the `webapp-data` volume across restarts. Do this once,
from a browser or with `curl`. With `API_TOKEN` set, add `-H "X-API-Token: <token>"`.

Easiest: open `https://<your-host>/ambilight/` in a browser and use the
**Settings & Pairing** panel (enter IP → Start → read the PIN off the TV →
Confirm).

Or with `curl` (substitute your TV's LAN IP):

```bash
BASE=https://home.example.lan/ambilight
TOKEN=change-me

# Start pairing — the TV displays a 4-digit PIN:
curl -sk -H "X-API-Token: $TOKEN" -X POST "$BASE/api/pair/start" \
  -d '{"tvIp":"tv.example.lan"}'

# Confirm with the PIN shown on the TV:
curl -sk -H "X-API-Token: $TOKEN" -X POST "$BASE/api/pair/confirm" \
  -d '{"pin":"1234"}'

# Verify:
curl -sk -H "X-API-Token: $TOKEN" "$BASE/api/state"
# -> {"power":"off","configured":true}

# To start over: POST $BASE/api/pair/reset
```

(`-k` accepts Caddy's internal/self-signed cert; drop it with a real domain.)

## Add the switch to the Apple Home app

1. Open the Homebridge UI at `http://<your-host>:8581` to confirm the
   **Ambilight** accessory is running (check `docker compose logs homebridge`).
2. On an **iPhone/iPad**, open the **Home** app → **+** → **Add Accessory** →
   **More options…**, pick **Homebridge Ambilight**, and enter the bridge PIN
   from `homebridge/config.json` (`031-45-154` in the example — change it).
3. The **Ambilight** switch now appears in Home. Because your **Apple TV is the
   home hub**, it shows up on the Apple TV automatically, plus Siri, Apple Watch,
   and Control Center.
4. State stays in sync: Homebridge polls `GET /api/state` every 15 s
   (`pollInterval`) and matches `"power":"on"` to know the switch is on.

## Apple Shortcuts examples

Hit the REST API directly for one-tap / Siri control (works on watchOS too,
thanks to Caddy's HTTPS). In Shortcuts, add a **Get Contents of URL** action:

**1. "Ambilight On"**
- URL: `https://home.example.lan/ambilight/api/on`
- Method: **POST**
- Headers: `X-API-Token` = `change-me` (only if `API_TOKEN` is set)

**2. "Ambilight Off"**
- URL: `https://home.example.lan/ambilight/api/off`
- Method: **POST**
- Headers: `X-API-Token` = `change-me`

Name them so "Hey Siri, Ambilight On" works. A `POST /ambilight/api/power` with
body `{"power":"on"}` (or `?power=on`) works too if you prefer one toggle.

> watchOS Shortcuts require **HTTPS with a trusted cert**. Caddy's `tls internal`
> CA must be trusted on the device, or use a real public domain (the reliable
> path). See the TLS comments in the [`Caddyfile`](./Caddyfile).

## Files

| # | File | Purpose |
|---|------|---------|
| 1 | `docker-compose.yml` | The three-service stack. |
| 2 | `Caddyfile` | TLS + reverse proxy serving the webapp under `/ambilight/*`. |
| 3 | `.env.example` | Template for image, token, base path, timezone. Copy to `.env`. |
| 4 | `homebridge/config.example.json` | Homebridge HTTP-switch config. Copy to `homebridge/config.json`. |

## Optional: auto-update

Add a [Watchtower](https://containrrr.dev/watchtower/) service to auto-pull new
`webapp` images when CI publishes them, or just re-run `docker compose pull &&
docker compose up -d` after a release.
