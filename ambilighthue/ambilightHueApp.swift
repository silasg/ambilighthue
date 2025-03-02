//
//  helloworldApp.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import SwiftUI
import Alamofire

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
    
    var body: some Scene {
            
        let ambilightTv = AmbilightTv(config: AmbilightTvConfig.isConfigured, sessionFac: SessionFactorty())
        
        WindowGroup {
            AmbilightHueControlView(ambilightTv: ambilightTv)
        }
    }
}
