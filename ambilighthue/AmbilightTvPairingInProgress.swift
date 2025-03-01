//
//  AmbilightTvPairingInProgress.swift
//  ambilighthue
//
//  Created by Silas Graffy on 01.03.25.
//


import Foundation
import Alamofire
import CommonCrypto

class AmbilightTvPairingInProgress {
    var tvIp: String
    var deviceId: String
    var authKey: String
    var timeStamp: Int
    
    init(tvIp: String, deviceId: String, authKey: String, timeStamp: Int) {
        self.tvIp = tvIp
        self.deviceId = deviceId
        self.authKey = authKey
        self.timeStamp = timeStamp
    }
}