import XCTest
import SwiftData
@testable import GymQuest

final class AIServiceNetworkTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var aiService: AIService!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! TestModelContainer.create()
        context = container.mainContext
        aiService = AIService()
        URLSessionTestSetup.install()
    }

    override func tearDown() {
        URLSessionTestSetup.uninstall()
        container = nil
        context = nil
        aiService = nil
        super.tearDown()
    }

    // MARK: - OpenAI Stubbed Call

    @MainActor
    func testCallOpenAI_parsesStubbedResponse() async throws {
        let fixtureData = TestFixtures.loadFixture("openai_chat_response")
        MockURLProtocol.stubbedResponses["api.openai.com"] = StubbedResponse(data: fixtureData)

        let profile = TestFixtures.makeUserProfile(aiProvider: .openai, email: "test@test.com")
        profile.apiKey = "sk-test-key-12345"
        context.insert(profile)

        let workouts = [TestFixtures.makeWorkout()]

        let response = try await aiService.chat(
            prompt: "How should I train today?",
            profile: profile,
            workouts: workouts,
            modelContext: context
        )

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains("bench") || response.contains("push") || response.contains("185"),
                       "Response should contain content from the fixture")
    }

    // MARK: - Groq Stubbed Call

    @MainActor
    func testCallGroq_parsesStubbedResponse() async throws {
        let fixtureData = TestFixtures.loadFixture("groq_chat_response")
        MockURLProtocol.stubbedResponses["api.groq.com"] = StubbedResponse(data: fixtureData)

        let profile = TestFixtures.makeUserProfile(aiProvider: .groq, email: "test@test.com")
        profile.apiKey = "gsk-test-key-12345"
        context.insert(profile)

        let workouts = [TestFixtures.makeWorkout()]

        let response = try await aiService.chat(
            prompt: "Give me feedback on my pull day",
            profile: profile,
            workouts: workouts,
            modelContext: context
        )

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains("pull") || response.contains("deadlift") || response.contains("315"),
                       "Response should contain content from the fixture")
    }

    // MARK: - Missing API Key

    @MainActor
    func testMissingAPIKey_throwsError() async {
        let profile = TestFixtures.makeUserProfile(aiProvider: .openai, email: "test@test.com")
        profile.apiKey = "" // Empty key
        context.insert(profile)

        do {
            let _ = try await aiService.chat(
                prompt: "Test",
                profile: profile,
                workouts: [],
                modelContext: context
            )
            XCTFail("Should have thrown AIError.missingAPIKey")
        } catch {
            // Verify it's the right error type
            XCTAssertTrue(error is AIError, "Expected AIError but got \(type(of: error))")
        }
    }

    // MARK: - Demo Mode (No Network)

    @MainActor
    func testDemoMode_returnsResponseWithoutNetwork() async throws {
        // Don't stub any URLs — demo mode shouldn't hit the network
        let profile = TestFixtures.makeUserProfile(aiProvider: .demo, email: "test@test.com")
        context.insert(profile)

        let workouts = [TestFixtures.makeWorkout()]

        let response = try await aiService.chat(
            prompt: "What should I focus on?",
            profile: profile,
            workouts: workouts,
            modelContext: context
        )

        XCTAssertFalse(response.isEmpty, "Demo mode should return a rule-based response")
    }

    // MARK: - Request Logging

    @MainActor
    func testChat_logsRequestToAILogEntry() async throws {
        let fixtureData = TestFixtures.loadFixture("openai_chat_response")
        MockURLProtocol.stubbedResponses["api.openai.com"] = StubbedResponse(data: fixtureData)

        let profile = TestFixtures.makeUserProfile(aiProvider: .openai, email: "test@test.com")
        profile.apiKey = "sk-test-key"
        context.insert(profile)

        let _ = try await aiService.chat(
            prompt: "Log this request",
            profile: profile,
            workouts: [],
            modelContext: context
        )

        // Verify AILogEntry was created
        let descriptor = FetchDescriptor<AILogEntry>()
        let logs = try context.fetch(descriptor)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.prompt, "Log this request")
        XCTAssertFalse(logs.first?.response.isEmpty ?? true)
    }

    // MARK: - Request Inspection

    @MainActor
    func testCallOpenAI_sendsCorrectHeaders() async throws {
        let fixtureData = TestFixtures.loadFixture("openai_chat_response")
        MockURLProtocol.stubbedResponses["api.openai.com"] = StubbedResponse(data: fixtureData)

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
        }

        let profile = TestFixtures.makeUserProfile(aiProvider: .openai, email: "test@test.com")
        profile.apiKey = "sk-test-key-verify"
        context.insert(profile)

        let _ = try await aiService.chat(
            prompt: "Check headers",
            profile: profile,
            workouts: [],
            modelContext: context
        )

        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key-verify")
    }
}
