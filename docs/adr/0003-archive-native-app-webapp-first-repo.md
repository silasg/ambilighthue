# ADR-0003: Archive the native Apple app and make the repo web-app-first

## Status

Accepted (structural move performed on Linux without Xcode; the native build is
unverified and requires macOS `pod install` + `xcodebuild` follow-up — see
ADR-0002's matching caveat).

## Context

The repository began as a tvOS SwiftUI app and was later extended to a universal
Apple app (iOS/iPadOS/watchOS) with a shared `AmbilightCore` package (ADR-0002).
In parallel a Go web app (`webapp/`, ADR-0001) was built and is now the actively
maintained product: it has a published multi-arch GHCR image, a release pipeline
(`mise run release`, tag `v0.0.1`), and a deployment stack (`deploy/`).

The native app is no longer the focus of development. Its source, Xcode project,
CocoaPods/SPM setup, and four strategy/porting docs (`STRATEGY.md`,
`APPLE_TV_CONTROL_OPTIONS.md`, `IOS_PORTING.md`, and parts of `README.md`) all
sit at the repo root, where they outweigh and visually bury the web app a new
reader should land on first.

A decision is needed on how to signal that the native app is parked and to
reorganize the root so the web app is the primary entry point.

## Decision Drivers

- A first-time reader of the repo root should immediately understand the web app
  is the maintained product and the native app is frozen.
- The native Apple build must keep working for anyone who checks out the archive,
  despite no maintainer actively building it.
- The reorganization is being performed on a Linux machine with no `xcodebuild`
  and no `pod`, so the native build **cannot be compiled or tested here** and any
  Xcode path breakage will not be caught until verified on macOS.
- The Go web app (`webapp/`, `deploy/`, `mise.toml`, CI workflows) must remain
  byte-for-byte functional — its paths must not move.
- Existing decisions ADR-0001 and ADR-0002 must remain accurate after the move.

## Considered Alternatives

### Alternative 1: `archive/` subfolder (chosen)

- Move the entire native bundle (app sources, tests, `.xcodeproj`, `Platforms/`,
  `AmbilightCore/`, `Podfile`, xctestplan, `icon/`, and its strategy docs) into
  `archive/`.
- Trade-offs: strongest "frozen / unmaintained" signal; one self-contained unit
  preserves the `.xcodeproj`'s relative paths (`projectDirPath = ""`); cost is a
  large one-time `git mv` plus fixing the Podfile/workspace and updating doc and
  CLAUDE.md path references.

### Alternative 2: `native/` parallel to `webapp/`

- Same physical move, neutral descriptive name.
- Trade-offs: reads as a co-equal maintained product, which misrepresents the
  app's parked status; rejected because the signal is wrong.

### Alternative 3: Leave layout, only rewrite `README.md`

- Keep all files at root; change only the top-level README to be web-app-first.
- Trade-offs: cheapest and zero build risk, but the root stays dominated by
  native files and `STRATEGY.md`/`APPLE_TV_CONTROL_OPTIONS.md`/`IOS_PORTING.md`,
  so the buried-web-app problem persists; rejected.

## Decision

Adopt **Alternative 1**. Move the native Apple app and its strategy/porting docs
into `archive/` as a single self-contained unit, and reframe the repo root around
the web app:

1. **Move into `archive/`**: `ambilighthue/`, `ambilighthueTests/`,
   `ambilighthue.xcodeproj/`, `ambilighthuetests.xctestplan`, `Platforms/`,
   `AmbilightCore/`, `Podfile`, `Podfile.lock`, `icon/`, and the docs
   `STRATEGY.md`, `APPLE_TV_CONTROL_OPTIONS.md`, `IOS_PORTING.md`. Add
   `archive/README.md` stating the app is frozen and pointing to `/webapp`.
2. **Delete** the stray root `SessionFactory.swift` (a known dead duplicate; the
   compiled file is `ambilighthue/SessionFactory.swift`, which moves with the
   bundle).
3. **Keep at root**: `webapp/`, `deploy/`, `docs/`, `mise.toml`, `.github/`, and
   a rewritten web-app-first `README.md`.
4. **Update path references**: `CLAUDE.md` "File Organization" and build/test
   commands, `.gitignore` entries (`Pods/`, `ambilighthue.xcworkspace/`,
   `build/`), and any doc cross-links, to the new `archive/...` locations.
5. Because the move cannot be built here, **macOS verification (`pod install` +
   `xcodebuild build`/`test`) is a required follow-up step performed by the
   maintainer**, mirroring the unverified status of ADR-0002.

## Consequences

### Positive

- The repo root surfaces the web app and `deploy/` first; native files no longer
  bury it.
- The native app and the four docs that describe it live next to the code they
  document, in one folder whose name says "frozen".
- Web app paths, CI workflows, and the release pipeline are untouched.

### Negative

- The `.xcodeproj`'s navigator references to root `README.md`/`CLAUDE.md` will
  break (cosmetic, non-build); `Podfile`/`.xcworkspace` wiring must be
  regenerated via `pod install` after the move.
- The move is committed unverified; an Xcode path regression may surface only
  when the maintainer next builds on macOS.

### Neutral

- `todo.md` is reviewed during the move and either relocated into `archive/` or
  deleted; not a structural concern.

## Reversibility

Reversible by a single `git mv archive/* .` plus reverting the doc/`.gitignore`
edits; because the bundle moves as a unit, the inverse move restores the original
relative paths. Cost is low, but any history written against the new paths would
need no change since `git mv` preserves file history.

## Related ADRs

- Relates to: ADR-0001 (web app port — the product this reorg centers on)
- Relates to: ADR-0002 (shared core + universal native app — the app being
  archived; its `AmbilightCore`/`Platforms` layout moves wholesale into
  `archive/`)
