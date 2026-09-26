import XCTest

/// Captures App Store screenshots. Skipped unless run via scripts/screenshots.sh (REQ-RL-02).
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1", "screenshots only on demand")
    }

    @MainActor
    func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Fresh launch per screen keeps each capture independent of navigation state.
    @MainActor
    func launch() {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-onboarded", "YES", "-demo", "-soundOn", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Daily Training"].waitForExistence(timeout: 5))
    }

    @MainActor
    func start(_ game: String) {
        launch()
        app.staticTexts[game].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Beginner'")).firstMatch.tap()
        app.buttons["Skip to game"].tap()
    }

    @MainActor
    func testCaptureScreens() {
        launch()
        snap("01-menu")

        start("Pair Match")
        XCTAssertTrue(app.staticTexts["Memorise!"].waitForExistence(timeout: 3))
        snap("02-pair-match")

        start("Sequence Echo")
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && !app.staticTexts["Watch…"].exists {}
        Thread.sleep(forTimeInterval: 0.35)
        snap("03-sequence-echo")

        start("N-Back")
        XCTAssertTrue(app.staticTexts["1/21"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.1)
        snap("04-n-back")

        launch()
        app.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 3))
        snap("05-progress")

        launch()

        app.buttons["The Science"].tap()
        XCTAssertTrue(app.navigationBars["The Science"].waitForExistence(timeout: 3))
        snap("06-science")
    }
}
