//
//  AmbilightTvConfig.swift
//  ambilighthue
//
//  Created by Silas Graffy on 28.12.24.
//


import Foundation
 class AmbilightTvConfig {
     let defaults = UserDefaults.standard

     static func configure(tvIp: String, username: String, password: String) -> AmbilightTvConfig {
        UserDefaults.standard.set(tvIp, forKey: "tvIp")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(password, forKey: "password")
        return AmbilightTvConfig()
    }
     
     static func clear() {
          UserDefaults.standard.removeObject(forKey: "tvIp")
          UserDefaults.standard.removeObject(forKey: "username")
          UserDefaults.standard.removeObject(forKey: "password")
     }
    
    static var isConfigured: AmbilightTvConfig? {
        if (UserDefaults.standard.string(forKey: "tvIp") != nil && UserDefaults.standard.string(forKey: "username") != nil && UserDefaults.standard.string(forKey: "password") != nil)
        {
            return AmbilightTvConfig()
        }
        return nil
    }
    
    var tvIp: String { return defaults.string(forKey: "tvIp").unsafelyUnwrapped }
    var username: String { return defaults.string(forKey: "username").unsafelyUnwrapped }
    var password: String { return defaults.string(forKey: "password").unsafelyUnwrapped }
    
    private init() {}
}
