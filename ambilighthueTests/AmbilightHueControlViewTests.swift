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

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testView() throws {
        // UI tests must launch the application that they test.
        let view = AmbilightHueControlView(ambilightTv: AmbilightTv(config: AmbilightTvConfig(), session: nil)) // TODO: mock ambilightTv
        let button = try view.inspect().find(button: "Off")
        let style = try button.buttonStyle()
        let images = button.findAll(ViewType.Image.self)
        
        XCTAssert(style is CardButtonStyle)
       XCTAssertNotNil(button)
      //  XCTAssert(images.count > 0)
        
       

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

}
