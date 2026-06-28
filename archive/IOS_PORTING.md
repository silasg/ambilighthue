# Universal port — Xcode wiring instructions (iOS + iPadOS + watchOS)

This port was produced in a **Linux environment with no Xcode / xcodebuild**.
Nothing here has been compiled or run. All new source files exist in a clean
structure; the existing tvOS project (`ambilighthue.xcodeproj`,
`ambilighthue.xcworkspace`, sources under `ambilighthue/`) was **left intact and
must keep working**.

The Xcode project file (`project.pbxproj`) was deliberately **not** hand-edited
to add the new targets — doing that by hand is error-prone and would risk
corrupting the working tvOS project. Follow the steps below in Xcode instead.

## What already exists in the repo after the port

```
AmbilightCore/                         # NEW shared Swift package (all logic)
  Package.swift                        #   iOS17 / tvOS17 / watchOS10; deps: Alamofire, Mocker(test)
  Sources/AmbilightCore/
    AmbilightTv.swift                  #   (moved from ambilighthue/, now public API)
    AmbilightTvPairingInProgress.swift #   HMAC-SHA1 signature (secret key preserved)
    AmbilightTvConfig.swift            #   UserDefaults persistence
    AmbilightTvProtocol.swift          #   AmbilightTvProtocol, AmbilightHueMode, SessionFactoryProtocol
    SessionFactory.swift               #   class SessionFactorty (typo preserved)
    AmbilightTvStub.swift              #   shared preview/test stub
  Tests/AmbilightCoreTests/
    AmbilightTvTests.swift             #   ported (Mocker + XCTest), @testable import AmbilightCore

Platforms/iOS/                         # NEW universal iOS app (iPhone + iPad)
  AmbilightHueApp.swift                #   @main AppLauncher (XCTest swap preserved)
  AmbilightHueControlView.swift        #   iOS-adapted (no CardButtonStyle)
  SettingsView.swift                   #   iOS-adapted Form
Platforms/iOSTests/
  AmbilightHueControlViewTests.swift   #   ported ViewInspector tests

Platforms/watchOS/                     # NEW watchOS app
  AmbilightHueWatchApp.swift           #   @main
  WatchControlView.swift               #   minimal On/Off + status
Platforms/watchOSTests/
  WatchControlViewTests.swift          #   ViewInspector behaviour tests

docs/adr/0001-extract-shared-core-and-go-universal.md   # NEW ADR
```

The original tvOS sources are still under `ambilighthue/` and unchanged.

> Note on duplication: `ambilighthue/` still contains its own copies of
> `AmbilightTv.swift`, `SessionFactory.swift`, etc. (internal access). The
> shared package contains the public versions. To avoid two divergent copies you
> may later re-point the tvOS target at `AmbilightCore` (step 8); until then the
> tvOS target keeps using its own files so it stays buildable as-is.

---

## Step 1 — Add the shared package to the workspace

1. Open `ambilighthue.xcworkspace` in Xcode.
2. File ▸ Add Package Dependencies… ▸ "Add Local…" ▸ select the `AmbilightCore`
   folder. This adds it as a local package in the workspace.
3. Verify `AmbilightCore` resolves Alamofire and Mocker (Swift Package Manager
   will fetch them).

## Step 2 — Create the universal iOS app target

1. File ▸ New ▸ Target… ▸ iOS ▸ **App**.
2. Product Name: `ambilighthue-iOS` (or your preferred display name). Interface:
   SwiftUI, Language: Swift. Uncheck Core Data / tests for now.
3. Delete the auto-generated `ContentView.swift` and `…App.swift` Xcode created
   for this target.
4. Add the files from `Platforms/iOS/` to the target (drag into the project
   navigator, "Create groups", target membership = the iOS app only):
   - `AmbilightHueApp.swift`, `AmbilightHueControlView.swift`, `SettingsView.swift`
5. Build settings for the iOS app target:
   - `IPHONEOS_DEPLOYMENT_TARGET = 17.0`
   - `TARGETED_DEVICE_FAMILY = "1,2"`  (iPhone + iPad → universal)
   - `PRODUCT_BUNDLE_IDENTIFIER = info.graffy.ambilighthue.ios` (or similar)
   - `GENERATE_INFOPLIST_FILE = YES`
6. General ▸ Frameworks, Libraries, and Embedded Content ▸ **+** ▸ add
   `AmbilightCore` (the package library product).
7. Info.plist keys (add via target ▸ Info, since INFOPLIST is generated use
   "Custom iOS Target Properties" / `INFOPLIST_KEY_*` build settings or an
   explicit Info.plist):
   - `NSLocalNetworkUsageDescription` — required on iOS 14+ to reach the TV on
     the LAN. e.g. "This app talks to your TV on your local network to control
     the ambilight."
   - **App Transport Security**: the TV uses HTTPS with a self-signed cert on a
     local IP. `DisabledTrustEvaluator` bypasses cert validation, but verify on
     device. If connections fail, add an ATS exception
     (`NSAppTransportSecurity` → `NSAllowsLocalNetworking = YES`, or a
     per-domain exception). tvOS did not need this; iOS may.

## Step 3 — Create the iOS unit-test target

1. File ▸ New ▸ Target… ▸ iOS ▸ **Unit Testing Bundle**. Name:
   `ambilighthue-iOSTests`. Target to be Tested: `ambilighthue-iOS`.
2. Delete the auto-generated test file.
3. Add `Platforms/iOSTests/AmbilightHueControlViewTests.swift` (target
   membership = the iOS test target).
4. The test file does `@testable import ambilighthue_iOS` — make sure the iOS
   app's **Product Module Name** matches `ambilighthue_iOS` (Xcode replaces `-`
   with `_`). Adjust the import if you chose a different product name.
5. Add the **ViewInspector** dependency to this test target:
   - Easiest: add ViewInspector via SPM (File ▸ Add Packages ▸
     `https://github.com/nalexn/ViewInspector`) and link it to the iOS test
     target. (CocoaPods' ViewInspector is currently tvOS-only in the Podfile.)
   - Also link `AmbilightCore` to the test target (for the stub + enums).

## Step 4 — Create the watchOS app target

1. File ▸ New ▸ Target… ▸ watchOS ▸ **App** (a standalone watchOS app; if you
   want it embedded in the iOS app instead, choose the "Watch App for iOS App"
   flow and set the companion to `ambilighthue-iOS`).
2. Product Name: `ambilighthue-watchOS`. Interface: SwiftUI.
3. Delete the auto-generated SwiftUI files for this target.
4. Add the files from `Platforms/watchOS/` (target membership = the watch app):
   - `AmbilightHueWatchApp.swift`, `WatchControlView.swift`
5. Build settings:
   - `WATCHOS_DEPLOYMENT_TARGET = 10.0`
   - `PRODUCT_BUNDLE_IDENTIFIER = info.graffy.ambilighthue.watchkitapp` (or, if
     embedded in iOS, the companion-derived id).
6. Frameworks ▸ **+** ▸ add `AmbilightCore`.
7. Info.plist: add `NSLocalNetworkUsageDescription` and the same ATS note as the
   iOS app (the watch makes the same TV calls).
8. Config sharing (optional, documented in the ADR): if you want the watch to
   reuse the iPhone's stored credentials, set up an **App Group** and change
   `AmbilightTvConfig` to use `UserDefaults(suiteName:)`, and/or add
   `WatchConnectivity`. Not done in this port on purpose.

## Step 5 — Create the watchOS test target (optional)

1. File ▸ New ▸ Target… ▸ watchOS ▸ **Unit Testing Bundle**. Name:
   `ambilighthue-watchOSTests`.
2. Add `Platforms/watchOSTests/WatchControlViewTests.swift`.
3. The file does `@testable import ambilighthue_watchOS` — match the watch app's
   Product Module Name.
4. Link ViewInspector (SPM) and `AmbilightCore` to this test target.
   - Note: watchOS has no `UIHostingController`; the watch tests inspect the view
     directly (no `onAppear`), so they only cover button-tap behaviour.

## Step 6 — Schemes and test plans

1. Create a scheme per app target (Xcode usually auto-creates them).
2. Add the test bundles to each scheme's Test action. You can also create a new
   `.xctestplan` mirroring the existing `ambilighthuetests.xctestplan` but
   pointing at the new test targets, including `AmbilightCoreTests`.

## Step 7 — Dependencies summary

| Dependency    | tvOS (existing)      | AmbilightCore | iOS app/tests        | watchOS app/tests   |
|---------------|----------------------|---------------|----------------------|---------------------|
| Alamofire     | CocoaPods (existing) | SPM           | via AmbilightCore    | via AmbilightCore   |
| Mocker        | SPM (existing)       | SPM (test)    | via AmbilightCore    | via AmbilightCore   |
| ViewInspector | CocoaPods (existing) | —             | SPM (add to test)    | SPM (add to test)   |

Keep the tvOS Podfile as-is. The new targets get Alamofire/Mocker transitively
through `AmbilightCore`; only ViewInspector must be added to the new test
targets (SPM recommended so the new targets don't depend on CocoaPods).

## Step 8 — (Optional) de-duplicate the tvOS target onto AmbilightCore

To stop maintaining two copies of the logic:
1. Add `AmbilightCore` to the tvOS app target's Frameworks.
2. Remove `AmbilightTv.swift`, `AmbilightTvPairingInProgress.swift`,
   `AmbilightTvConfig.swift`, `AmbilightTvProtocol.swift`, `SessionFactory.swift`,
   `AmbilightTvStub.swift` from the tvOS target's membership (the copies in
   `ambilighthue/`).
3. Add `import AmbilightCore` where needed in the tvOS views and `ambilightHueApp.swift`.
4. Move Alamofire/Mocker for tvOS to come via the package, and drop them from the
   Podfile if no longer needed directly.
This is optional and was intentionally NOT done so the tvOS target keeps
building unchanged.

---

## UNVERIFIED — must be checked once Xcode is available

- **Nothing compiles here.** No target, package, or test has been built or run.
- Public-access changes in `AmbilightCore` may need touch-ups if any other
  internal symbol is referenced across module boundaries.
- ViewInspector inspection of the iOS view assumes the layout still matches the
  selectors (`find(button: "Off"/"On")`, `VStack` `.background().group()` with
  `AngularGradient`). The iOS view preserves this structure but it is unverified
  against the current ViewInspector version.
- watchOS ViewInspector behaviour (no hosting controller) is unverified.
- ATS / Local Network permission behaviour on iOS and watchOS is unverified.
- Product module names (`ambilighthue_iOS`, `ambilighthue_watchOS`) used in
  `@testable import` must match whatever you name the targets.
```
