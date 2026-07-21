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
            "-nullAnalytics", "-freshTrial", "-autoCapture", "-stubAccount"
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

        // S1 — welcome (sign-in CTA lives under the main button)
        let start = app.buttons["Watch Ben work"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["I already have an account"].exists)
        start.tap()

        // S2 — demo scan
        let demoCTA = app.buttons["That, but for my bills"]
        XCTAssertTrue(demoCTA.waitForExistence(timeout: 5))
        demoCTA.tap()

        // Interview: intent → sources → volume → maths → late fees →
        // feeling → mirror → odds → reminder style → plan
        app.buttons["Just bought a home"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Buried in my email"].waitForExistence(timeout: 5))
        app.buttons["Buried in my email"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["8–12"].waitForExistence(timeout: 5))
        app.buttons["8–12"].tap()
        app.buttons["Continue"].tap()

        let mathsCTA = app.buttons["Take them off me"]
        XCTAssertTrue(mathsCTA.waitForExistence(timeout: 5))
        mathsCTA.tap()

        XCTAssertTrue(app.buttons["A few times"].waitForExistence(timeout: 5))
        app.buttons["A few times"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["It's always in the back of my mind"].waitForExistence(timeout: 5))
        app.buttons["It's always in the back of my mind"].tap()
        app.buttons["Continue"].tap()

        let mirrorCTA = app.buttons["That's me"]
        XCTAssertTrue(mirrorCTA.waitForExistence(timeout: 5))
        mirrorCTA.tap()

        let oddsCTA = app.buttons["Not me anymore"]
        XCTAssertTrue(oddsCTA.waitForExistence(timeout: 5))
        oddsCTA.tap()

        XCTAssertTrue(app.buttons["A few days early"].waitForExistence(timeout: 5))
        app.buttons["A few days early"].tap()
        app.buttons["Continue"].tap()

        let planCTA = app.buttons["Let's do the first bill"]
        XCTAssertTrue(planCTA.waitForExistence(timeout: 5))
        planCTA.tap()

        // S4 — trust block + method
        XCTAssertTrue(app.staticTexts["You confirm everything before it's saved."].waitForExistence(timeout: 5))
        app.buttons["Choose a photo"].tap()

        // S5 auto-captures via the mock parser → S6 confirm shows the AGL fixture
        let confirmCTA = app.buttons["Looks right, track it"]
        XCTAssertTrue(confirmCTA.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["confirm-issuer"].value as? String == "AGL")
        confirmCTA.tap()

        // S7 — reminder setup
        let setUp = app.buttons["Sounds right, set it up"]
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

        // S8 — account required before paywall (no skip)
        XCTAssertTrue(app.staticTexts["Save this setup"].waitForExistence(timeout: 15))
        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.exists)
        apple.tap()

        // Commit pact
        let thumb = app.buttons["Press to commit"]
        XCTAssertTrue(thumb.waitForExistence(timeout: 10))
        thumb.tap()
        let sealed = app.buttons["Keep it that way"]
        XCTAssertTrue(sealed.waitForExistence(timeout: 10))
        sealed.tap()

        // Paywall journey → trial → second-bill → home
        XCTAssertTrue(app.staticTexts["Never get surprised by a bill again. And never hear from Ben otherwise."]
            .waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        let giftCTA = app.buttons["Sounds fair"]
        XCTAssertTrue(giftCTA.waitForExistence(timeout: 5))
        giftCTA.tap()

        XCTAssertTrue(app.staticTexts["How your 7 free\ndays work"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        let compareCTA = app.buttons["Fair enough"]
        XCTAssertTrue(compareCTA.waitForExistence(timeout: 5))
        compareCTA.tap()

        let startTrial = app.buttons["Start for $0.00"]
        XCTAssertTrue(startTrial.waitForExistence(timeout: 5))
        startTrial.tap()

        let later = app.buttons["Later's fine"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        XCTAssertTrue(app.staticTexts["Bills"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["AGL"].waitForExistence(timeout: 5))
    }
}
