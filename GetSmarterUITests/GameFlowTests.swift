import XCTest

final class GameFlowTests: XCTestCase {
    @MainActor
    func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-onboarded", "YES"]
        app.launch()
        return app
    }

    @MainActor
    func open(_ game: String, in app: XCUIApplication) {
        app.staticTexts[game].tap()
        app.buttons["Beginner"].firstMatch.tap()
        app.buttons["Skip to game"].tap()
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

extension GameFlowTests {
    @MainActor
    func testSequenceEchoAcceptsInputAfterPlayback() {
        let app = launch()
        open("Sequence Echo", in: app)
        XCTAssertTrue(app.staticTexts["Watch…"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your turn"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Star"].isEnabled)
    }
}

extension GameFlowTests {
    @MainActor
    func testNBackShowsMatchButton() {
        let app = launch()
        open("N-Back", in: app)
        let button = app.buttons["Position match"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1/21"].waitForExistence(timeout: 3))
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(app.buttons["Sound match"].exists)
    }
}

extension GameFlowTests {
    @MainActor
    func testWordRecallStudyThenTest() {
        let app = launch()
        open("Word Recall", in: app)
        XCTAssertTrue(app.staticTexts["Word 1 of 8"].waitForExistence(timeout: 3))
        // 8 words × 2.4 s ≈ 19 s of study.
        let done = app.buttons["Done (0 selected)"]
        XCTAssertTrue(done.waitForExistence(timeout: 25))
        done.tap()
        XCTAssertTrue(app.staticTexts["Score"].waitForExistence(timeout: 3))
    }
}

extension GameFlowTests {
    @MainActor
    func testDailyTrainingStartsWithPairMatch() {
        let app = launch()
        app.staticTexts["Daily Training"].tap()
        app.buttons["Start training"].tap()
        XCTAssertTrue(app.staticTexts["Level 4"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Pause"].exists)
    }
}

extension GameFlowTests {
    @MainActor
    func testPracticeRoundReturnsToIntro() {
        let app = launch()
        app.staticTexts["Sequence Echo"].tap()
        app.buttons["Beginner"].firstMatch.tap()
        app.buttons["Try a practice round"].tap()
        XCTAssertTrue(app.staticTexts["Practice round: not scored"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your turn"].waitForExistence(timeout: 6))
        // Wrong answer on purpose: any tile that is not first ends the one-trial practice.
        for name in ["Star", "Heart", "Moon", "Sun"] where app.staticTexts["Your turn"].exists {
            app.buttons[name].tap()
        }
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
    }
}
