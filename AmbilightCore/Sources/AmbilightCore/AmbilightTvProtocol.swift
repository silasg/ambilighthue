//
//  AmbilightTvProtocol.swift
//  AmbilightCore
//
//  Created by Silas Graffy on 01.03.25.
//  Moved into the shared AmbilightCore package for the universal port.
//


import Foundation
import Alamofire
import CommonCrypto

public protocol AmbilightTvProtocol: ObservableObject {
    func updateState()
    func setAmbilightHueMode(newMode: AmbilightHueMode)
    var currentState: AmbilightHueMode? { get }
    var log: String { get }
    var isConfigured: Bool { get }
    var config: AmbilightTvConfig? { get }
    func startPairing(tvIp: String)
    var pairingInProgress: AmbilightTvPairingInProgress? { get }
    func confirmPairing(tvPin: String, pairing: AmbilightTvPairingInProgress)
    func resetPairing()
}

public enum AmbilightHueMode {
    case enabled, disabled
}

public protocol SessionFactoryProtocol {
    func makeSession() -> Session
}
