//
//  AmbilightHueApp.swift
//  ambilighthue-iOS  (universal: iPhone + iPad)
//
//  iOS entry point for the universal port. Mirrors the tvOS AppLauncher so the
//  same XCTest swap-in behaviour is preserved.
//

import SwiftUI
import AmbilightCore

@main
struct AppLauncher {
    static func main() throws {
        if NSClassFromString("XCTestCase") == nil {
            AmbilightHueApp.main()
        } else {
            TestApp.main()
        }
    }
}

struct TestApp: App {
    var body: some Scene {
        WindowGroup { Text("Running Unit Tests") }
    }
}

struct AmbilightHueApp: App {
    var body: some Scene {
        let ambilightTv = AmbilightTv(
            config: AmbilightTvConfig.isConfigured,
            sessionFac: SessionFactorty()
        )

        WindowGroup {
            AmbilightHueControlView(ambilightTv: ambilightTv)
        }
    }
}
