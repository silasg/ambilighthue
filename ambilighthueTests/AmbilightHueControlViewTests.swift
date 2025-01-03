//
//  helloworldUITests.swift
//  helloworldUITests
//
//  Created by Silas Graffy on 23.06.24.
//

import XCTest
import ViewInspector
@testable import ambilighthue
import SwiftUI



final class AmbilightHueControlViewTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func test_view_updates_state_on_init() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled)
        
        // act
        let _ = AmbilightHueControlView(ambilightTv: mockedTv)
        
        // arrange
        XCTAssertEqual(mockedTv.currentState, .disabled)
    }
    
    func test_off_button_has_image_if_ambilighttv_is_disabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        
        // act
        let button = try view.inspect().find(button: "Off")
        
        // arrange
        XCTAssert(button.findAll(ViewType.Image.self).count > 0)
    }
    
    func test_on_button_has_image_if_ambilighttv_is_enabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        
        // act
        let button = try view.inspect().find(button: "On")
        
        // arrange
        XCTAssert(button.findAll(ViewType.Image.self).count > 0)
    }
    
    func test_off_button_tap_disables_ambilight() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        let button = try view.inspect().find(button: "Off")
        
        // act
        try button.tap()
        
        // arrange
        XCTAssertEqual(mockedTv.currentState, AmbilightHueMode.disabled)
    }
    
    func test_on_button_tap_enables_ambilight() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        let button = try view.inspect().find(button: "On")
        
        // act
        try button.tap()
        
        // arrange
        XCTAssertEqual(mockedTv.currentState, AmbilightHueMode.enabled)
    }
    
    func test_stack_has_angulargradient_background_if_ambilighttv_is_enabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        let backgroundGroup = try view.inspect().find(ViewType.VStack.self).background().group()
        
        // act
        let backgroundGradients = backgroundGroup.findAll(AngularGradient.self)
        
        // arrange
        XCTAssertEqual(backgroundGradients.count, 1)
    }
    
    func test_stack_has_no_angulargradient_background_if_ambilighttv_is_disabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        let backgroundGroup = try view.inspect().find(ViewType.VStack.self).background().group()
        
        // act
        let backgroundGradients = backgroundGroup.findAll(AngularGradient.self)
        
        // arrange
        XCTAssertEqual(backgroundGradients.count, 0)
    }

}
