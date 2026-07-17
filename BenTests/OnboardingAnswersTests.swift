import Foundation
import Testing
@testable import Ben

struct OnboardingAnswersTests {
    @Test func yearlyMathsUsesMonthlyMidpointTimesTwelve() {
        #expect(BillVolume.oneToThree.dueDatesPerYear == 24)
        #expect(BillVolume.fourToSeven.dueDatesPerYear == 66)
        #expect(BillVolume.eightToTwelve.dueDatesPerYear == 120)
    }

    @Test func lostCountAssumesAverageHouseholdAndSaysSo() {
        #expect(BillVolume.lostCount.dueDatesPerYear == 100)
        #expect(BillVolume.lostCount.isEstimate)
        #expect(!BillVolume.eightToTwelve.isEstimate)
        #expect(OnboardingCopy.mathsSub(.lostCount).contains("average"))
        #expect(OnboardingCopy.mathsVoice(.lostCount).contains("lost count"))
    }

    @Test func singleSourceGetsItsOwnEcho() {
        let echo = OnboardingCopy.sourcesEcho([.email])
        #expect(echo == "Forward them straight in. Your inbox stops being a filing cabinet.")
        #expect(OnboardingCopy.sourcesEcho([.dog])?.contains("dog") == true)
    }

    @Test func multipleSourcesGetTheCatchAll() {
        let echo = OnboardingCopy.sourcesEcho([.email, .apps])
        #expect(echo?.contains("funnel into Ben") == true)
        #expect(OnboardingCopy.sourcesEcho([.email, .apps, .dog]) == echo)
        #expect(OnboardingCopy.sourcesEcho([]) == nil)
    }

    @Test func sourceEmotionFollowsTheSameSingleVersusMultiRule() {
        #expect(OnboardingCopy.sourcesEmotion([.email]) == "📥")
        #expect(OnboardingCopy.sourcesEmotion([.email, .paper]) == "⚡")
    }

    @Test func neverLateFeesFlipsToInsuranceFraming() {
        #expect(OnboardingCopy.lateFeesEcho(.never).contains("keeping it that way"))
        #expect(OnboardingCopy.lateFeesEcho(.few).contains("$0"))
        #expect(OnboardingCopy.oddsVoice(.never).contains("dodged"))
        #expect(OnboardingCopy.oddsVoice(.few).contains("stops today"))
    }

    @Test func everyMomentHasMirrorPlanAndEmotion() {
        for moment in IntentContext.allCases {
            #expect(!OnboardingCopy.momentMirror(moment).isEmpty)
            #expect(!OnboardingCopy.momentPlan(moment).isEmpty)
            #expect(!OnboardingCopy.momentEmotion(moment).isEmpty)
        }
    }

    @Test func attributesRoundTripThroughDefaults() {
        let defaults = UserDefaults(suiteName: "onboarding-attrs-test")!
        defaults.removePersistentDomain(forName: "onboarding-attrs-test")
        OnboardingAttributes.save(.init(
            moment: .movedInTogether,
            sources: [.email, .apps],
            volume: .eightToTwelve,
            lateFees: .few,
            feeling: .load,
            reminderStyle: .fewDaysEarly,
            committed: true
        ), defaults: defaults)
        let attrs = OnboardingAttributes.load(defaults: defaults)
        #expect(attrs["moment"] == "moved_in_together")
        #expect(attrs["bill_sources"] == "apps,email")
        #expect(attrs["bills_per_month"] == "8_12")
        #expect(attrs["late_fees"] == "few")
        #expect(attrs["bill_feeling"] == "load")
        #expect(attrs["reminder_style"] == "few_days_early")
        #expect(attrs["commitment_made"] == "true")
    }

    @Test func dogIsItsOwnAttributeValue() {
        let defaults = UserDefaults(suiteName: "onboarding-dog-test")!
        defaults.removePersistentDomain(forName: "onboarding-dog-test")
        OnboardingAttributes.save(.init(sources: [.dog]), defaults: defaults)
        #expect(OnboardingAttributes.load(defaults: defaults)["bill_sources"] == "dog")
    }
}
