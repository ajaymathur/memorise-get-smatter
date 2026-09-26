import XCTest

final class OnboardingTests: XCTestCase {
    @MainActor
    func testOnboardingShowsOnceAndCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Get Smarter"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Honest science"].waitForExistence(timeout: 2))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.staticTexts["Daily Training"].waitForExistence(timeout: 3))
    }
}
