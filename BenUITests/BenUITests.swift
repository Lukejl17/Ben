import XCTest

final class BenUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-nullAnalytics"]
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }

    /// The whole activation loop: S1 → S10 → home, on the mock AGL bill.
    func testHappyPathS1ToS10() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetOnboarding", "-inMemoryStore", "-mockParser",
            "-nullAnalytics", "-freshTrial", "-autoCapture"
        ]

        // The OS notification prompt appears mid-flow; allow it when it does.
        addUIInterruptionMonitor(withDescription: "Notifications permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists {
                allow.tap()
                return true
            }
            return false
        }

        app.launch()

        // S1 — welcome
        let start = app.buttons["Set up my first bill"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        // S2 — intent
        app.buttons["Just bought a home"].tap()
        app.buttons["Continue"].tap()

        // S3 — reminder style (default pre-selected)
        XCTAssertTrue(app.staticTexts["A few days early"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        // S4 — trust block + method
        XCTAssertTrue(app.staticTexts["You confirm everything before it's saved."].waitForExistence(timeout: 5))
        app.buttons["Choose a photo"].tap()

        // S5 auto-captures via the mock parser → S6 confirm shows the AGL fixture
        let confirmCTA = app.buttons["Looks right — track it"]
        XCTAssertTrue(confirmCTA.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["confirm-issuer"].value as? String == "AGL")
        confirmCTA.tap()

        // S7 — reminder setup
        let setUp = app.buttons["Sounds right — set it up"]
        XCTAssertTrue(setUp.waitForExistence(timeout: 10))
        setUp.tap()

        // Pre-permission sheet
        let allowButton = app.buttons["Allow notifications"]
        XCTAssertTrue(allowButton.waitForExistence(timeout: 5))
        allowButton.tap()
        // Nudge the run loop so the interruption monitor fires on the OS alert.
        app.swipeUp()

        // S7b — overdue cadence
        let overdueCTA = app.buttons["That works"]
        XCTAssertTrue(overdueCTA.waitForExistence(timeout: 15))
        app.buttons["Every second day"].tap()
        overdueCTA.tap()

        // S8 — set state
        let s8Continue = app.buttons["Continue"]
        XCTAssertTrue(s8Continue.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Nothing else needs your attention."].exists)
        s8Continue.tap()

        // S9 — paywall, three pages
        XCTAssertTrue(app.staticTexts["Never get surprised by a bill again — and never hear from Ben otherwise."]
            .waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["How the trial works"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        let startTrial = app.buttons["Start my 7-day trial"]
        XCTAssertTrue(startTrial.waitForExistence(timeout: 5))
        startTrial.tap()

        // S10 — second-bill bridge, decline is first-class
        let later = app.buttons["Later's fine"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        // Home — the tracked bill is there
        XCTAssertTrue(app.staticTexts["Bills"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["AGL"].waitForExistence(timeout: 5))
    }
}
