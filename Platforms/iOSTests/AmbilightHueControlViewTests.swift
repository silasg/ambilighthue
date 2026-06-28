//
//  AmbilightHueControlViewTests.swift
//  ambilighthue-iOSTests
//
//  Ported from the tvOS view tests. Exercises the iOS-adapted control view via
//  ViewInspector + UIHostingController (UIKit is available on iOS). The shared
//  logic stub and enums come from AmbilightCore.
//

import XCTest
import ViewInspector
import SwiftUI
import AmbilightCore
@testable import ambilighthue_iOS

extension UIHostingController {
    fileprivate func forceRenderToTriggerUpdateOnAppear() {
        _render(seconds: 0)
    }
}

final class AmbilightHueControlViewTests: XCTestCase {

    let config: AmbilightTvConfig = AmbilightTvConfig.configure(tvIp: "ip", username: "username", password: "password")

    func test_view_updates_state_on_init() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)

        // act
        UIHostingController(rootView: AmbilightHueControlView(ambilightTv: mockedTv)).forceRenderToTriggerUpdateOnAppear()

        // assert
        XCTAssertEqual(mockedTv.currentState, .disabled)
    }

    func test_off_button_has_image_if_ambilighttv_is_disabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        UIHostingController(rootView: view).forceRenderToTriggerUpdateOnAppear()

        // act
        let button = try view.inspect().find(button: "Off")

        // assert
        XCTAssert(button.findAll(ViewType.Image.self).count > 0)
    }

    func test_on_button_has_image_if_ambilighttv_is_enabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled, config: config)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        UIHostingController(rootView: view).forceRenderToTriggerUpdateOnAppear()

        // act
        let button = try view.inspect().find(button: "On")

        // assert
        XCTAssert(button.findAll(ViewType.Image.self).count > 0)
    }

    func test_off_button_tap_disables_ambilight() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled, config: config)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        UIHostingController(rootView: view).forceRenderToTriggerUpdateOnAppear()
        let button = try view.inspect().find(button: "Off")

        // act
        try button.tap()

        // assert
        XCTAssertEqual(mockedTv.currentState, AmbilightHueMode.disabled)
    }

    func test_on_button_tap_enables_ambilight() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        UIHostingController(rootView: view).forceRenderToTriggerUpdateOnAppear()
        let button = try view.inspect().find(button: "On")

        // act
        try button.tap()

        // assert
        XCTAssertEqual(mockedTv.currentState, AmbilightHueMode.enabled)
    }

    func test_stack_has_angulargradient_background_if_ambilighttv_is_enabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .enabled, config: config)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        UIHostingController(rootView: view).forceRenderToTriggerUpdateOnAppear()
        let backgroundGroup = try view.inspect().find(ViewType.VStack.self).background().group()

        // act
        let backgroundGradients = backgroundGroup.findAll(AngularGradient.self)

        // assert
        XCTAssertEqual(backgroundGradients.count, 1)
    }

    func test_stack_has_no_angulargradient_background_if_ambilighttv_is_disabled() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = AmbilightHueControlView(ambilightTv: mockedTv)
        UIHostingController(rootView: view).forceRenderToTriggerUpdateOnAppear()
        let backgroundGroup = try view.inspect().find(ViewType.VStack.self).background().group()

        // act
        let backgroundGradients = backgroundGroup.findAll(AngularGradient.self)

        // assert
        XCTAssertEqual(backgroundGradients.count, 0)
    }
}
