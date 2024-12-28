//
//  AmbilightTvConfig.swift
//  ambilighthue
//
//  Created by Silas Graffy on 28.12.24.
//


import Foundation
import Alamofire

class AmbilightTvConfig {
    let defaults = UserDefaults.standard

    func configure(tvIp: String, username: String, password: String) {
        defaults.set(tvIp, forKey: "tvIp")
        defaults.set(username, forKey: "username")
        defaults.set(password, forKey: "password")
    }
    
    var isConfigured: Bool {
        return defaults.string(forKey: "tvIp") != nil && defaults.string(forKey: "username") != nil && defaults.string(forKey: "password") != nil
    }
    
    var tvIp: String { return defaults.string(forKey: "tvIp").unsafelyUnwrapped }
    var username: String { return defaults.string(forKey: "username").unsafelyUnwrapped }
    var password: String { return defaults.string(forKey: "password").unsafelyUnwrapped }
}
