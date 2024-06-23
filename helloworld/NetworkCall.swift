//
//  NetworkCall.swift
//  helloworld
//
//  Created by Silas Graffy on 23.06.24.
//

import Foundation
import Alamofire

class NetworkCall : ObservableObject{
    @Published var log = "(no log)"
   
    let usr = "REDACTED"
    let pwd = "REDACTED"
   
     let session = Session(serverTrustManager: ServerTrustManager(evaluators: ["TV_IP": DisabledTrustEvaluator()]))
  
    func postRequest(powerState: String) {
        
        let parameters: [String: Any] = ["power": powerState]
        
        let credential = URLCredential(user: usr, password: pwd, persistence: .forSession)

        session.request("https://TV_IP:1926/6/HueLamp/power", method: .post, 
                        parameters: parameters, encoding: JSONEncoding.default)
        .authenticate(with: credential).response { response in
            self.log = switch response.result {
            case .success(let value):
                "ok for \(powerState)"
            case .failure(let error):
                error.localizedDescription
            }
                debugPrint(response)
            }
        
    }
}


