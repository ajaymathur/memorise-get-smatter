import XCTest

final class GameFlowTests: XCTestCase {
    @MainActor
    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        return app
    }

    @MainActor
    func open(_ game: String, in app: XCUIApplication) {
        app.staticTexts[game].tap()
        app.buttons["Beginner"].firstMatch.tap()
        app.buttons["Start"].tap()
    }

    @MainActor
    func testPairMatchShowsBoardAndPauses() {
        let app = launch()
        open("Pair Match", in: app)
        XCTAssertTrue(app.staticTexts["Memorise!"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Row 1, column 1, face down"].waitForExistence(timeout: 5))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].exists)
        XCTAssertFalse(app.buttons["Row 1, column 1, face down"].exists)
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Row 1, column 1, face down"].waitForExistence(timeout: 2))
    }
}
