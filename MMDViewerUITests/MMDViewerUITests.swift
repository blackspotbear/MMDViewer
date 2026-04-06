import XCTest

final class MMDViewerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsPlayPauseButton() throws {
        let app = XCUIApplication()

        app.launch()

        let playPauseButton = app.buttons["playPauseButton"]
        XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5))
        XCTAssertEqual(playPauseButton.label, "Pause")
    }

    func testPlayPauseButtonTogglesTitle() throws {
        let app = XCUIApplication()

        app.launch()

        let playPauseButton = app.buttons["playPauseButton"]
        XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5))

        playPauseButton.tap()
        XCTAssertEqual(playPauseButton.label, "Play")

        playPauseButton.tap()
        XCTAssertEqual(playPauseButton.label, "Pause")
    }
}
