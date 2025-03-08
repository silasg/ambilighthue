//
//  SessionFactorty.swift
//  
//
//  Created by Silas Graffy on 08.03.25.
//


import Alamofire
import CommonCrypto
import Foundation

class SessionFactorty: SessionFactoryProtocol {
    
    static var session: Session?

    func makeSession(tvIp: String) -> Session {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = 300

        let evaluators: [String: ServerTrustEvaluating] = [
            "*.example.com": PinnedCertificatesTrustEvaluator()
        ]

        let manager = WildcardServerTrustPolicyManager(evaluators: evaluators)

        SessionFactorty.session = Session(configuration: configuration, serverTrustManager: manager)
        return SessionFactorty.session!
    }
}


class WildcardServerTrustPolicyManager: ServerTrustManager {
    override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        if let policy = evaluators[host] {
            return policy
        }
        var domainComponents = host.split(separator: ".")
        if domainComponents.count > 2 {
            domainComponents[0] = "*"
            let wildcardHost = domainComponents.joined(separator: ".")
            return evaluators[wildcardHost]
        }
        return nil
    }
}
