# 2. Extract a shared core layer and go universal (iOS + iPadOS + watchOS)

## Status

Accepted (proposed as part of the universal port; not yet verified on a build
because the port was performed in a Linux environment without Xcode).

## Context

The app originated as a single tvOS SwiftUI target ("Ambilight Hue Control")
that controls a Philips TV's ambilight via the local Philips TV API
(`/6/pair/request`, `/6/pair/grant`, `/6/HueLamp/power`) over HTTPS on port
1926 with digest auth and an HMAC-SHA1 pairing signature.

We want the app to also run on iPhone, iPad and Apple Watch (motivation:
alternative iOS app stores / future use). The existing code mixed
platform-agnostic logic with tvOS-specific UI:

- Business / network logic (`AmbilightTv`, `AmbilightTvPairingInProgress`,
  `AmbilightTvConfig`, `AmbilightTvProtocol`, `SessionFactorty`, `AmbilightTvStub`)
  has no UI dependency beyond `ObservableObject`/Foundation.
- The views (`AmbilightHueControlView`, `SettingsView`) used tvOS-only idioms,
  most notably `CardButtonStyle()` (focus-based), which do not exist on
  iOS/watchOS.

Dependencies are hybrid: Alamofire + ViewInspector via CocoaPods, Mocker via
Swift Package Manager. The production session-factory class name is
intentionally the typo `SessionFactorty`. There is a stray, unused
`SessionFactory.swift` at the repo root (NOT the real one).

## Decision

1. **Extract the platform-agnostic logic into a shared Swift Package
   `AmbilightCore`** (`AmbilightCore/`), depending on Alamofire (and Mocker for
   its test target). Types consumed by app targets are made `public`; the
   intentional `SessionFactorty` typo is preserved. The package targets
   iOS 17 / tvOS 17 / watchOS 10.

2. **One universal iOS app target** (`Platforms/iOS/`) for iPhone + iPad
   (`TARGETED_DEVICE_FAMILY = "1,2"`), with iOS-adapted SwiftUI views:
   tvOS focus styling replaced by `.bordered` / `.borderedProminent`; a
   `Form`-based Settings screen; TV-IP entry and PIN entry via alerts. The
   structural layout (VStack, "Off"/"On" buttons, AngularGradient background)
   is preserved so the ported ViewInspector tests still match.

3. **A separate watchOS app target** (`Platforms/watchOS/`) with a minimal UI:
   status line + On/Off buttons. **Pairing is iPhone-only** — entering an IP
   address and a PIN on a watch keyboard is impractical. When unconfigured the
   watch instructs the user to pair on the iPhone.

4. **Keep `UserDefaults` persistence.** Each app process has its own
   `UserDefaults.standard`, so the watch app does not automatically share the
   iPhone's stored TV config. The chosen near-term behaviour is: the watch reads
   whatever config exists in its own process; cross-device sync (App Group
   shared `UserDefaults` and/or `WatchConnectivity`) is documented as the future
   path but intentionally NOT implemented now to avoid over-engineering.

5. **Keep the existing tvOS target intact.** Its sources remain under
   `ambilighthue/` and are not deleted. (Optionally the tvOS target can later be
   re-pointed at `AmbilightCore` too; documented in `IOS_PORTING.md`.)

## Consequences

Positive:
- Single source of truth for TV-comms / pairing logic, reused by all targets.
- Per-target dependency wiring is explicit; Alamofire/Mocker move to SPM via the
  package, reducing CocoaPods scope.
- New platforms can be added without copying logic.

Negative / risks:
- Logic types had to become `public`, widening the API surface.
- Config is not shared between iPhone and watch yet (deliberate; see decision 4).
- ATS: iOS App Transport Security is stricter than tvOS. The app talks HTTPS to
  a self-signed local TV; `DisabledTrustEvaluator` bypasses cert validation at
  the URLSession layer, but iOS may still need an ATS exception for local
  networking. To be verified on a real build (see `IOS_PORTING.md`).
- iOS 14+ requires the Local Network privacy permission
  (`NSLocalNetworkUsageDescription`) to reach devices on the LAN; tvOS did not.
  To be added/verified on a real build.
- **Unverified**: the entire port was done without Xcode/xcodebuild on Linux;
  nothing has been compiled or run.
