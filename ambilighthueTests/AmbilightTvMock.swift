//
//  AmbilightTvMock.swift
//  ambilighthue
//
//  Created by Silas Graffy on 31.12.24.
//


import XCTest
import ViewInspector
@testable import ambilighthue
import SwiftUI

class AmbilightTvMock: AmbilightTvProtocol {
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
