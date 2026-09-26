import XCTest

final class GameCenterTests: XCTestCase {
    @MainActor
    func testLeaderboardsAskToSignInWhenSignedOut() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-onboarded", "YES"]
        app.launch()
        app.buttons["Leaderboards"].tap()
        XCTAssertTrue(app.staticTexts["Sign in to Game Center"].waitForExistence(timeout: 3))
    }
}
