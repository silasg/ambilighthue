//
//  helloworldTests.swift
//  helloworldTests
//
//  Created by Silas Graffy on 23.06.24.
//

import XCTest
import Mocker
import Alamofire
@testable import ambilighthue

final class AmbilightTvTests: XCTestCase {

    static let configuration = URLSessionConfiguration.af.default;
    static let sessionManager = Alamofire.Session(configuration: configuration);
    static let tvip = "mocked.tv";
    static let tvendpoint = URL(string: "https://\(tvip):1926/6/HueLamp/power")!;
    
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        AmbilightTvTests.configuration.protocolClasses = [MockingURLProtocol.self];
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        Mocker.removeAll()
    }

    func test_update_state_to_enabled_when_power_on_is_returned_by_tvendpoint() throws {
         // arrange
        let mock = Mock(url: AmbilightTvTests.tvendpoint, contentType: .json, statusCode: 200, data: [
            .get : "{\"power\":\"On\"}".data(using: .utf8).unsafelyUnwrapped
        ])
        mock.register()
        
        let sut = createAmbilightTvForTest()
        
        // act
        sut.updateState()
        
        // assert
        let ambilightHueEnabledExpectation = expectation(for: sut.currentState == Optional(AmbilightHueMode.enabled))
        wait(for: [ambilightHueEnabledExpectation], timeout: 5.0)
    }
    
    func test_post_power_on_to_tvendpoint_when_mode_set_to_enabled() throws {
         // arrange
        var mock = Mock(url: AmbilightTvTests.tvendpoint, contentType: .json, statusCode: 200, data: [
            .post : Data(), .get: "{\"power\":\"Off\"}".data(using: .utf8).unsafelyUnwrapped
        ])
        let expectedBodyArguments = expectation(description: "The body sent to TV to set state to enabled")
        mock.onRequestHandler = OnRequestHandler(httpBodyType: [String:String].self, callback: { request, postBodyArguments in
            if (request.method == .post && postBodyArguments == ["power": "On"]) {
                expectedBodyArguments.fulfill()
            }
        })
        mock.register()
        
        let sut = createAmbilightTvForTest()
        
        
        // act
        sut.setAmbilightHueMode(newMode: AmbilightHueMode.enabled)
        
        // assert
        let ambilightHueEnabledExpectation = expectation(for: sut.currentState == Optional(AmbilightHueMode.enabled))
        wait(for: [ expectedBodyArguments, ambilightHueEnabledExpectation], timeout: 5.0)
    }
    
    func test_post_power_off_to_tvendpoint_when_mode_set_to_disabled() throws {
         // arrange
        var mock = Mock(url: AmbilightTvTests.tvendpoint, contentType: .json, statusCode: 200, data: [
            .post : Data(), .get: "{\"power\":\"On\"}".data(using: .utf8).unsafelyUnwrapped
        ])
        let expectedBodyArguments = expectation(description: "The body sent to TV to set state to disabled")
        mock.onRequestHandler = OnRequestHandler(httpBodyType: [String:String].self, callback: { request, postBodyArguments in
            if (request.method == .post && postBodyArguments == ["power": "Off"]) {
                expectedBodyArguments.fulfill()
            }
        })
        mock.register()
        
        let sut = createAmbilightTvForTest()
        
        // act
        sut.setAmbilightHueMode(newMode: AmbilightHueMode.disabled)
        
        // assert
        let ambilightHueDisabledExpectation = expectation(for: sut.currentState == Optional(AmbilightHueMode.disabled))
        wait(for: [ expectedBodyArguments, ambilightHueDisabledExpectation], timeout: 5.0)
    }
    
    private func createAmbilightTvForTest() -> AmbilightTv {
        let config = AmbilightTvConfig()
        config.configure(tvIp: AmbilightTvTests.tvip, username: "usr", password: "pwd")
        return AmbilightTv(config: config, session: AmbilightTvTests.sessionManager)
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
