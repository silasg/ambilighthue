# Archived: native Apple apps (tvOS / iOS / iPadOS / watchOS)

> **Frozen and unmaintained.** The maintained product is the Go web app at
> [`../webapp`](../webapp/README.md). This folder preserves the original native
> Apple apps and their design docs for reference; they are not actively built,
> signed, or released.

## What's here

| # | Path | What it is |
|---|------|------------|
| 1 | `ambilighthue/`, `ambilighthueTests/` | The original **tvOS** SwiftUI app and its tests. |
| 2 | `ambilighthue.xcodeproj/`, `ambilighthuetests.xctestplan` | Xcode project and test plan. |
| 3 | `Platforms/` | The **universal port** (iOS + iPadOS + watchOS) views. |
| 4 | `AmbilightCore/` | Shared Swift package (TV-comms / pairing logic). |
| 5 | `Podfile`, `Podfile.lock` | CocoaPods (Alamofire, ViewInspector). |
| 6 | `icon/` | App icon assets. |
| 7 | `STRATEGY.md`, `APPLE_TV_CONTROL_OPTIONS.md`, `IOS_PORTING.md` | Strategy and porting notes. |

## Building (if you really want to)

The native build was last reorganized on a Linux machine **without Xcode**, so it
is unverified. From this `archive/` directory on macOS:

```bash
cd archive
pod install                                  # regenerates ambilighthue.xcworkspace + Pods/
xcodebuild -workspace ambilighthue.xcworkspace -scheme ambilighthue \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build
```

See [`STRATEGY.md`](STRATEGY.md), [`APPLE_TV_CONTROL_OPTIONS.md`](APPLE_TV_CONTROL_OPTIONS.md),
and [`IOS_PORTING.md`](IOS_PORTING.md) for background, and the repo root
[`../README.md`](../README.md) for the maintained web app.
