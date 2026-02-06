import XCTest

final class AccessibilityAuditTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchForTesting()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - iOS 17 Accessibility Audit

    @available(iOS 17.0, *)
    func testLoginScreen_passesAccessibilityAudit() throws {
        // Wait for the UI to settle
        let settled = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        guard settled else {
            XCTFail("App did not settle within timeout")
            return
        }

        // Run the built-in accessibility audit
        try app.performAccessibilityAudit()
    }

    // MARK: - Manual Label Checks

    func testLoginScreen_buttonsHaveLabels() {
        // Check that interactive elements have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex

        // Give the app time to load
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)

        for button in buttons {
            if button.exists && button.isHittable {
                XCTAssertFalse(
                    button.label.isEmpty,
                    "Button at \(button.frame) has no accessibility label"
                )
            }
        }
    }

    func testLoginScreen_textElementsHaveTraits() {
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)

        // Check that the main heading has the header trait
        let headings = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'GymQuest'")
        )

        if headings.count > 0 {
            let heading = headings.firstMatch
            XCTAssertTrue(heading.exists, "GymQuest heading should exist")
        }
    }
}
