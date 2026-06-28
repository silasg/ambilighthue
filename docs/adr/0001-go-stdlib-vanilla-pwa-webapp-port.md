# ADR-0001: Go stdlib-only backend with a vanilla PWA for the TV-control web app

## Status

Accepted

## Context

The existing tvOS app (`ambilighthue/`) controls a Philips TV's ambilight over
the JointSpace protocol (pairing via HMAC-SHA1 signature, then HTTP Digest auth
to toggle `HueLamp/power`). We want the same control available as a small web
service that runs in a resource-tight homelab, is easy to drive from Apple
Shortcuts, and can be added to an iPhone/iPad home screen as a PWA. A read-only
Python reference (`pylips`) for the same protocol exists.

This ADR covers three intertwined choices for that port: the backend language
and dependency policy, the frontend approach, and whether to build on pylips.
They share a single spine — keep the deployed artifact tiny and operationally
trivial in a homelab — so they are recorded together.

## Decision Drivers

- The container must fit a resource-tight homelab: target a ~10-15 MB image and
  a near-idle memory/CPU footprint.
- The endpoints must be dead-simple to call from Apple Shortcuts (including
  watchOS), which favors plain JSON over HTTP and zero client-side complexity.
- The PWA must be installable to an iOS home screen with no build toolchain to
  maintain in a hobby repo.
- The protocol is already proven against the user's specific TV by the Swift
  app, including a secret HMAC key that differs from pylips' key.
- Maintainer is a solo developer; supply-chain surface and upgrade churn should
  be minimal.

## Considered Alternatives

### Alternative 1: Go with third-party libraries (router, digest-auth client)

- Use a web framework (chi/gin) and an off-the-shelf HTTP Digest client.
- Trade-offs: faster to write the digest handshake; but adds modules to audit
  and update, grows the binary, and the digest libraries are more general than
  the four endpoints we hit.

### Alternative 2: Python (reuse/vendor pylips)

- Port or wrap the existing pylips implementation.
- Trade-offs: closest to a known-working reference; but a Python runtime image
  is an order of magnitude larger than a static Go binary, and pylips ships a
  *different* secret key and signs `timestamp+pin`, neither of which matches the
  user's working TV — so we could not use it verbatim anyway.

### Alternative 3: Frontend SPA framework (React/Vue + bundler)

- Build the UI with a framework and a Vite/webpack build step.
- Trade-offs: richer DX; but introduces an npm toolchain, a build artifact, and
  ongoing dependency upgrades for a five-control UI.

## Decision

1. **Backend: Go, standard library only.** No external Go modules. Use
   `net/http`, `crypto/tls` (with `InsecureSkipVerify` for the TV's self-signed
   cert), `crypto/hmac` + `crypto/sha1` for the pairing signature, `crypto/md5`
   for Digest auth, `crypto/rand` for the deviceId/cnonce, and `encoding/json`.
   The HTTP Digest handshake is implemented by hand for the minimal qop=auth/MD5
   subset the endpoints need.
2. **Container: multi-stage build to `distroless/static`** with a static,
   CGO-disabled, stripped binary; the frontend is embedded via `embed.FS` so the
   image is a single file.
3. **Frontend: vanilla PWA** — one `index.html` + `app.js` + `style.css`,
   `manifest.webmanifest`, a service worker, and icons. No framework, no
   bundler, served as static files by the Go binary.
4. **Do not depend on pylips.** Port the minimal proven subset directly from the
   Swift app, including its exact secret key and its `pin+timestamp` signing
   order.

## Consequences

### Positive

- Final image is a single static binary on distroless; no language runtime to
  ship or patch.
- Zero Go module supply chain: nothing to `go get`, audit, or bump.
- The REST surface (`/api/on`, `/api/off`, `/api/power`, `/api/state`) is a
  one-line `curl` and therefore a one-step Apple Shortcut.
- The PWA has no build step; editing a file and restarting the binary is the
  whole workflow.
- Behavior matches the user's TV because the signature key and ordering are
  copied from the app that already works on it.

### Negative

- We own and must test the Digest-auth code ourselves (mitigated by unit tests
  with known vectors).
- `InsecureSkipVerify` disables TLS verification to the TV; acceptable on a LAN
  to a self-signed device but not a general-purpose posture.
- No framework conveniences (state management, routing) on the frontend; complex
  UI growth would be more manual.

### Neutral

- The signing order diverges from pylips by design; anyone cross-referencing
  pylips must know this is intentional.
- watchOS Shortcuts require HTTPS, so production deployments need a reverse proxy
  (e.g. Caddy) for TLS in front of the plain-HTTP Go server.

## Reversibility

Moderate-to-easy. The `tv` package is isolated behind an interface, so swapping
in a library-based digest client or re-hosting the logic in another language is
contained. Replacing the vanilla frontend with a framework is a self-contained
change to `webapp/web/`. The pylips decision is effectively permanent only in
that we keep the Swift-derived key/order; reversing would mean re-pairing.

## Related ADRs

- None (first ADR in this repository).
