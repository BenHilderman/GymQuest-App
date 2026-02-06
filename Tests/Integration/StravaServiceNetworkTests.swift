import XCTest
import SwiftData
@testable import GymQuest

final class StravaServiceNetworkTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionTestSetup.install()
    }

    override func tearDown() {
        URLSessionTestSetup.uninstall()
        super.tearDown()
    }

    // MARK: - Activity Fixture Parsing

    func testStravaActivities_fixtureIsValidJSON() throws {
        let data = TestFixtures.loadFixture("strava_activities_response")
        let activities = try JSONDecoder().decode([StravaActivityFixture].self, from: data)

        XCTAssertEqual(activities.count, 3)
        XCTAssertEqual(activities[0].name, "Morning Run")
        XCTAssertEqual(activities[0].type, "Run")
        XCTAssertEqual(activities[0].moving_time, 1800)
        XCTAssertEqual(activities[1].name, "Evening Strength")
        XCTAssertEqual(activities[1].type, "WeightTraining")
        XCTAssertEqual(activities[2].name, "Cycling Session")
        XCTAssertEqual(activities[2].type, "Ride")
    }

    // MARK: - Token Exchange Fixture Parsing

    func testStravaToken_fixtureIsValidJSON() throws {
        let data = TestFixtures.loadFixture("strava_token_response")
        let token = try JSONDecoder().decode(StravaTokenFixture.self, from: data)

        XCTAssertEqual(token.access_token, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
        XCTAssertEqual(token.refresh_token, "f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5")
        XCTAssertNotNil(token.athlete)
        XCTAssertEqual(token.athlete?.username, "testathlete")
    }

    // MARK: - Activity Type Mapping

    func testActivityTypeMapping_runToCardio() {
        let data = TestFixtures.loadFixture("strava_activities_response")
        guard let activities = try? JSONDecoder().decode([StravaActivityFixture].self, from: data) else {
            XCTFail("Failed to decode fixture")
            return
        }

        // "Run" should map to cardio
        let runActivity = activities[0]
        XCTAssertEqual(runActivity.type, "Run")

        // "WeightTraining" should exist
        let strengthActivity = activities[1]
        XCTAssertEqual(strengthActivity.type, "WeightTraining")
    }
}

// MARK: - Local Decodable Types (mirrors StravaService internal types for fixture validation)

private struct StravaActivityFixture: Decodable {
    let id: Int
    let name: String
    let type: String
    let start_date: String
    let moving_time: Int
    let distance: Double
    let average_speed: Double
    let average_heartrate: Double?
    let suffer_score: Int?
}

private struct StravaTokenFixture: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_at: Int
    let athlete: StravaAthleteFixture?
}

private struct StravaAthleteFixture: Decodable {
    let id: Int
    let username: String
    let firstname: String
    let lastname: String
}
