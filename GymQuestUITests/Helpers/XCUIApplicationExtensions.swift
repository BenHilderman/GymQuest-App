import XCTest

extension XCUIApplication {

    /// Waits for an element to exist with a configurable timeout
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Launches the app with common test launch arguments
    func launchForTesting() {
        launchArguments += ["-UITesting"]
        launch()
    }
}
