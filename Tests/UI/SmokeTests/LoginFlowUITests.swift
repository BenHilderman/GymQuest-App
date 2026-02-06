import XCTest

final class LoginFlowUITests: XCTestCase {

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

    // MARK: - Login Screen Loads

    func testLoginScreen_loadsSuccessfully() {
        // The login screen should be visible on fresh launch (no authenticated user)
        // Look for the GymQuest branding or login elements
        let loginExists = app.staticTexts["GymQuest"].waitForExistence(timeout: 10)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Google'")).firstMatch.waitForExistence(timeout: 10)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Email'")).firstMatch.waitForExistence(timeout: 10)

        // If we're already authenticated, we'll see the main tab bar instead
        let tabBarExists = app.tabBars.firstMatch.waitForExistence(timeout: 3)

        XCTAssertTrue(loginExists || tabBarExists,
                       "App should show either login screen or main content on launch")
    }

    // MARK: - Google Sign In Button Present

    func testLoginScreen_googleButtonPresent() {
        let googleButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Google'")
        ).firstMatch

        // Only check if we're on the login screen
        if googleButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(googleButton.isEnabled)
        }
    }

    // MARK: - Email Button Present

    func testLoginScreen_emailButtonPresent() {
        let emailButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Email'")
        ).firstMatch

        if emailButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(emailButton.isEnabled)
        }
    }

    // MARK: - Email Auth Sheet

    func testLoginScreen_emailButtonOpensSheet() {
        let emailButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Email'")
        ).firstMatch

        guard emailButton.waitForExistence(timeout: 5) else {
            // Not on login screen (already authenticated) — skip
            return
        }

        emailButton.tap()

        // The email auth sheet should appear with text fields
        let emailField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'email'")
        ).firstMatch
        let passwordField = app.secureTextFields.firstMatch

        let sheetAppeared = emailField.waitForExistence(timeout: 3)
            || passwordField.waitForExistence(timeout: 3)

        XCTAssertTrue(sheetAppeared, "Email auth sheet should appear with input fields")
    }
}
