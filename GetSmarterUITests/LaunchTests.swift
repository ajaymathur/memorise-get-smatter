import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Get Smarter"].waitForExistence(timeout: 5))
    }
}
