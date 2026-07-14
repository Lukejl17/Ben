import XCTest

/// Walks the flow and saves PNGs for BUILD_REPORT.md.
/// Only runs when SCREENSHOT_DIR is set — skipped in normal test runs.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1" else {
            throw XCTSkip("SCREENSHOTS not enabled")
        }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWalkAndScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetOnboarding", "-inMemoryStore", "-mockParser",
            "-nullAnalytics", "-freshTrial", "-autoCapture"
        ]
        if ProcessInfo.processInfo.environment["SCREENSHOT_DARK"] == "1" {
            app.launchArguments.append("-forceDark")
        }
        addUIInterruptionMonitor(withDescription: "Notifications permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists {
                allow.tap()
                return true
            }
            return false
        }
        app.launch()

        let start = app.buttons["Set up my first bill"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snap(app, "s1-welcome")
        start.tap()

        app.buttons["Just bought a home"].tap()
        snap(app, "s2-intent")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["A few days early"].waitForExistence(timeout: 5))
        snap(app, "s3-reminder-style")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["You confirm everything before it's saved."].waitForExistence(timeout: 5))
        snap(app, "s4-trust-upload")
        app.buttons["Photo"].tap()

        let confirmCTA = app.buttons["Looks right — track it"]
        XCTAssertTrue(confirmCTA.waitForExistence(timeout: 10))
        snap(app, "s6-confirm")
        confirmCTA.tap()

        let setUp = app.buttons["Sounds right — set it up"]
        XCTAssertTrue(setUp.waitForExistence(timeout: 10))
        snap(app, "s7-reminder-setup")
        setUp.tap()

        let allowButton = app.buttons["Allow notifications"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 5))
        snap(app, "s7b-pre-permission")
        allowButton.tap()
        app.swipeUp()

        let overdueCTA = app.buttons["That works"]
        XCTAssertTrue(overdueCTA.waitForExistence(timeout: 15))
        snap(app, "s7c-overdue-style")
        overdueCTA.tap()

        let s8Continue = app.buttons["Continue"]
        XCTAssertTrue(s8Continue.waitForExistence(timeout: 15))
        snap(app, "s8-set-state")
        s8Continue.tap()

        XCTAssertTrue(app.staticTexts["Never get surprised by a bill again — and never hear from Ben otherwise."]
            .waitForExistence(timeout: 5))
        snap(app, "s9-paywall-outcome")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["How the trial works"].waitForExistence(timeout: 5))
        snap(app, "s9-paywall-timeline")
        app.buttons["Continue"].tap()
        let startTrial = app.buttons["Start my 7-day trial"]
        XCTAssertTrue(startTrial.waitForExistence(timeout: 5))
        snap(app, "s9-paywall-price")
        startTrial.tap()

        let later = app.buttons["Later's fine"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        snap(app, "s10-second-bill")
        later.tap()

        XCTAssertTrue(app.navigationBars["Bills"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["AGL"].waitForExistence(timeout: 5))
        snap(app, "home")

        // The add-bill dial, expanded
        app.buttons["Add a bill"].tap()
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 5))
        snap(app, "home-add-dial")
    }
}
