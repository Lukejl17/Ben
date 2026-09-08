import Foundation
import Testing
@testable import Ben

struct WelcomeGreetingTests {
    @Test func unknownRegionFallsBackToGday() {
        #expect(WelcomeGreeting.word(forRegionCode: nil) == "G'day")
        #expect(WelcomeGreeting.word(forRegionCode: "") == "G'day")
        #expect(WelcomeGreeting.word(forRegionCode: "ZZ") == "G'day")
    }

    @Test func knownRegionsMapToLockedHellos() {
        #expect(WelcomeGreeting.word(forRegionCode: "AU") == "G'day")
        #expect(WelcomeGreeting.word(forRegionCode: "us") == "Howdy")
        #expect(WelcomeGreeting.word(forRegionCode: "NZ") == "Kia ora")
        #expect(WelcomeGreeting.word(forRegionCode: "CA") == "Oh hey bud")
        #expect(WelcomeGreeting.word(forRegionCode: "FR") == "Bonjour")
        #expect(WelcomeGreeting.word(forRegionCode: "BR") == "Olá")
    }

    @Test func displayAttachesComma() {
        #expect(WelcomeGreeting.display("Howdy") == "Howdy,")
        #expect(WelcomeGreeting.display("Oh hey bud") == "Oh hey bud,")
    }

    @Test func stripStartsOnBrandAndLandsOnTarget() {
        var rng = SeededGenerator(seed: 42)
        let strip = WelcomeGreeting.reelStrip(landingOn: "Howdy", using: &rng)
        #expect(strip.first == "G'day,")
        #expect(strip.last == "Howdy,")
        #expect(strip.count > 5)
        #expect(strip.allSatisfy { $0.hasSuffix(",") })
    }

    @Test func australianStripReturnsHomeToGday() {
        var rng = SeededGenerator(seed: 7)
        let strip = WelcomeGreeting.reelStrip(landingOn: "G'day", using: &rng)
        #expect(strip.first == "G'day,")
        #expect(strip.last == "G'day,")
        #expect(strip.count > 2)
    }
}

/// Deterministic RNG so strip tests stay stable.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xbf58476d1ce4e5b9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94d049bb133111eb
        return mixed ^ (mixed >> 31)
    }
}
