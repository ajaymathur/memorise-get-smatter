import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testMenuListsAllGames() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        for title in ["Pair Match", "Sequence Echo", "N-Back", "Word Recall"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), title)
        }
    }
}
