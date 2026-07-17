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
        usleep(400_000)  // let taps and pop animations settle
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWalkAndScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetOnboarding", "-inMemoryStore", "-mockParser",
            "-nullAnalytics", "-freshTrial", "-freshAccount", "-autoCapture"
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

        walkInterview(app)
        walkFirstBill(app)
        walkCommitAndPaywall(app)
        walkHomeAndTabs(app)
    }

    private func walkInterview(_ app: XCUIApplication) {
        let start = app.buttons["Watch Ben work"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snap(app, "s01-welcome")
        start.tap()

        let demoCTA = app.buttons["That, but for my bills"]
        XCTAssertTrue(demoCTA.waitForExistence(timeout: 5))
        sleep(3)  // let the scan reveal play out before the shot
        snap(app, "s02-demo-scan")
        demoCTA.tap()

        app.buttons["Moved in with someone"].tap()
        snap(app, "s03-moment")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Buried in my email"].waitForExistence(timeout: 5))
        app.buttons["Buried in my email"].tap()
        app.buttons["Scattered across apps"].tap()
        snap(app, "s04-sources")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["8–12"].waitForExistence(timeout: 5))
        app.buttons["8–12"].tap()
        snap(app, "s05-volume")
        app.buttons["Continue"].tap()

        let mathsCTA = app.buttons["Take them off me"]
        XCTAssertTrue(mathsCTA.waitForExistence(timeout: 5))
        sleep(2)  // let the odometer settle
        snap(app, "s06-stat-maths")
        mathsCTA.tap()

        XCTAssertTrue(app.buttons["A few times"].waitForExistence(timeout: 5))
        app.buttons["A few times"].tap()
        snap(app, "s07-late-fees")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["It's always in the back of my mind"].waitForExistence(timeout: 5))
        app.buttons["It's always in the back of my mind"].tap()
        snap(app, "s08-feeling")
        app.buttons["Continue"].tap()

        let mirrorCTA = app.buttons["That's me"]
        XCTAssertTrue(mirrorCTA.waitForExistence(timeout: 5))
        sleep(2)  // chips stagger in
        snap(app, "s09-mirror")
        mirrorCTA.tap()

        let oddsCTA = app.buttons["Not me anymore"]
        XCTAssertTrue(oddsCTA.waitForExistence(timeout: 5))
        sleep(3)  // reel ticks to a stop
        snap(app, "s10-stat-odds")
        oddsCTA.tap()

        XCTAssertTrue(app.buttons["A few days early"].waitForExistence(timeout: 5))
        app.buttons["A few days early"].tap()
        snap(app, "s11-reminder-style")
        app.buttons["Continue"].tap()

        let planCTA = app.buttons["Let's do the first bill"]
        XCTAssertTrue(planCTA.waitForExistence(timeout: 5))
        sleep(2)  // ledger rows rise in
        snap(app, "s12-plan")
        planCTA.tap()
    }

    private func walkFirstBill(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["You confirm everything before it's saved."].waitForExistence(timeout: 5))
        snap(app, "s4-trust-upload")
        app.buttons["Choose a photo"].tap()

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
        snap(app, "s13-set-state")
        s8Continue.tap()
    }

    private func walkCommitAndPaywall(_ app: XCUIApplication) {
        let thumb = app.buttons["Press to commit"]
        XCTAssertTrue(thumb.waitForExistence(timeout: 5))
        snap(app, "s14-commit-pact")
        thumb.tap()
        let sealed = app.buttons["Keep it that way"]
        XCTAssertTrue(sealed.waitForExistence(timeout: 10))
        snap(app, "s14-commit-done")
        sealed.tap()

        XCTAssertTrue(app.staticTexts["Never get surprised by a bill again — and never hear from Ben otherwise."]
            .waitForExistence(timeout: 5))
        snap(app, "s15-paywall-outcome")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["How the trial works"].waitForExistence(timeout: 5))
        snap(app, "s15-paywall-timeline")
        app.buttons["Continue"].tap()
        let startTrial = app.buttons["Start my 7-day trial"]
        XCTAssertTrue(startTrial.waitForExistence(timeout: 5))
        snap(app, "s15-paywall-price")
        startTrial.tap()

        let later = app.buttons["Later's fine"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        snap(app, "s16-second-bill")
        later.tap()
    }

    private func walkHomeAndTabs(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Bills"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["AGL"].waitForExistence(timeout: 5))
        snap(app, "home")

        // The add-bill dial, expanded
        app.buttons["Add a bill"].tap()
        XCTAssertTrue(app.buttons["Choose a photo"].waitForExistence(timeout: 5))
        snap(app, "home-add-dial")
        app.buttons["Add a bill"].tap()  // collapse
        let dialGone = expectation(
            for: NSPredicate(format: "exists == FALSE"),
            evaluatedWith: app.buttons["Choose a photo"]
        )
        wait(for: [dialGone], timeout: 5)

        // Pay the bill → cadence ask → expected ghost row
        app.staticTexts["AGL"].firstMatch.tap()
        let markPaid = app.buttons["Mark as paid"]
        XCTAssertTrue(markPaid.waitForExistence(timeout: 5))
        markPaid.tap()
        XCTAssertTrue(app.buttons["Quarterly"].waitForExistence(timeout: 5))
        snap(app, "cadence-ask")
        app.buttons["Quarterly"].tap()
        app.buttons["Expect it"].tap()
        XCTAssertTrue(app.staticTexts["Expected"].waitForExistence(timeout: 8))
        snap(app, "home-expected")

        // Insights tab
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.buttons["3 months"].waitForExistence(timeout: 5))
        snap(app, "insights")

        // Settings tab
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Not signed in"].waitForExistence(timeout: 5))
        snap(app, "settings")

        // Export sheet
        app.buttons["Export bills"].tap()
        XCTAssertTrue(app.buttons["Upcoming"].waitForExistence(timeout: 5))
        app.buttons["Upcoming"].tap()
        XCTAssertTrue(app.buttons["Share CSV"].waitForExistence(timeout: 5))
        snap(app, "settings-export")
        app.swipeDown(velocity: .fast)

        // Email-in (signed out) → account sheet → signed in
        XCTAssertTrue(app.buttons["Email bills in"].waitForExistence(timeout: 5))
        app.buttons["Email bills in"].tap()
        XCTAssertTrue(app.buttons["Set up my address"].waitForExistence(timeout: 5))
        snap(app, "settings-emailin-signedout")
        app.buttons["Set up my address"].tap()
        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5))
        snap(app, "settings-account-sheet")
        app.buttons["Continue with Apple"].tap()
        XCTAssertTrue(app.buttons["Copy address"].waitForExistence(timeout: 5))
        snap(app, "settings-emailin-signedin")
    }
}
