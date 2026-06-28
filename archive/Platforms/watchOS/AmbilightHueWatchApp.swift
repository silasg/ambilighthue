//
//  AmbilightHueWatchApp.swift
//  ambilighthue-watchOS
//
//  watchOS entry point. Reuses the shared AmbilightCore logic. Pairing is
//  intentionally NOT performed on the watch (entering an IP address and a PIN on
//  a watch keyboard is impractical); the watch reads configuration that was set
//  up on the iPhone. See the ADR and IOS_PORTING.md for the config-sharing note
//  (App Group / WatchConnectivity is the documented future path).
//

import SwiftUI
import AmbilightCore

@main
struct AmbilightHueWatchApp: App {
    var body: some Scene {
        let ambilightTv = AmbilightTv(
            config: AmbilightTvConfig.isConfigured,
            sessionFac: SessionFactorty()
        )

        WindowGroup {
            WatchControlView(ambilightTv: ambilightTv)
        }
    }
}
