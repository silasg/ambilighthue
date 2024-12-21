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
    
    init() {
        configure()
    }
    
    func configure() {
        let config = AmbilightTvConfig();
        if (!config.isConfigured) {
            config.configure(tvIp: tvIp, username: usr, password: pwd);
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AmbilightHueControlView()
        }
    }
}
