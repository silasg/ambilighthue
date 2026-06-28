//
//  AmbilightTvProtocol.swift
//  ambilighthue
//
//  Created by Silas Graffy on 01.03.25.
//


import Foundation
import Alamofire
import CommonCrypto

protocol AmbilightTvProtocol: ObservableObject {
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

enum AmbilightHueMode {
    case enabled, disabled
}

protocol SessionFactoryProtocol {
    func makeSession() -> Session
}
