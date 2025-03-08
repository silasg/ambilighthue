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

    func makeSession() -> Session {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = 300

        let evaluators: [String: ServerTrustEvaluating] = [
            "*": DisabledTrustEvaluator()
        ]

        let manager = WildcardServerTrustPolicyManager(evaluators: evaluators)

        return Session(configuration: configuration, serverTrustManager: manager)
    }
}

class WildcardServerTrustPolicyManager: ServerTrustManager, @unchecked Sendable {
    override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        if let policy = evaluators[host] {
            return policy
        }

        return evaluators["*"]
    }
}
