//
//  NetworkCall.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import Foundation
import Alamofire

enum AmbilightHueMode {
    case enabled, disabled
}

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

class AmbilightTv : ObservableObject{
    @Published var log = "(no log)"
    @Published var currentState: AmbilightHueMode? = nil
   
    var tvIp: String
    var credential: URLCredential
    
 
    var session: Session

    
    init(config: AmbilightTvConfig) {
        self.credential = URLCredential(user: config.username, password: config.password, persistence: .forSession)
        self.tvIp = config.tvIp
        let serverTrustPolicies: [String: DisabledTrustEvaluator] = [
            self.tvIp: DisabledTrustEvaluator()
            ]
        self.session = Session(serverTrustManager: ServerTrustManager(evaluators: serverTrustPolicies))
        updateState()//todo: move
    }
    
    func updateState() {
        session.request("https://\(tvIp):1926/6/HueLamp/power", method: .get)
            .authenticate(with: credential)
            .responseString { r in
            switch r.result {
            case .success(let value):
                self.currentState = switch value {
                case "{\"power\":\"Off\"}": AmbilightHueMode.disabled
                case "{\"power\":\"On\"}": AmbilightHueMode.enabled
                default: nil
                }
            case .failure(let error):
                self.log = error.localizedDescription
                self.currentState = nil
            }
                debugPrint(r)
            }
    }
    
    func setAmbilightHueMode(newMode: AmbilightHueMode) {
        
        let powerState = newMode == AmbilightHueMode.enabled ? "On" : "Off"
        
        let parameters: [String: Any] = ["power": powerState]
        
        
        session.request("https://\(tvIp):1926/6/HueLamp/power", method: .post,
                        parameters: parameters, encoding: JSONEncoding.default)
        .authenticate(with: credential).response { response in
            switch response.result {
            case .success( _):
                self.currentState = newMode;
                self.log =  "ok for \(powerState)"
            case .failure(let error):
                self.log = error.localizedDescription
            }
                debugPrint(response)
            }
        
    }
}


