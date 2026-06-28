//
//  AmbilightTvPairingInProgress.swift
//  AmbilightCore
//
//  Created by Silas Graffy on 01.03.25.
//  Moved into the shared AmbilightCore package for the universal port.
//


import Foundation
import Alamofire
import CommonCrypto

public class AmbilightTvPairingInProgress {
    public var tvIp: String
    public var deviceId: String
    public var authKey: String
    public var timeStamp: Int

    public init(tvIp: String, deviceId: String, authKey: String, timeStamp: Int) {
        self.tvIp = tvIp
        self.deviceId = deviceId
        self.authKey = authKey
        self.timeStamp = timeStamp
    }

    public func createSignature(tvPin: String) -> String {
        let toSign = "\(tvPin)\(timeStamp)"

        let secretKey: String = "oEC9Uhg5xbg566mpYPjhoWUwFtFAwTFoTW1By0vaOD4="
         guard let keyData = Data(base64Encoded: secretKey),
             let toSignData = toSign.data(using: .utf8)
         else { return "" }

         var hmac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
         keyData.withUnsafeBytes { keyBytes in
             toSignData.withUnsafeBytes { toSignBytes in
                 CCHmac(
                     CCHmacAlgorithm(kCCHmacAlgSHA1), keyBytes.baseAddress, keyData.count,
                     toSignBytes.baseAddress, toSignData.count, &hmac)
             }
         }

         let hmacData = Data(hmac)
         return hmacData.base64EncodedString()
     }
}
