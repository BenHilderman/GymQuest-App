import XCTest

final class ClubsTabUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testClubsTab_fullFunctionality() {
        // Step 1: Handle onboarding if present
        // The onboarding is an AI chat flow. "Skip" button is at top-right.
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.tap()
            sleep(2)

            // After skip, a completion card appears with "Get Started"
            let getStarted = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'get started'")).firstMatch
            if getStarted.waitForExistence(timeout: 5) {
                getStarted.tap()
                sleep(2)
            }

            // Training Plan Offer screen — tap "Maybe Later"
            let maybeLater = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'maybe later'")).firstMatch
            if maybeLater.waitForExistence(timeout: 5) {
                maybeLater.tap()
                sleep(2)
            }
        }

        save("00_after_onboarding")

        // Step 2: We should now be on the main Feed tab (Social sub-tab).
        // "Clubs" is a sub-tab within the Feed view, not a main tab.
        let clubsTab = app.staticTexts["Clubs"]
        if !clubsTab.waitForExistence(timeout: 5) {
            // Try tapping "Home" main tab first if we're not on Feed
            let homeTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'home'")).firstMatch
            if homeTab.exists { homeTab.tap(); sleep(1) }
        }

        guard clubsTab.waitForExistence(timeout: 10) else {
            // Dump hierarchy for debugging
            let desc = app.debugDescription
            let path = "/tmp/clubs_debug_hierarchy.txt"
            FileManager.default.createFile(atPath: path, contents: desc.data(using: .utf8))
            save("FAIL_no_clubs_tab")
            XCTFail("Could not find Clubs sub-tab. Hierarchy saved to \(path)")
            return
        }

        // Step 3: Navigate to Clubs sub-tab
        clubsTab.tap()
        sleep(3)
        save("01_clubs_list")

        // Step 4: Verify search bar
        let searchField = app.textFields["Search clubs..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search bar should exist")

        // Step 5: Verify MY CLUBS header
        let myClubsHeader = app.staticTexts["MY CLUBS"]
        XCTAssertTrue(myClubsHeader.waitForExistence(timeout: 5), "MY CLUBS header should exist")

        // Step 6: Test search
        searchField.tap()
        sleep(1)
        searchField.typeText("basketball")
        sleep(2)
        save("02_search_basketball")

        // Step 7: Clear search
        let clearValue = searchField.value as? String ?? ""
        for _ in 0..<clearValue.count {
            searchField.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        sleep(1)

        // Dismiss keyboard by tapping elsewhere
        if myClubsHeader.exists {
            myClubsHeader.tap()
        } else {
            app.tap()
        }
        sleep(1)

        // Step 8: Scroll down to see Nearby section
        app.swipeUp()
        sleep(1)
        save("03_scrolled_nearby")

        // Scroll back up
        app.swipeDown()
        sleep(1)

        // Step 9: Test map toggle
        let mapButton = app.buttons["Map"]
        if !mapButton.exists {
            // Try finding by SF Symbol or image name
            let mapToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'map'")).firstMatch
            if mapToggle.waitForExistence(timeout: 3) {
                mapToggle.tap()
                sleep(2)
                save("04_map_mode")

                // Switch back to list
                let listButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'list'")).firstMatch
                if listButton.exists {
                    listButton.tap()
                    sleep(1)
                }
            }
        } else {
            mapButton.tap()
            sleep(2)
            save("04_map_mode")

            let listButton = app.buttons["List"]
            if listButton.exists {
                listButton.tap()
                sleep(1)
            }
        }

        // Step 10: Try tapping a club card to open detail
        let clubNames = ["Queen's Run Club", "Kingston Pickup Basketball", "Queen's Powerlifting",
                         "Kingston Cycling Group", "Campus Yoga", "Queen's Intramural Soccer"]
        for name in clubNames {
            let clubText = app.staticTexts[name]
            if clubText.waitForExistence(timeout: 2) {
                clubText.tap()
                sleep(2)
                save("05_club_detail")
                // Dismiss detail (swipe down or tap back)
                app.swipeDown()
                sleep(1)
                break
            }
        }

        // Step 11: Test category filter pills
        let categories = ["Cardio", "Strength", "Social", "Wellness"]
        for category in categories {
            let pill = app.buttons[category]
            if pill.exists {
                pill.tap()
                sleep(1)
                save("06_category_\(category)")
                // Tap again to deselect
                pill.tap()
                sleep(1)
                break
            }
            // Also try as staticText
            let pillText = app.staticTexts[category]
            if pillText.exists {
                pillText.tap()
                sleep(1)
                save("06_category_\(category)")
                pillText.tap()
                sleep(1)
                break
            }
        }

        save("07_final_state")
    }

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let data = screenshot.pngRepresentation
        let path = "/tmp/clubs_\(name).png"
        FileManager.default.createFile(atPath: path, contents: data)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
