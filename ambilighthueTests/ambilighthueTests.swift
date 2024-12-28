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

final class ambilighthueTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        Mocker.removeAll()
    }

    func test_update_state_to_enabled_when_power_on_is_returned_by_tvendpoint() throws {
         // arrange
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        let sessionManager = Alamofire.Session(configuration: configuration)
        let tvip = "mocked.tv"
        let tvendpoint = URL(string: "https://\(tvip):1926/6/HueLamp/power")!
        
        let mock = Mock(url: tvendpoint, contentType: .json, statusCode: 200, data: [
            .get : "{\"power\":\"On\"}".data(using: .utf8).unsafelyUnwrapped
        ])
        mock.register()
        
        let config = AmbilightTvConfig()
        config.configure(tvIp: tvip, username: "usr", password: "pwd")
        let sut = AmbilightTv(config: config, session: sessionManager)
        
        // act
        sut.updateState()
        
        // assert
        let ambilightHueEnabledExpectation = expectation(for: sut.currentState == Optional(AmbilightHueMode.enabled))
        wait(for: [ambilightHueEnabledExpectation], timeout: 2.0)
    }
    
    func test_post_power_on_to_tvendpoint_when_state_is_updated_to_enabled() throws {
         // arrange
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        let sessionManager = Alamofire.Session(configuration: configuration)
        let tvip = "mocked.tv"
        let tvendpoint = URL(string: "https://\(tvip):1926/6/HueLamp/power")!
        
        var mock = Mock(url: tvendpoint, contentType: .json, statusCode: 200, data: [
            .post : Data(), .get: "{\"power\":\"Off\"}".data(using: .utf8).unsafelyUnwrapped
        ])
        mock.onRequestHandler = OnRequestHandler(httpBodyType: [String:String].self, callback: { request, postBodyArguments in
            XCTAssertEqual(request.url, mock.request.url)
            if (request.method == .post) {
                XCTAssertEqual(["power": "On"], postBodyArguments)
            }
        })
        mock.register()
        
        let config = AmbilightTvConfig()
        config.configure(tvIp: tvip, username: "usr", password: "pwd")
        let sut = AmbilightTv(config: config, session: sessionManager)
        
        // act
        sut.setAmbilightHueMode(newMode: AmbilightHueMode.enabled)
        
        // assert
        let ambilightHueEnabledExpectation = expectation(for: sut.currentState == Optional(AmbilightHueMode.enabled))
        wait(for: [ ambilightHueEnabledExpectation], timeout: 2.0)
    }
    
    func test_post_power_off_to_tvendpoint_when_state_is_updated_to_disabled() throws {
         // arrange
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        let sessionManager = Alamofire.Session(configuration: configuration)
        let tvip = "mocked.tv"
        let tvendpoint = URL(string: "https://\(tvip):1926/6/HueLamp/power")!
        
        var mock = Mock(url: tvendpoint, contentType: .json, statusCode: 200, data: [
            .post : Data(), .get: "{\"power\":\"On\"}".data(using: .utf8).unsafelyUnwrapped
        ])
        mock.onRequestHandler = OnRequestHandler(httpBodyType: [String:String].self, callback: { request, postBodyArguments in
            XCTAssertEqual(request.url, mock.request.url)
            if (request.method == .post) {
                XCTAssertEqual(["power": "Off"], postBodyArguments)
            }
        })
        mock.register()
        
        let config = AmbilightTvConfig()
        config.configure(tvIp: tvip, username: "usr", password: "pwd")
        let sut = AmbilightTv(config: config, session: sessionManager)
        
        // act
        sut.setAmbilightHueMode(newMode: AmbilightHueMode.disabled)
        
        // assert
        let ambilightHueEnabledExpectation = expectation(for: sut.currentState == Optional(AmbilightHueMode.disabled))
        wait(for: [ ambilightHueEnabledExpectation], timeout: 2.0)
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
