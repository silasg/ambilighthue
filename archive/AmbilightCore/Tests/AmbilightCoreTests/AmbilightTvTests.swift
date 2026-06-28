//
//  AmbilightTvTests.swift
//  AmbilightCoreTests
//
//  Created by Silas Graffy on 23.06.24.
//  Moved into the shared AmbilightCore package for the universal port.
//  Platform-agnostic: exercises the TV-comms / pairing logic only.
//

import Alamofire
import Mocker
import XCTest

@testable import AmbilightCore

final class AmbilightTvTests: XCTestCase {

    private class MockSessionFactory: SessionFactoryProtocol {
        func makeSession() -> Alamofire.Session {
            return Alamofire.Session(configuration: configuration)
        }
    }

    static let configuration = URLSessionConfiguration.af.default
    static let sessionFac: SessionFactoryProtocol = MockSessionFactory()
    static let tvip = "mocked.tv"
    static let HuePowerEndpoint = URL(string: "https://\(tvip):1926/6/HueLamp/power")!
    static let PairGrantEndpoint = URL(string: "https://\(tvip):1926/6/pair/grant")!
    static let PairRequestEndpoint = URL(string: "https://\(tvip):1926/6/pair/request")!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        AmbilightTvTests.configuration.protocolClasses = [MockingURLProtocol.self]
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        Mocker.removeAll()
    }

    func test_update_state_to_enabled_when_power_on_is_returned_by_tvendpoint() throws {
        // arrange
        let mock = Mock(
            url: AmbilightTvTests.HuePowerEndpoint, contentType: .json, statusCode: 200,
            data: [
                .get: "{\"power\":\"On\"}".data(using: .utf8).unsafelyUnwrapped
            ])
        mock.register()

        let sut = createAmbilightTvForTest()

        // act
        sut.updateState()

        // assert
        let ambilightHueEnabledExpectation = expectation(
            for: sut.currentState == Optional(AmbilightHueMode.enabled))
        wait(for: [ambilightHueEnabledExpectation], timeout: 5.0)
    }

    func test_post_power_on_to_tvendpoint_when_mode_set_to_enabled() throws {
        // arrange
        var mock = Mock(
            url: AmbilightTvTests.HuePowerEndpoint, contentType: .json, statusCode: 200,
            data: [
                .post: Data(), .get: "{\"power\":\"Off\"}".data(using: .utf8).unsafelyUnwrapped,
            ])
        let expectedBodyArguments = expectation(
            description: "The body sent to TV to set state to enabled")
        mock.onRequestHandler = OnRequestHandler(
            httpBodyType: [String: String].self,
            callback: { request, postBodyArguments in
                if request.method == .post && postBodyArguments == ["power": "On"] {
                    expectedBodyArguments.fulfill()
                }
            })
        mock.register()

        let sut = createAmbilightTvForTest()

        // act
        sut.setAmbilightHueMode(newMode: AmbilightHueMode.enabled)

        // assert
        let ambilightHueEnabledExpectation = expectation(
            for: sut.currentState == Optional(AmbilightHueMode.enabled))
        wait(for: [expectedBodyArguments, ambilightHueEnabledExpectation], timeout: 5.0)
    }

    func test_post_power_off_to_tvendpoint_when_mode_set_to_disabled() throws {
        // arrange
        var mock = Mock(
            url: AmbilightTvTests.HuePowerEndpoint, contentType: .json, statusCode: 200,
            data: [
                .post: Data(), .get: "{\"power\":\"On\"}".data(using: .utf8).unsafelyUnwrapped,
            ])
        let expectedBodyArguments = expectation(
            description: "The body sent to TV to set state to disabled")
        mock.onRequestHandler = OnRequestHandler(
            httpBodyType: [String: String].self,
            callback: { request, postBodyArguments in
                if request.method == .post && postBodyArguments == ["power": "Off"] {
                    expectedBodyArguments.fulfill()
                }
            })
        mock.register()

        let sut = createAmbilightTvForTest()

        // act
        sut.setAmbilightHueMode(newMode: AmbilightHueMode.disabled)

        // assert
        let ambilightHueDisabledExpectation = expectation(
            for: sut.currentState == Optional(AmbilightHueMode.disabled))
        wait(for: [expectedBodyArguments, ambilightHueDisabledExpectation], timeout: 5.0)
    }

    func test_reset_pairing_clears_credentials_and_config() throws {
        // arrange
        let sut = createAmbilightTvForTest()

        // act
        sut.resetPairing()

        // assert
        XCTAssertNil(sut.credential)
        XCTAssertNil(sut.config)

    }
    
    func test_return_pairing_in_progress_and_set_credentials_when_pairing_requested() throws {
        // arrange
        var mock = Mock(
            url: AmbilightTvTests.PairRequestEndpoint, contentType: .json, statusCode: 200,
            data: [
                .post:
                    "{\"error_id\":\"SUCCESS\",\"error_text\":\"Authorization required\",\"auth_key\":\"a8d1b59ad64689d76b160dae57c396bbf77cbb8f6c98b05751fa75c2c4c61361\",\"timestamp\":55285,\"timeout\":60}"
                    .data(using: .utf8).unsafelyUnwrapped
            ])
        let expectedBodyArguments = expectation(
            description: "The body sent to TV to request pairing")
        struct RequestPars: Decodable {
            let scope: [String]
            let device: [String: String]
        }
        mock.onRequestHandler = OnRequestHandler(
            httpBodyType: RequestPars.self,
            callback: { request, postBodyArguments in
                if request.method == .post
                    && postBodyArguments?.scope == ["read", "write", "control"]
                    && postBodyArguments?.device["device_name"] == "heliotrope"
                    && postBodyArguments?.device["device_os"] == "Android"
                    && postBodyArguments?.device["app_name"] == "AmilightHue"
                    && postBodyArguments?.device["type"] == "native"
                    && postBodyArguments?.device["app_id"] == "app.id"
                {
                    expectedBodyArguments.fulfill()
                }
            })
        mock.register()

        let sut = createAmbilightTvForTest()

        // act
        sut.startPairing(tvIp: AmbilightTvTests.tvip)

        // assert
        let pairingInProgressExpectation = expectation(
            for: sut.pairingInProgress?.authKey
                == "a8d1b59ad64689d76b160dae57c396bbf77cbb8f6c98b05751fa75c2c4c61361"
                && sut.pairingInProgress?.tvIp == AmbilightTvTests.tvip
                && sut.pairingInProgress?.timeStamp == 55285)
        // we dont check for device id since it is randomly generated every time and I dont want to make it mockable
        let credentialAuthKeySetExpectation = expectation(
            for: sut.credential != nil && sut.credential?.password == sut.pairingInProgress?.authKey
        )
        wait(
            for: [
                expectedBodyArguments, pairingInProgressExpectation,
                credentialAuthKeySetExpectation,
            ], timeout: 5.0)
    }
    
    func test_confirm_pairing_sets_config_correctly() throws {
        // arrange
        let pairingInProgress = AmbilightTvPairingInProgress(tvIp: AmbilightTvTests.tvip, deviceId: "mockedDeviceId", authKey: "mockedAuthKey", timeStamp: 12345)
        let tvPin = "1234"
        
        var mock = Mock(
            url: AmbilightTvTests.PairGrantEndpoint, contentType: .json, statusCode: 200,
            data: [.post: Data()])
        let expectedBodyArguments = expectation(description: "The body sent to TV to request pairing")
        struct AuthPars: Decodable {
            let auth_AppId: String
            let pin: String
            let auth_timestamp: Int
            let auth_signature: String
        }
        
        struct RequestPars: Decodable {
            let auth: AuthPars
            let device: [String: String]
        }
        mock.onRequestHandler = OnRequestHandler(
            httpBodyType: RequestPars.self,
            callback: { request, postBodyArguments in
                if request.method == .post
                    && postBodyArguments?.auth.auth_AppId == "1"
                    && postBodyArguments?.auth.pin ==  tvPin
                    && postBodyArguments?.auth.auth_timestamp == pairingInProgress.timeStamp
                    && postBodyArguments?.auth.auth_signature ==  pairingInProgress.createSignature(tvPin: tvPin)
                    && postBodyArguments?.device["device_name"] == "heliotrope"
                    && postBodyArguments?.device["device_os"] == "Android"
                    && postBodyArguments?.device["app_name"] == "AmilightHue"
                    && postBodyArguments?.device["type"] == "native"
                    && postBodyArguments?.device["app_id"] == "app.id"
                    && postBodyArguments?.device["id"] == pairingInProgress.deviceId
                {
                    expectedBodyArguments.fulfill()
                }
            })
        mock.register()
        
        let sut = createAmbilightTvForTest()
        sut.pairingInProgress = pairingInProgress
        
        // act
        sut.confirmPairing(tvPin: tvPin, pairing: pairingInProgress)
        
        // assert
        let configSetExpectation = expectation(for: sut.config?.tvIp == AmbilightTvTests.tvip
                                               && sut.config?.username == pairingInProgress.deviceId
                                               && sut.config?.password == pairingInProgress.authKey)
        wait(for: [ expectedBodyArguments, configSetExpectation,], timeout: 5.0)
    }

    private func createAmbilightTvForTest() -> AmbilightTv {
        let config = AmbilightTvConfig.configure(
            tvIp: AmbilightTvTests.tvip, username: "usr", password: "pwd")
        return AmbilightTv(config: config, sessionFac: AmbilightTvTests.sessionFac)
    }
}

extension XCTestCase {
    func expectation(for condition: @autoclosure @escaping () -> Bool) -> XCTestExpectation {
        let predicate = NSPredicate { _, _ in
            return condition()
        }

        return XCTNSPredicateExpectation(predicate: predicate, object: nil)
    }
}
