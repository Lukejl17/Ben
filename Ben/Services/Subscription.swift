import Foundation

enum TrialState: Equatable, Sendable {
    case notStarted
    /// daysRemaining counts whole calendar days until the trial ends (7 on day 0).
    case active(daysRemaining: Int)
    /// Paid Ben Pro — StoreKit / RevenueCat entitlement is active.
    case subscribed
    /// Trial or subscription ended. Hard paywall; not view-only.
    case lapsed
}

extension TrialState {
    var isEntitled: Bool {
        switch self {
        case .active, .subscribed: true
        case .notStarted, .lapsed: false
        }
    }
}

enum SubscriptionPlan: Equatable, Sendable {
    case annual
    case monthly
}

enum PurchaseOutcome: Equatable, Sendable {
    case entitled
    case cancelled
}

enum SubscriptionPeriodKind: Equatable, Sendable {
    case trial
    case intro
    case normal
}

enum SubscriptionError: Error, LocalizedError, Equatable {
    case notConfigured
    case offeringsUnavailable
    case packageMissing
    case notEntitled
    case paymentPending
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Subscriptions aren't wired on this build yet. That's on us, not you."
        case .offeringsUnavailable:
            "Couldn't load plans just now. Check the connection and try again."
        case .packageMissing:
            "That plan isn't available on this device yet."
        case .notEntitled:
            "Nothing to restore on this Apple ID."
        case .paymentPending:
            "Apple's still confirming that payment. Ben will unlock as soon as it lands."
        case .failed(let message):
            message
        }
    }
}

/// Store-localised plan copy. Fallback matches the App Store products we filed.
struct PlanPricing: Equatable, Sendable {
    var annualPrice: String
    var annualPerMonth: String
    var monthlyPrice: String
    var standingPrice: String?
    var annualHasIntro: Bool

    static let fallback = PlanPricing(
        annualPrice: "US$49.99",
        annualPerMonth: "US$4.17",
        monthlyPrice: "US$5.99",
        standingPrice: "US$69.99",
        annualHasIntro: true
    )
}

extension Notification.Name {
    static let benSubscriptionDidChange = Notification.Name("ben.subscriptionDidChange")
}

/// Maps a StoreKit / RevenueCat entitlement snapshot onto TrialState.
enum EntitlementMapping {
    static let trialLengthDays = 7

    static func state(
        isActive: Bool,
        expirationDate: Date?,
        period: SubscriptionPeriodKind,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TrialState {
        guard isActive else { return .lapsed }
        switch period {
        case .trial, .intro:
            guard let expirationDate else { return .active(daysRemaining: Self.trialLengthDays) }
            let remaining = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: expirationDate)
            ).day ?? 0
            return remaining > 0
                ? .active(daysRemaining: remaining)
                : .subscribed
        case .normal:
            return .subscribed
        }
    }
}

protocol SubscriptionService: AnyObject, Sendable {
    func startTrial(preChargeReminderDaysBeforeEnd: Int, now: Date)
    func state(now: Date) -> TrialState
    var preChargeReminderDaysBeforeEnd: Int? { get }
    var isEntitled: Bool { get }
    var pricing: PlanPricing { get }
    /// RevenueCat needs a CustomerInfo round-trip; the stub already knows locally.
    var usesRemoteEntitlements: Bool { get }

    func refresh() async
    func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome
    func restore() async throws -> PurchaseOutcome
    func identify(userID: String) async
    func logOutPurchaser() async
}

extension SubscriptionService {
    func startTrial(preChargeReminderDaysBeforeEnd: Int) {
        startTrial(preChargeReminderDaysBeforeEnd: preChargeReminderDaysBeforeEnd, now: .now)
    }
    func state() -> TrialState { state(now: .now) }
    var usesRemoteEntitlements: Bool { false }
    var pricing: PlanPricing { .fallback }
}

/// 7-day trial state machine persisted in UserDefaults.
/// Used by tests and UI tests (`-freshTrial`). Live app uses RevenueCat.
final class StubSubscriptionService: SubscriptionService, @unchecked Sendable {
    static let trialLengthDays = EntitlementMapping.trialLengthDays

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let startedAtKey = "trial.startedAt"
    private let reminderDayKey = "trial.preChargeReminderDaysBeforeEnd"
    private let subscribedKey = "trial.subscribed"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func startTrial(preChargeReminderDaysBeforeEnd: Int, now: Date = .now) {
        guard defaults.object(forKey: startedAtKey) == nil else { return }  // one trial only
        defaults.set(now.timeIntervalSince1970, forKey: startedAtKey)
        defaults.set(preChargeReminderDaysBeforeEnd, forKey: reminderDayKey)
        defaults.set(false, forKey: subscribedKey)
    }

    func state(now: Date = .now) -> TrialState {
        if defaults.bool(forKey: subscribedKey) { return .subscribed }
        guard let interval = defaults.object(forKey: startedAtKey) as? Double else { return .notStarted }
        let startedAt = Date(timeIntervalSince1970: interval)
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let remaining = Self.trialLengthDays - elapsed
        return remaining > 0 ? .active(daysRemaining: remaining) : .lapsed
    }

    var isEntitled: Bool { state().isEntitled }
    var pricing: PlanPricing { .fallback }
    var usesRemoteEntitlements: Bool { false }

    var preChargeReminderDaysBeforeEnd: Int? {
        defaults.object(forKey: reminderDayKey) as? Int
    }

    func refresh() async {}

    func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
        if defaults.object(forKey: reminderDayKey) == nil {
            defaults.set(2, forKey: reminderDayKey)
        }
        switch plan {
        case .annual:
            // StoreKit intro trial — a real purchase can start access even after a local lapse.
            defaults.set(Date.now.timeIntervalSince1970, forKey: startedAtKey)
            defaults.set(false, forKey: subscribedKey)
        case .monthly:
            defaults.set(true, forKey: subscribedKey)
        }
        return .entitled
    }

    func restore() async throws -> PurchaseOutcome {
        if isEntitled { return .entitled }
        throw SubscriptionError.notEntitled
    }

    func identify(userID: String) async {}
    func logOutPurchaser() async {}
}
