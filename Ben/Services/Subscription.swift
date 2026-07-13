import Foundation

enum TrialState: Equatable, Sendable {
    case notStarted
    /// daysRemaining counts whole calendar days until the trial ends (7 on day 0).
    case active(daysRemaining: Int)
    /// Lapsed = view-only: bills stay visible, reminders stop, one factual line, no guilt.
    case lapsed
}

protocol SubscriptionService: AnyObject, Sendable {
    func startTrial(preChargeReminderDaysBeforeEnd: Int, now: Date)
    func state(now: Date) -> TrialState
    var preChargeReminderDaysBeforeEnd: Int? { get }
}

extension SubscriptionService {
    func startTrial(preChargeReminderDaysBeforeEnd: Int) {
        startTrial(preChargeReminderDaysBeforeEnd: preChargeReminderDaysBeforeEnd, now: .now)
    }
    func state() -> TrialState { state(now: .now) }
}

/// 7-day trial state machine persisted in UserDefaults.
/// HUMAN: RevenueCat API key — replace this stub with RevenueCat entitlements,
/// keeping the SubscriptionService protocol as-is.
final class StubSubscriptionService: SubscriptionService, @unchecked Sendable {
    static let trialLengthDays = 7

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let startedAtKey = "trial.startedAt"
    private let reminderDayKey = "trial.preChargeReminderDaysBeforeEnd"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func startTrial(preChargeReminderDaysBeforeEnd: Int, now: Date = .now) {
        guard defaults.object(forKey: startedAtKey) == nil else { return }  // one trial only
        defaults.set(now.timeIntervalSince1970, forKey: startedAtKey)
        defaults.set(preChargeReminderDaysBeforeEnd, forKey: reminderDayKey)
    }

    func state(now: Date = .now) -> TrialState {
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

    var preChargeReminderDaysBeforeEnd: Int? {
        defaults.object(forKey: reminderDayKey) as? Int
    }
}
