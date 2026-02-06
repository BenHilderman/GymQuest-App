import XCTest
import SwiftUI
import SwiftData
import SnapshotTesting
@testable import GymQuest

final class LoginViewSnapshotTests: SnapshotTestCase {

    @MainActor
    func testLoginView_defaultState() {
        // First run: set record = true to generate reference images
        // After recording: set record = false to verify
        // record = true

        let container = try! TestModelContainer.create()
        let appState = AppState()
        let authService = AuthService()
        authService.setModelContext(container.mainContext)

        let view = LoginView()
            .environmentObject(appState)
            .environmentObject(authService)
            .modelContainer(container)

        assertSnapshot(of: view, named: "LoginView-default")
    }
}
