//
//  NetworkCall.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import Alamofire
import CommonCrypto
import Foundation



class AmbilightTv: AmbilightTvProtocol, ObservableObject {
    func resetPairing() {
        AmbilightTvConfig.clear()
        config = nil
        credential = nil
    }

    @Published var log = "(no log)"
    @Published var currentState: AmbilightHueMode? = nil

    var credential: URLCredential?
    let session: Session
    var config: AmbilightTvConfig?
    var pairingInProgress: AmbilightTvPairingInProgress?
    var isConfigured: Bool { return config != nil }
    let AppName = "AmilightHue"

    init(config: AmbilightTvConfig?, sessionFac: SessionFactoryProtocol) {
        self.config = config
        self.session = sessionFac.makeSession()
        if config != nil {
            self.setCredential(user: config!.username, pass: config!.password)
        }
    }

    func startPairing(tvIp: String) {
        if tvIp == "" {
            return
        }
        pairingInProgress = nil
        let deviceId = createDeviceId()
        let parameters: Parameters = [
            "scope": ["read", "write", "control"],
            "device": [
                "device_name": "heliotrope", "device_os": "Android", "app_name": AppName,
                "type": "native", "app_id": "app.id", "id": deviceId,
            ],
        ]

        // curl --insecure -X POST -H "Content-Type: application/json" -d "{'scope': ['read', 'write', 'control'], 'device': {'device_name': 'heliotrope', 'device_os': 'Android', 'app_name': '$appname', 'type': 'native', 'app_id': 'app.id', 'id': '$device_id'}}" https://TV_IP:1926/6/pair/request

        struct PairingInfo: Decodable {
            let timestamp: Int
            let error_id: String
            let auth_key: String
        }
        
       session.request(
            "https://\(tvIp):1926/6/pair/request", method: .post, parameters: parameters,
            encoding: JSONEncoding.default, headers: ["Content-Type": "application/json"]
        )
        .validate()
        .responseDecodable(of: PairingInfo.self) { response in
            switch response.result {

            // will return: {"error_id":"SUCCESS","error_text":"Authorization required","auth_key":"a8d1b59ad64689d76b160dae57c396bbf77cbb8f6c98b05751fa75c2c4c61361","timestamp":55285,"timeout":60}

            case .success(let value):
                if value.error_id == "SUCCESS" {
                    self.log = "Pairing requested"
                    self.setCredential(user: deviceId, pass: value.auth_key)
                    self.pairingInProgress = AmbilightTvPairingInProgress(
                        tvIp: tvIp, deviceId: deviceId, authKey: value.auth_key,
                        timeStamp: value.timestamp)

                } else {
                    self.log = "Pairing request failed with error: \(value.error_id)"
                }

            case .failure(let err):
                self.log = err.localizedDescription
            }
        }

    }
    
    private func setCredential(user: String, pass: String) {
        self.credential = URLCredential(user: user, password: pass, persistence: .forSession)
    }

    func confirmPairing(tvPin: String, pairing: AmbilightTvPairingInProgress) {

        let user = pairing.deviceId
        let pass = pairing.authKey
        let tvIp = pairing.tvIp

        let signature = pairing.createSignature(tvPin: tvPin)

        // python implementation tried up to 10 times, however I never needed a single retry
        // curl --insecure -v --digest -u $user:$pass -X POST -H "Content-Type: application/json" -d "{'auth': {'auth_AppId': '1', 'pin': '$pin_input', 'auth_timestamp': $timestamp_input, 'auth_signature': "b\'$auth_signature\'"}, 'device': {'device_name': 'heliotrope', 'device_os': 'Android', 'app_name': '$appname', 'type': 'native', 'app_id': 'app.id', 'id': '$user'}}" https://TV_IP:1926/6/pair/grant

        let parameters: [String: Any] = [
            "auth": [
                "auth_AppId": "1",
                "pin": tvPin,
                "auth_timestamp": pairing.timeStamp,
                "auth_signature": signature,
            ],
            "device": [
                "device_name": "heliotrope",
                "device_os": "Android",
                "app_name": self.AppName,
                "type": "native",
                "app_id": "app.id",
                "id": user,
            ],
        ]
        
        if let credential {
            session.request(
                "https://\(tvIp):1926/6/pair/grant", method: .post,
                parameters: parameters, encoding: JSONEncoding.default
            )
            .authenticate(with: credential).response { response in
                switch response.result {
                case .success(_):
                    self.config = AmbilightTvConfig.configure(
                        tvIp: tvIp, username: user, password: pass)
                case .failure(let error):
                    self.log = error.localizedDescription
                }
                debugPrint(response)
            }
        }
        
    }

    private func createDeviceId() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let length = 16
        var deviceId = ""

        for _ in 0..<length {
            let randomIndex = Int(arc4random_uniform(UInt32(characters.count)))
            let randomCharacter = characters[
                characters.index(characters.startIndex, offsetBy: randomIndex)]
            deviceId.append(randomCharacter)
        }

        return deviceId
    }

    func updateState() {
        if let credential {
            session.request("https://\(config!.tvIp):1926/6/HueLamp/power", method: .get)
                .authenticate(with: credential)
                .responseString { response in
                    switch response.result {
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
                    debugPrint(response)
                }
        }
    }

    func setAmbilightHueMode(newMode: AmbilightHueMode) {
        let powerState = newMode == AmbilightHueMode.enabled ? "On" : "Off"
        if let credential {
            session.request(
                "https://\(config!.tvIp):1926/6/HueLamp/power", method: .post,
                parameters: ["power": powerState], encoding: JSONEncoding.default
            )
            .authenticate(with: credential).response { response in
                switch response.result {
                case .success(_):
                    self.currentState = newMode
                    self.log = "ok for \(powerState)"
                case .failure(let error):
                    self.log = error.localizedDescription
                }
                debugPrint(response)
            }
        }
    }
}
