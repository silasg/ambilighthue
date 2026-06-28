//
//  WatchControlViewTests.swift
//  ambilighthue-watchOSTests
//
//  Behavioural tests for the minimal watch UI using ViewInspector. watchOS has
//  no UIHostingController, so these inspect the view directly (no onAppear).
//  The On/Off buttons must drive the shared logic stub.
//

import XCTest
import ViewInspector
import SwiftUI
import AmbilightCore
@testable import ambilighthue_watchOS

final class WatchControlViewTests: XCTestCase {

    private func configuredStub(_ state: AmbilightHueMode?) -> AmbilightTvStub {
        let config = AmbilightTvConfig.configure(tvIp: "ip", username: "u", password: "p")
        return AmbilightTvStub(stateToBeReturnedByUpdateState: state, config: config)
    }

    func test_on_button_tap_enables_ambilight() throws {
        // arrange
        let stub = configuredStub(.disabled)
        let view = WatchControlView(ambilightTv: stub)
        let button = try view.inspect().find(button: "On")

        // act
        try button.tap()

        // assert
        XCTAssertEqual(stub.currentState, .enabled)
    }

    func test_off_button_tap_disables_ambilight() throws {
        // arrange
        let stub = configuredStub(.enabled)
        let view = WatchControlView(ambilightTv: stub)
        let button = try view.inspect().find(button: "Off")

        // act
        try button.tap()

        // assert
        XCTAssertEqual(stub.currentState, .disabled)
    }

    func test_shows_not_configured_message_when_unconfigured() throws {
        // arrange
        AmbilightTvConfig.clear()
        let stub = AmbilightTvStub(stateToBeReturnedByUpdateState: nil, config: nil)
        let view = WatchControlView(ambilightTv: stub)

        // act / assert
        XCTAssertNoThrow(try view.inspect().find(text: "Not configured"))
    }
}
