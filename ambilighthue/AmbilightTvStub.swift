//
//  AmbilightTvMock.swift
//  ambilighthue
//
//  Created by Silas Graffy on 31.12.24.
//

import SwiftUI

class AmbilightTvStub: AmbilightTvProtocol {
    static func startPairing(tvIp: String) -> AmbilightTvPairingInProgress {
        return AmbilightTvPairingInProgress(tvIp: tvIp, deviceId: "mocked device id", authKey: "mocked auth key", timeStamp: 1)
    }
    
    static func confirmPairing(tvPin: String, pairing: AmbilightTvPairingInProgress) -> AmbilightTvConfig {
        return AmbilightTvConfig.configure(tvIp: pairing.tvIp, username: pairing.deviceId, password: pairing.authKey)
    }
    
    init(stateToBeReturnedByUpdateState: ambilighthue.AmbilightHueMode?) {
        self.stateToBeReturnedByUpdateState = stateToBeReturnedByUpdateState
    }
    
    func updateState() {
        currentState = stateToBeReturnedByUpdateState
    }
    
    func setAmbilightHueMode(newMode: ambilighthue.AmbilightHueMode) {
        currentState = newMode
    }
    
    var currentState: ambilighthue.AmbilightHueMode? = nil
    
    var log = "as a mock, I don't log anything"
    var stateToBeReturnedByUpdateState: ambilighthue.AmbilightHueMode?;
}
