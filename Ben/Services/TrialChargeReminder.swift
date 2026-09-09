import Foundation

/// Pre-charge trial reminder maths. Pure so it can be unit-tested.
enum TrialChargeReminder {
    static let identifier = "trial-pre-charge"
    static let trialLengthDays = EntitlementMapping.trialLengthDays

    /// Calendar date at `hour` on the day `daysBeforeEnd` before trial end.
    /// Drops (returns nil) when that moment is already in the past.
    static func triggerDate(
        daysBeforeEnd: Int,
        from start: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        hour: Int = ReminderPrefs.hour()
    ) -> Date? {
        let daysUntil = trialLengthDays - daysBeforeEnd
        guard daysUntil > 0, daysBeforeEnd > 0 else { return nil }
        guard let day = calendar.date(byAdding: .day, value: daysUntil, to: start) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        guard let date = calendar.date(from: components), date > now else { return nil }
        return date
    }

    static func body(daysBeforeEnd: Int) -> String {
        if daysBeforeEnd == 1 {
            return "Ben here — the trial ends tomorrow. Cancel in Settings if you don't want to continue."
        }
        return "Ben here — the trial ends in \(daysBeforeEnd) days. Cancel in Settings if you don't want to continue."
    }
}

/// When the trial lapses, reminders stop. Entitled states leave them alone.
enum TrialEntitlementEffects {
    static func apply(state: TrialState, scheduler: ReminderScheduler) {
        if case .lapsed = state {
            scheduler.cancelAllPending()
        }
    }
}
