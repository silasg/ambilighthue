# Ambilight Control Strategy

## Decision

Go with the **lighter, fully-native control path**:

> **Philips TV → Go REST backend → Homebridge (HTTP switch) → HomeKit → Apple TV Home app** (and Siri, Apple Watch, iPhone/iPad, Control Center).

The **web app's own UI** is kept for **advanced/occasional workflows** (pairing, configuration, manual control), *not* for daily use. Daily on/off happens through the native Apple **Home app** on whatever device is closest — including the Apple TV itself, which acts as the HomeKit home hub.

This is chosen over running **Home Assistant + a native tvOS HA client** (the "richer dashboard" alternative from [`APPLE_TV_CONTROL_OPTIONS.md`](./APPLE_TV_CONTROL_OPTIONS.md)) because for a single on/off control we don't need a dashboard, and this stack has the smallest footprint, reuses the REST backend we already built, and requires no extra heavy service. HA remains a documented fallback if richer UI is wanted later.

## Why this approach

| # | Reason |
|---|--------|
| 1 | **Smallest footprint** — a tiny stdlib Go container + Homebridge; no Home Assistant to run on the resource-tight homelab. |
| 2 | **Fully native on the Apple TV** — control from the built-in tvOS Home app; no App Store app, no paid Apple Developer account, no 7-day re-signing churn. |
| 3 | **Reuses what we have** — the `port/webapp` Go backend is the integration point; Homebridge just calls its REST API. |
| 4 | **Broad reach for free** — once it's a HomeKit accessory, it works from Siri, Apple Watch, iPhone/iPad, Control Center, and HomeKit automations. |

## Component responsibilities

| # | Component | Runs where | Responsibility |
|---|-----------|------------|----------------|
| 1 | **Go REST backend** (`port/webapp`) | Homelab (Docker) | Talks to the Philips TV (digest auth + HMAC pairing); persists credentials; exposes the REST API + PWA. The single source of truth for TV communication. |
| 2 | **Homebridge + http-switch plugin** | Homelab | Exposes the ambilight as a HomeKit switch by calling the backend's `/api/on`, `/api/off`, and polling `/api/state`. The adapter into HomeKit. |
| 3 | **Apple Home app** | Apple TV (hub), iPhone, iPad, Watch | Daily on/off control surface. Generic but fully native tile. |
| 4 | **Web app PWA UI** | Browser / iPhone home screen | Advanced/occasional workflows (see below). |

## What each surface is for

### Daily control → Apple Home app (via Homebridge)
- On/off from the Apple TV Home app, Siri, Apple Watch, Control Center, automations.
- The accessory is added to Home **once** from an iPhone (Homebridge pairing code); afterwards it's available on the Apple TV automatically because the Apple TV is the home hub.
- State stays in sync by having the http-switch plugin poll `GET /api/state`.

### Advanced workflows → web app PWA UI
- **TV pairing** — enter TV IP → start pairing → enter the PIN shown on the TV → confirm. This is the flow that can't be reduced to a single HomeKit toggle, so it lives in the web UI.
- **Configuration / reset** — change the TV IP, reset/re-pair credentials.
- **Manual control & status** — a direct on/off and live state view, useful for setup and troubleshooting independent of HomeKit.
- Installable to the iPhone/iPad home screen as a PWA for quick access when needed.

## Setup outline

| # | Step |
|---|------|
| 1 | Deploy the Go backend container on the homelab (mount a volume for `CONFIG_PATH`; optional `API_TOKEN`). |
| 2 | Open the PWA, pair with the TV (IP → PIN → confirm). Credentials persist across restarts. |
| 3 | Run Homebridge on the homelab; install `homebridge-http-switch`; point its on/off/status URLs at the backend (include `X-API-Token` if set). |
| 4 | Add the Homebridge bridge to the Home app from an iPhone (pairing code). |
| 5 | Confirm the ambilight tile appears and works in the Apple TV Home app, via Siri, and on the Watch. |

## Out of scope (for this strategy)

| # | Not doing | Note |
|---|-----------|------|
| 1 | Home Assistant + native tvOS HA client | Documented fallback if a richer on-TV dashboard is ever wanted. |
| 2 | Re-signing the tvOS SwiftUI app every 7 days | Stopgap only; the HomeKit path makes it unnecessary. |
| 3 | iOS/watchOS native app for daily use | The `port/ios` work is kept for the future (alternative app stores), but daily control goes through the Home app, not a custom app. |

## Open items

| # | Item |
|---|------|
| 1 | **TLS for Shortcuts/remote**: watchOS Shortcuts require HTTPS. If hitting the backend directly (not via HomeKit), front it with a reverse proxy (e.g. Caddy). HomeKit control does not need this. |
| 2 | **Docker image build unverified** — confirm the ~10–15 MB size once Docker is available. |
| 3 | Pick the HomeKit accessory type in Homebridge (plain **Switch** vs **Lightbulb**); Switch is simplest for on/off. |
| 4 | Decide whether to expose the backend beyond the LAN at all (default: LAN-only; TLS verification to the TV is intentionally disabled for its self-signed cert). |

## Related

- [`APPLE_TV_CONTROL_OPTIONS.md`](./APPLE_TV_CONTROL_OPTIONS.md) — full options research and ranking.
- Branch `port/webapp` — the Go backend + PWA (with its own ADR under `docs/adr/`).
- Branch `port/ios` — the universal iOS/watchOS port, kept for future use.
