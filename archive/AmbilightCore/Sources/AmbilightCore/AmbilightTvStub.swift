//
//  AmbilightTvStub.swift
//  AmbilightCore
//
//  Created by Silas Graffy on 31.12.24.
//  Moved into the shared AmbilightCore package for the universal port.
//  Used by SwiftUI previews and by the view tests across all platforms.
//

import Foundation

public class AmbilightTvStub: AmbilightTvProtocol {
    public var pairingInProgress: AmbilightTvPairingInProgress?

    public func resetPairing() {
        config = nil
    }

    public var config: AmbilightTvConfig?

    public var isConfigured: Bool { return config != nil }

    public func startPairing(tvIp: String)  {

    }

    public func confirmPairing(tvPin: String, pairing: AmbilightTvPairingInProgress) {
        config = AmbilightTvConfig.configure(tvIp: pairing.tvIp, username: pairing.deviceId, password: pairing.authKey)
    }

    public init(stateToBeReturnedByUpdateState: AmbilightHueMode?, config: AmbilightTvConfig? = nil) {
        self.stateToBeReturnedByUpdateState = stateToBeReturnedByUpdateState
        self.config = config
    }

    public func updateState() {
        currentState = stateToBeReturnedByUpdateState
    }

    public func setAmbilightHueMode(newMode: AmbilightHueMode) {
        currentState = newMode
    }

    public var currentState: AmbilightHueMode? = nil

    public var log = "as a mock, I don't log anything"
    public var stateToBeReturnedByUpdateState: AmbilightHueMode?
}
