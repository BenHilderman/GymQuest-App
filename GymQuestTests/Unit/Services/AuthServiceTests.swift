import XCTest
import SwiftData
@testable import GymQuest

final class AuthServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var authService: AuthService!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! TestModelContainer.create()
        context = container.mainContext
        authService = AuthService()
        authService.setModelContext(context)
    }

    override func tearDown() {
        container = nil
        context = nil
        authService = nil
        super.tearDown()
    }

    // MARK: - hashPassword

    @MainActor
    func testHashPassword_producesConsistent64CharHex() {
        let hash = authService.hashPassword("mypassword123")
        XCTAssertEqual(hash.count, 64) // SHA256 = 32 bytes = 64 hex chars
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    @MainActor
    func testHashPassword_sameInputSameOutput() {
        let hash1 = authService.hashPassword("testpass")
        let hash2 = authService.hashPassword("testpass")
        XCTAssertEqual(hash1, hash2)
    }

    @MainActor
    func testHashPassword_differentInputDifferentOutput() {
        let hash1 = authService.hashPassword("password1")
        let hash2 = authService.hashPassword("password2")
        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - register

    @MainActor
    func testRegister_createsAuthenticatedProfile() {
        let profile = authService.register(
            name: "Test User",
            username: "testuser",
            dateOfBirth: Date(timeIntervalSince1970: 946684800),
            email: "test@test.com",
            password: "password123"
        )

        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.name, "Test User")
        XCTAssertEqual(profile?.username, "testuser")
        XCTAssertEqual(profile?.email, "test@test.com")
        XCTAssertTrue(profile?.isAuthenticated ?? false)
        XCTAssertEqual(profile?.authMethod, "email")
        XCTAssertEqual(profile?.aiProvider, .demo) // Default to demo mode
        XCTAssertNotNil(profile?.passwordHash)
    }

    // MARK: - login

    @MainActor
    func testLogin_succeedsWithCorrectCredentials() {
        // Register first
        let _ = authService.register(
            name: "Login Test",
            username: "logintest",
            dateOfBirth: Date(),
            email: "login@test.com",
            password: "correctpassword"
        )

        // Now logout and login
        let profile = authService.login(email: "login@test.com", password: "correctpassword")
        XCTAssertNotNil(profile)
        XCTAssertTrue(profile?.isAuthenticated ?? false)
    }

    @MainActor
    func testLogin_returnsNilWithWrongPassword() {
        let _ = authService.register(
            name: "Wrong Pass Test",
            username: "wrongpasstest",
            dateOfBirth: Date(),
            email: "wrong@test.com",
            password: "rightpassword"
        )

        let profile = authService.login(email: "wrong@test.com", password: "wrongpassword")
        XCTAssertNil(profile)
    }

    @MainActor
    func testLogin_returnsNilForNonexistentEmail() {
        let profile = authService.login(email: "nonexistent@test.com", password: "anything")
        XCTAssertNil(profile)
    }

    // MARK: - emailExists

    @MainActor
    func testEmailExists_trueForRegisteredEmail() {
        let _ = authService.register(
            name: "Email Test",
            username: "emailtest",
            dateOfBirth: Date(),
            email: "exists@test.com",
            password: "password"
        )

        XCTAssertTrue(authService.emailExists("exists@test.com"))
    }

    @MainActor
    func testEmailExists_falseForUnregisteredEmail() {
        XCTAssertFalse(authService.emailExists("nope@test.com"))
    }

    // MARK: - logout

    @MainActor
    func testLogout_setsIsAuthenticatedFalse() {
        let profile = authService.register(
            name: "Logout Test",
            username: "logouttest",
            dateOfBirth: Date(),
            email: "logout@test.com",
            password: "password"
        )!

        XCTAssertTrue(profile.isAuthenticated)
        authService.logout(profile: profile)
        XCTAssertFalse(profile.isAuthenticated)
    }
}
