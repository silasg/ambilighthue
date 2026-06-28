# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Orientation

The **maintained product is the Go web app under `webapp/`** (REST backend + PWA;
see `webapp/README.md`), deployed via the homelab stack in `deploy/`. The native
Apple apps described below (tvOS/iOS/watchOS) are **archived and unmaintained**,
and now live under **`archive/`** — all native paths in this file are relative to
`archive/`. The sections below document those archived apps.

## Project Overview

This is a tvOS SwiftUI application called "Ambilight Hue Control" that controls Philips TV ambilight functionality through Hue integration. The app allows users to turn the TV's ambilight on/off and manage the pairing process with Philips TVs.

## Key Architecture Components

### Core Classes
- **AmbilightTv**: Main business logic class implementing `AmbilightTvProtocol`, handles TV communication via Alamofire HTTP requests
- **AmbilightHueControlView**: Main SwiftUI view with toggle buttons for ambilight control
- **AmbilightTvConfig**: Manages UserDefaults persistence for TV connection settings (IP, username, password)
- **AmbilightTvPairingInProgress**: Handles TV pairing workflow with signature generation
- **SessionFactory**: Creates Alamofire sessions with custom SSL trust management

### Protocol Design
The app uses protocol-based architecture for testability:
- `AmbilightTvProtocol`: Main TV interface
- `SessionFactoryProtocol`: Alamofire session creation abstraction

### TV Communication
- Uses Philips TV API endpoints on port 1926
- Implements digest authentication for secure communication
- Handles pairing workflow: request → user PIN → confirmation → stored credentials
- Main endpoints: `/6/pair/request`, `/6/pair/grant`, `/6/HueLamp/power`

## Development Commands

### Building and Testing
```bash
# All native commands run from the archive/ directory (cd archive first).

# Build the project (use Xcode or xcodebuild)
xcodebuild -workspace archive/ambilighthue.xcworkspace -scheme ambilighthue -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'

# Run tests
xcodebuild test -workspace archive/ambilighthue.xcworkspace -scheme ambilighthue -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'

# Run specific test plan
xcodebuild test -workspace archive/ambilighthue.xcworkspace -scheme ambilighthue -testPlan ambilighthuetests

# Run a single test (class or method)
xcodebuild test -workspace archive/ambilighthue.xcworkspace -scheme ambilighthue \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:ambilighthueTests/AmbilightTvTests/test_reset_pairing_clears_credentials_and_config
```

### Dependencies
This project uses a **hybrid dependency setup** — be aware of both:
- **CocoaPods** (`Podfile`): Alamofire (networking) and ViewInspector (SwiftUI test inspection). Requires `pod install` and the `.xcworkspace`.
- **Swift Package Manager** (in `archive/ambilighthue.xcodeproj`): Mocker (HTTP mocking), pulled from `github.com/WeTransfer/Mocker.git`. The `pod 'Mocker'` line in the Podfile is intentionally commented out.

```bash
# Install/update the CocoaPods dependencies (Alamofire, ViewInspector) — run from archive/
cd archive
pod install
pod update
```
SPM packages (Mocker) are resolved automatically by Xcode/xcodebuild — no manual step.

## Testing Strategy

The project uses comprehensive unit testing with mocking:
- **Mocker** (SPM): HTTP request mocking — registered via `MockingURLProtocol` on a `URLSessionConfiguration.af.default` in `setUpWithError()`
- **ViewInspector** (Pod): SwiftUI view testing
- **XCTest**: Standard testing framework

The `ambilighthuetests.xctestplan` enumerates an explicit `selectedTests` list — new tests must be added there to run under the test plan.

### Test Structure
- `AmbilightTvTests`: Tests business logic, API communication, and pairing workflow
- `AmbilightHueControlViewTests`: Tests UI behavior and state management
- Uses `MockSessionFactory` for dependency injection in tests

### Key Test Patterns
- Expectation-based async testing for network requests
- Custom extension for condition-based expectations
- Mock request/response validation with `OnRequestHandler`

## Important Implementation Notes

### Security Considerations
- TV credentials stored in UserDefaults (username/password from pairing)
- Custom SSL trust manager for TV communication (self-signed certificates)
- Device ID generation for pairing process

### State Management
- Uses `@StateObject` and `@Published` for reactive UI updates
- `ObservableObject` protocol for SwiftUI integration
- Current state tracking: enabled/disabled/nil (for unknown)

### Error Handling
- Network errors logged to `log` property for UI display
- Graceful fallbacks for configuration issues
- Alert prompts for unconfigured TV state

## File Organization

The native app lives under `archive/` (paths below are relative to it):

- `archive/ambilighthue/`: Main app source code
- `archive/ambilighthueTests/`: Unit tests
- `archive/Pods/`: CocoaPods dependencies (Alamofire, ViewInspector) — gitignored
- `archive/ambilighthue.xcworkspace/`: Main workspace — **gitignored and regenerated by `pod install`**. The shared scheme (`ambilighthue`) lives in `archive/ambilighthue.xcodeproj/xcshareddata/xcschemes/`, not the workspace.
- `archive/Podfile`: CocoaPods config for tvOS 17.5+
- The file compiled into the app is `archive/ambilighthue/SessionFactory.swift`. (A stray outdated duplicate that used to sit at the repo root was deleted during the archive move.)

## Development Tips

- Always use the `.xcworkspace` file, not the `.xcodeproj` 
- The app targets tvOS platform specifically
- Test mock setup is in `setUpWithError()` with `MockingURLProtocol`
- Use `createAmbilightTvForTest()` helper for consistent test setup
- The `AppLauncher` struct (`@main` in `ambilightHueApp.swift`) launches a minimal `TestApp` when `XCTestCase` is present, and the real `ambilightHueApp` otherwise — this keeps the full UI from booting during unit tests
- The production session factory class is named `SessionFactorty` (note the typo) — reference it as-is when wiring dependencies