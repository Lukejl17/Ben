import Foundation
import Testing
@testable import Ben

struct OnboardingAttributesTests {
    @Test func roundTripPreservesInterviewAnswers() {
        let suite = UserDefaults(suiteName: "onboarding-attr-\(UUID().uuidString)")!
        let snapshot = OnboardingAttributes.Snapshot(
            moment: .billsPilingUp,
            sources: [.email, .paper],
            volume: .fourToSeven,
            lateFees: .few,
            feeling: .load,
            reminderStyle: .fewDaysEarly,
            committed: true
        )
        OnboardingAttributes.save(snapshot, defaults: suite)
        let loaded = OnboardingAttributes.loadSnapshot(defaults: suite)
        #expect(loaded.moment == .billsPilingUp)
        #expect(loaded.sources == [.email, .paper])
        #expect(loaded.volume == .fourToSeven)
        #expect(loaded.lateFees == .few)
        #expect(loaded.feeling == .load)
        #expect(loaded.reminderStyle == .fewDaysEarly)
        #expect(loaded.committed)
    }

    @MainActor
    @Test func coordinatorRestoreFillsPaywallRecapFields() {
        let suite = UserDefaults(suiteName: "onboarding-restore-\(UUID().uuidString)")!
        OnboardingAttributes.save(
            .init(
                moment: .gettingOrganised,
                sources: [.apps],
                volume: .oneToThree,
                lateFees: .once,
                feeling: .dread,
                reminderStyle: .justBefore,
                committed: true
            ),
            defaults: suite
        )
        let loaded = OnboardingAttributes.loadSnapshot(defaults: suite)
        let coordinator = OnboardingCoordinator()
        coordinator.intent = loaded.moment
        coordinator.sources = loaded.sources
        coordinator.volume = loaded.volume
        coordinator.lateFees = loaded.lateFees
        coordinator.feeling = loaded.feeling
        #expect(coordinator.intent == .gettingOrganised)
        #expect(coordinator.volume == .oneToThree)
        #expect(coordinator.feeling == .dread)
        #expect(coordinator.lateFees == .once)
        #expect(!coordinator.sources.isEmpty)
    }

    @Test func stubPlansAreReadyWithoutStore() {
        let suite = UserDefaults(suiteName: "plans-ready-\(UUID().uuidString)")!
        let service = StubSubscriptionService(defaults: suite)
        #expect(service.plansReady)
    }
}
