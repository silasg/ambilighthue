# Ambilight Hue Control

Control a Philips TV's ambilight (the `HueLamp` feature) over the local
**JointSpace** API. The maintained product is a small self-hostable **web
service** — a dependency-free Go REST backend plus an installable PWA — designed
for homelab and Apple-Home integration. The repo also keeps the original native
Apple apps (tvOS/iOS/watchOS) in an archive.

## Repository Layout

| # | Path | What it is |
|---|------|------------|
| 1 | `webapp/` | **The product.** Go stdlib backend + vanilla PWA exposing ambilight control as a REST API (Shortcuts-friendly, installable). See [`webapp/README.md`](webapp/README.md). |
| 2 | `deploy/` | **Homelab Docker Compose** stack (webapp + Homebridge + Caddy) that puts the ambilight in HomeKit. See [`deploy/README.md`](deploy/README.md). |
| 3 | `docs/` | Architecture Decision Records (`docs/adr/`), the deployment proposal, and agent plans/handoffs. |
| 4 | `archive/` | **Frozen, unmaintained** native Apple apps (tvOS/iOS/watchOS) and their strategy/porting docs. See [`archive/README.md`](archive/README.md). |

## Quick start

- **Run the web app locally:** see [`webapp/README.md`](webapp/README.md)
  (`mise run run` from the repo root, then open `http://localhost:8080`).
- **Deploy to a homelab:** see [`deploy/README.md`](deploy/README.md) — copy the
  example env/config and `docker compose up -d`.

## Use case: Apple Home, controlled from the Apple TV

The intended real-world setup exposes the TV's ambilight to **HomeKit** so it can
be toggled from the **Home app, Siri, Apple Watch, Control Center, and
Shortcuts** — with the **Apple TV acting as the home hub**. The control chain is:

```
webapp REST API  →  Homebridge (homebridge-http-switch plugin)  →  HomeKit
                                                                      │
                          Apple TV (home hub) ── Home app / Siri / Watch / Shortcuts
```

Homebridge calls the webapp directly over the internal Docker network
(`http://webapp:8080/api/{on,off,state}`) and publishes it as a HomeKit switch;
Caddy fronts the human/Shortcuts-facing UI with TLS. The **canonical, ready-to-run
example of this whole stack lives in [`deploy/`](deploy/)** — see
[`deploy/README.md`](deploy/README.md) for bring-up, pairing, adding the switch to
the Home app, and Shortcuts examples.

## Archived native apps

The original tvOS SwiftUI app and its universal Apple port (iOS/iPadOS/watchOS,
built on the shared `AmbilightCore` Swift package) are preserved under
[`archive/`](archive/) but are **no longer maintained** — the web app supersedes
them. Their setup, pairing flow, and strategy/porting notes are documented in
[`archive/README.md`](archive/README.md).

## License

This project is available for personal use and development.
