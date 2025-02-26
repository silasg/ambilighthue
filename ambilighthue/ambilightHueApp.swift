//
//  helloworldApp.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import SwiftUI

@main
struct AppLauncher {
    static func main() throws {
        if NSClassFromString("XCTestCase") == nil {
            ambilightHueApp.main()
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
struct ambilightHueApp: App {
    let usr = "REDACTED"
    let pwd = "REDACTED"
    let tvIp = "TV_IP"
    
    func configure() -> AmbilightTvConfig {
        let config = AmbilightTvConfig.isConfigured ?? AmbilightTvConfig.configure(tvIp: tvIp, username: usr, password: pwd)
        return config;
    }
    
    var body: some Scene {
        let ambilightTv = AmbilightTv(config: configure(), session: nil)
        
        WindowGroup {
            AmbilightHueControlView(ambilightTv: ambilightTv)
        }
    }
}
