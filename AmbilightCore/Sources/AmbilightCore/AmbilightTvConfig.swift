//
//  AmbilightTvConfig.swift
//  AmbilightCore
//
//  Created by Silas Graffy on 28.12.24.
//  Moved into the shared AmbilightCore package for the universal port.
//
//  NOTE (watchOS): UserDefaults.standard is per-app-process. The watchOS app
//  runs in its own process and therefore does NOT share this config with the
//  phone automatically. See IOS_PORTING.md / the ADR for the chosen approach
//  (pairing on iPhone, optional App Group / WatchConnectivity sync later).
//


import Foundation

public class AmbilightTvConfig {
    let defaults = UserDefaults.standard

    @discardableResult
    public static func configure(tvIp: String, username: String, password: String) -> AmbilightTvConfig {
        UserDefaults.standard.set(tvIp, forKey: "tvIp")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(password, forKey: "password")
        return AmbilightTvConfig()
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: "tvIp")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "password")
    }

    public static var isConfigured: AmbilightTvConfig? {
        if (UserDefaults.standard.string(forKey: "tvIp") != nil && UserDefaults.standard.string(forKey: "username") != nil && UserDefaults.standard.string(forKey: "password") != nil)
        {
            return AmbilightTvConfig()
        }
        return nil
    }

    public var tvIp: String { return defaults.string(forKey: "tvIp").unsafelyUnwrapped }
    public var username: String { return defaults.string(forKey: "username").unsafelyUnwrapped }
    public var password: String { return defaults.string(forKey: "password").unsafelyUnwrapped }

    private init() {}
}
