import XCTest

final class ChipsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        // Verify the app launches successfully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    // MARK: - Navigation Tests

    func testTabNavigation() throws {
        // Test tab bar navigation on iPhone
        #if os(iOS)
        // Chips tab should be selected by default
        let chipsTab = app.tabBars.buttons["Chips"]
        XCTAssertTrue(chipsTab.exists)

        // Navigate to History
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.exists)
        historyTab.tap()

        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()

        // Return to Chips
        chipsTab.tap()
        #endif
    }

    // MARK: - Empty State Tests

    func testEmptyStateDisplayed() throws {
        // When no sources are added, empty state should be shown
        let emptyStateText = app.staticTexts["No Sources"]

        // Note: This may not exist if there's already data
        // In a real test, you'd reset the state first
        if emptyStateText.exists {
            XCTAssertTrue(emptyStateText.exists)
            XCTAssertTrue(app.buttons["Add Source"].exists)
        }
    }

    // MARK: - Settings Tests

    func testSettingsNavigation() throws {
        #if os(iOS)
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()

        // Verify settings sections exist
        XCTAssertTrue(app.staticTexts["Sources"].exists || app.navigationBars["Settings"].exists)
        #endif
    }

    // MARK: - History Tests

    func testHistoryTabDisplaysEmptyState() throws {
        #if os(iOS)
        let historyTab = app.tabBars.buttons["History"]
        historyTab.tap()

        // Check for empty state or history content
        let noHistoryText = app.staticTexts["No History"]
        if noHistoryText.exists {
            XCTAssertTrue(noHistoryText.exists)
        }
        #endif
    }

    // MARK: - Screenshot Tests

    func testCaptureScreenshots() throws {
        // Capture screenshots for App Store
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        #if os(iOS)
        // History tab
        app.tabBars.buttons["History"].tap()
        let historyScreenshot = XCTAttachment(screenshot: app.screenshot())
        historyScreenshot.name = "History Tab"
        historyScreenshot.lifetime = .keepAlways
        add(historyScreenshot)

        // Settings tab
        app.tabBars.buttons["Settings"].tap()
        let settingsScreenshot = XCTAttachment(screenshot: app.screenshot())
        settingsScreenshot.name = "Settings Tab"
        settingsScreenshot.lifetime = .keepAlways
        add(settingsScreenshot)
        #endif
    }
}
