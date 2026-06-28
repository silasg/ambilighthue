//
//  SessionFactory.swift
//  AmbilightCore
//
//  Created by Silas Graffy on 08.03.25.
//  Moved into the shared AmbilightCore package for the universal port.
//
//  NOTE: the production class name is intentionally `SessionFactorty` (typo
//  preserved from the original tvOS app so behaviour stays identical).
//

import Alamofire
import CommonCrypto
import Foundation

public class SessionFactorty: SessionFactoryProtocol {

    public init() {}

    public func makeSession() -> Session {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = 300

        let evaluators: [String: ServerTrustEvaluating] = [
            "*": DisabledTrustEvaluator()
        ]

        let manager = WildcardServerTrustPolicyManager(evaluators: evaluators)

        return Session(configuration: configuration, serverTrustManager: manager)
    }
}

public class WildcardServerTrustPolicyManager: ServerTrustManager, @unchecked Sendable {
    public override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        if let policy = evaluators[host] {
            return policy
        }

        return evaluators["*"]
    }
}
