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

class NetworkCall : ObservableObject{
    @Published var log = "(no log)"
    @Published var currentState: AmbilightHueMode? = nil
   
    static let usr = "REDACTED"
    static let pwd = "REDACTED"
    let credential = URLCredential(user: usr, password: pwd, persistence: .forSession)
    let session = Session(serverTrustManager: ServerTrustManager(evaluators: ["TV_IP": DisabledTrustEvaluator()]))
  
    init() {
        updateState()//todo: move
    }
    
    func updateState() {
        session.request("https://TV_IP:1926/6/HueLamp/power", method: .get)
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
    
    func postRequest(newState: AmbilightHueMode) {
        
        let powerState = newState == AmbilightHueMode.enabled ? "On" : "Off"
        
        let parameters: [String: Any] = ["power": powerState]
        
        
        session.request("https://TV_IP:1926/6/HueLamp/power", method: .post, 
                        parameters: parameters, encoding: JSONEncoding.default)
        .authenticate(with: credential).response { response in
            switch response.result {
            case .success(let value):
                self.currentState = newState;
                self.log =  "ok for \(powerState)"
            case .failure(let error):
                self.log = error.localizedDescription
            }
                debugPrint(response)
            }
        
    }
}


