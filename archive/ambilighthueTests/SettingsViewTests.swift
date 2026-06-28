//  SettingsViewTests.swift
//  ambilighthueTests
//
//  Created by Silas Graffy on 25.03.25.
//

import SwiftUI
import ViewInspector
import XCTest

@testable import ambilighthue

extension InspectableAlert: PopupPresenter { }

final class SettingsViewTests: XCTestCase {

    override func setUpWithError() throws {
        // Setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Teardown code here. This method is called after the invocation of each test method in the class.
    }

    let config: AmbilightTvConfig = AmbilightTvConfig.configure(
        tvIp: "ip", username: "username", password: "password")

    func test_ip_address_input_lost_focus_triggers_pairing() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = SettingsView(ambilightTv: mockedTv)
        let hostingController = UIHostingController(rootView: view)
        hostingController.forceRenderToTriggerUpdateOnAppear()
        let ipInput = try view.inspect().find(
            ViewType.TextField.self, where: { try $0.prompt().string() == "TV IP Address" }
        )

        // act
        try ipInput.setInput("new_ip")

        // assert
        XCTAssertNotNil(mockedTv.pairingInProgress)
    }
    
    func testAlertExample() throws {
        let binding = Binding(wrappedValue: true)
        let sut = EmptyView().alert2(isPresented: binding) {
            Alert(title: Text("Title"), message: Text("Message"),
                  primaryButton: .destructive(Text("Delete")),
                  secondaryButton: .cancel(Text("Cancel")))
        }
        let alert = try sut.inspect().emptyView().alert()
        XCTAssertEqual(try alert.title().string(), "Title")
       // XCTAssertEqual(try alert.message().string(), "Message")
        XCTAssertEqual(try alert.primaryButton().style(), .destructive)
        try sut.inspect().find(ViewType.AlertButton.self, containing: "Cancel").tap()
    }


    func test_pin_alert_is_presented_when_pairing_in_progress() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = SettingsView(ambilightTv: mockedTv)
        let hostingController = UIHostingController(rootView: view)
        hostingController.forceRenderToTriggerUpdateOnAppear()

        // act
        mockedTv.startPairing(tvIp: "mock.ip")
       
        // assert
        let alert2 = try view.inspect().alert()
        XCTAssertNotNil(alert2)
    }

    func test_reset_button_clears_settings() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = SettingsView(ambilightTv: mockedTv)
        let hostingController = UIHostingController(rootView: view)
        hostingController.forceRenderToTriggerUpdateOnAppear()

        // act
        try view.inspect().find(button: "Reset").tap()

        // assert
        XCTAssertEqual(mockedTv.config?.tvIp, "")
        XCTAssertEqual(mockedTv.config?.username, "")
        XCTAssertEqual(mockedTv.config?.password, "")
    }

    func test_close_button_dismisses_view() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = SettingsView(ambilightTv: mockedTv)
        let hostingController = UIHostingController(rootView: view)
        hostingController.forceRenderToTriggerUpdateOnAppear()

        // act
        try view.inspect().find(button: "Close").tap()

        // assert
        XCTAssertTrue(hostingController.isBeingDismissed)
    }

    func test_disabled_fields_display_correct_information() throws {
        // arrange
        let mockedTv = AmbilightTvStub(stateToBeReturnedByUpdateState: .disabled, config: config)
        let view = SettingsView(ambilightTv: mockedTv)
        let hostingController = UIHostingController(rootView: view)
        hostingController.forceRenderToTriggerUpdateOnAppear()

        // act
        let usernameField = try view.inspect().find(
            ViewType.TextField.self,
            where: { try $0.prompt().string() == "TV API user will be shown here" })
        let passwordField = try view.inspect().find(
            ViewType.TextField.self,
            where: { try $0.prompt().string() == "TV API secret will be shown here" })

        // assert
        XCTAssertEqual(try usernameField.input(), "username")
        XCTAssertEqual(try passwordField.input(), "password")
    }
}
