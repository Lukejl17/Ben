import Foundation
import Observation

/// UI-facing subscription state. Views observe this; the backend is
/// RevenueCat in production and the UserDefaults stub in tests.
@Observable @MainActor
final class SubscriptionController {
    private let service: any SubscriptionService
    private(set) var state: TrialState
    private(set) var pricing: PlanPricing
    private(set) var isBusy = false
    /// False until the first CustomerInfo fetch when using RevenueCat.
    private(set) var hasResolved: Bool

    var isEntitled: Bool { state.isEntitled }

    init(service: any SubscriptionService) {
        self.service = service
        self.state = service.state()
        self.pricing = service.pricing
        self.hasResolved = !service.usesRemoteEntitlements
        observeRemoteUpdates()
    }

    func refresh() async {
        await service.refresh()
        applyServiceSnapshot()
        hasResolved = true
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
        isBusy = true
        defer { isBusy = false }
        let outcome = try await service.purchase(plan)
        applyServiceSnapshot()
        return outcome
    }

    func restore() async throws -> PurchaseOutcome {
        isBusy = true
        defer { isBusy = false }
        let outcome = try await service.restore()
        applyServiceSnapshot()
        return outcome
    }

    func identify(userID: String) async {
        await service.identify(userID: userID)
        await refresh()
    }

    func logOutPurchaser() async {
        await service.logOutPurchaser()
        await refresh()
    }

    func rememberPreChargeReminder(daysBeforeEnd: Int) {
        service.startTrial(preChargeReminderDaysBeforeEnd: daysBeforeEnd)
    }

    private func applyServiceSnapshot() {
        state = service.state()
        pricing = service.pricing
    }

    private func observeRemoteUpdates() {
        guard service.usesRemoteEntitlements else { return }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .benSubscriptionDidChange) {
                self?.applyServiceSnapshot()
            }
        }
    }
}
