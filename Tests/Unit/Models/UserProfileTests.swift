import XCTest
@testable import GymQuest

final class UserProfileTests: XCTestCase {

    // MARK: - calculateLevel

    func testCalculateLevel_zeroXP() {
        let result = UserProfile.calculateLevel(from: 0)
        XCTAssertEqual(result.level, 1)
    }

    func testCalculateLevel_100XP() {
        // levels = [0, 100, 250, 500, 1000, 2000, 3500, 5500, 8000, 12000, 20000]
        // 100 >= levels[1] (100) → level 2
        let result = UserProfile.calculateLevel(from: 100)
        XCTAssertEqual(result.level, 2)
    }

    func testCalculateLevel_500XP() {
        // 500 >= levels[3] (500) → level 4
        let result = UserProfile.calculateLevel(from: 500)
        XCTAssertEqual(result.level, 4)
    }

    func testCalculateLevel_20000XP() {
        // 20000 >= levels[10] (20000) → level 11
        let result = UserProfile.calculateLevel(from: 20000)
        XCTAssertEqual(result.level, 11)
    }

    func testCalculateLevel_justBelowThreshold() {
        // 99 XP → still level 1 (need 100 for level 2)
        let result = UserProfile.calculateLevel(from: 99)
        XCTAssertEqual(result.level, 1)
    }

    func testCalculateLevel_currentAndNextXP() {
        // At 150 XP: level 2 (threshold 100), currentXP = 150-100 = 50, nextXP = 250-100 = 150
        let result = UserProfile.calculateLevel(from: 150)
        XCTAssertEqual(result.level, 2)
        XCTAssertEqual(result.currentXP, 50)
        XCTAssertEqual(result.nextXP, 150)
    }

    // MARK: - addXP

    @MainActor
    func testAddXP_returnsTrue_onLevelUp() {
        let profile = TestFixtures.makeUserProfile(xp: 90, level: 1)
        // Adding 15 XP → 105 → level 2, was level 1 → leveledUp = true
        let leveledUp = profile.addXP(15)
        XCTAssertTrue(leveledUp)
        XCTAssertEqual(profile.level, 2)
        XCTAssertEqual(profile.xp, 105)
    }

    @MainActor
    func testAddXP_returnsFalse_noLevelUp() {
        let profile = TestFixtures.makeUserProfile(xp: 50, level: 1)
        // Adding 10 XP → 60 → still level 1
        let leveledUp = profile.addXP(10)
        XCTAssertFalse(leveledUp)
        XCTAssertEqual(profile.level, 1)
        XCTAssertEqual(profile.xp, 60)
    }

    // MARK: - levelTitle

    func testLevelTitle_beginner() {
        XCTAssertEqual(UserProfile.levelTitle(for: 1), "Beginner")
    }

    func testLevelTitle_legend() {
        XCTAssertEqual(UserProfile.levelTitle(for: 11), "Legend")
    }

    func testLevelTitle_intermediate() {
        XCTAssertEqual(UserProfile.levelTitle(for: 4), "Intermediate")
    }

    func testLevelTitle_clampsBeyondMax() {
        // Level 15 should return "Legend" (last title)
        XCTAssertEqual(UserProfile.levelTitle(for: 15), "Legend")
    }

    func testLevelTitle_allTitles() {
        let expected = ["Beginner", "Novice", "Apprentice", "Intermediate", "Experienced",
                        "Advanced", "Expert", "Elite", "Master", "Champion", "Legend"]
        for (index, title) in expected.enumerated() {
            XCTAssertEqual(UserProfile.levelTitle(for: index + 1), title)
        }
    }
}
