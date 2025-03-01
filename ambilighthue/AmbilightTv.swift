//
//  NetworkCall.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import Foundation
import Alamofire
import CommonCrypto

class AmbilightTv : AmbilightTvProtocol, ObservableObject{
    func resetPairing() {
        config = nil
        
    }
    
    
    @Published var log = "(no log)"
    @Published var currentState: AmbilightHueMode? = nil
   
    var tvIp: String
    var credential: URLCredential
    var session: Session
    var config: AmbilightTvConfig?
    var isConfigured: Bool { return config != nil }
    
    init(config: AmbilightTvConfig, session: Session?) {
        self.credential = URLCredential(user: config.username, password: config.password, persistence: .forSession)
        self.config = config
        self.tvIp = config.tvIp
        if (session == nil) {
            let serverTrustPolicies: [String: DisabledTrustEvaluator] = [
                self.tvIp: DisabledTrustEvaluator()
                ]
            self.session = Session(serverTrustManager: ServerTrustManager(evaluators: serverTrustPolicies))
        } else {
            self.session = session.unsafelyUnwrapped
        }
    }
    
    static func startPairing(tvIp: String) -> AmbilightTvPairingInProgress {
        let deviceId = createDeviceId()
        
        // curl --insecure -X POST -H "Content-Type: application/json" -d "{'scope': ['read', 'write', 'control'], 'device': {'device_name': 'heliotrope', 'device_os': 'Android', 'app_name': '$appname', 'type': 'native', 'app_id': 'app.id', 'id': '$device_id'}}" https://TV_IP:1926/6/pair/request
        
        // will return: {"error_id":"SUCCESS","error_text":"Authorization required","auth_key":"a8d1b59ad64689d76b160dae57c396bbf77cbb8f6c98b05751fa75c2c4c61361","timestamp":55285,"timeout":60}
        
        return AmbilightTvPairingInProgress(tvIp: tvIp, deviceId: "", authKey: "", timeStamp: 0)
    }
    
    static func confirmPairing(tvPin: String, pairing: AmbilightTvPairingInProgress) -> AmbilightTvConfig {
        
        let user = pairing.deviceId
        let pass = pairing.authKey
        let tvIp = pairing.tvIp
        
        let signature = createSignature(toSign: String(pairing.timeStamp) + tvPin)
        
        //try up to 10 times
        // curl --insecure -v --trace-ascii debug.log --digest -u $user:$pass -X POST -H "Content-Type: application/json" -d "{'auth': {'auth_AppId': '1', 'pin': '$pin_input', 'auth_timestamp': $timestamp_input, 'auth_signature': "b\'$auth_signature\'"}, 'device': {'device_name': 'heliotrope', 'device_os': 'Android', 'app_name': '$appname', 'type': 'native', 'app_id': 'app.id', 'id': '$user'}}" https://TV_IP:1926/6/pair/grant
        
        
        return AmbilightTvConfig.configure(tvIp: tvIp, username: user, password: pass)
    }
    
    private static func createDeviceId() -> String {
            let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            let length = 16
            var deviceId = ""
            
            for _ in 0..<length {
                let randomIndex = Int(arc4random_uniform(UInt32(characters.count)))
                let randomCharacter = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
                deviceId.append(randomCharacter)
            }
            
            return deviceId
        }

        private static func createSignature(toSign: String) -> String? {
            let secretKey: String = "oEC9Uhg5xbg566mpYPjhoWUwFtFAwTFoTW1By0vaOD4="
            guard let keyData = Data(base64Encoded: secretKey),
                  let toSignData = toSign.data(using: .utf8) else {
                return nil
            }
            
            var hmac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            keyData.withUnsafeBytes { keyBytes in
                toSignData.withUnsafeBytes { toSignBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyBytes.baseAddress, keyData.count, toSignBytes.baseAddress, toSignData.count, &hmac)
                }
            }
            
            let hmacData = Data(hmac)
            return hmacData.base64EncodedString()
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


