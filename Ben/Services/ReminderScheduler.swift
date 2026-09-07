import Foundation
import UserNotifications

/// User-tunable delivery preferences. Stored flat; read at scheduling time.
enum ReminderPrefs {
    static let hourKey = "reminderDeliveryHour"
    static let quietWeekendsKey = "reminderQuietWeekends"

    /// 9am default — early enough to act, late enough to be civil.
    static func hour(defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: hourKey)
        return stored == 0 ? 9 : stored
    }

    static func quietWeekends(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: quietWeekendsKey)
    }
}

/// All local-notification work: permission, scheduling maths, actual scheduling.
/// The maths is pure and static so it can be tested hard.
struct ReminderScheduler: Sendable {
    static let reminderHour = 9  // fallback; live scheduling reads ReminderPrefs

    // MARK: Pure scheduling maths

    /// Trigger dates for a reminder style against a due date. Never returns a
    /// date in the past; drops (rather than moves) reminders that have passed.
    static func triggerDates(
        style: ReminderStyle,
        dueDate: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        hour: Int = ReminderPrefs.hour(),
        quietWeekends: Bool = ReminderPrefs.quietWeekends()
    ) -> [Date] {
        triggerSchedule(
            style: style, dueDate: dueDate, now: now, calendar: calendar,
            hour: hour, quietWeekends: quietWeekends
        ).map(\.date)
    }

    /// Day offsets used by scheduling — shared so due-day tagging stays in sync.
    static func triggerOffsets(for style: ReminderStyle) -> [Int] {
        switch style {
        case .fewDaysEarly: [-3]
        case .justBefore: [0]
        case .both: [-3, 0]
        }
    }

    /// Scheduled fire dates paired with their style offset (0 = due day).
    static func triggerSchedule(
        style: ReminderStyle,
        dueDate: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        hour: Int = ReminderPrefs.hour(),
        quietWeekends: Bool = ReminderPrefs.quietWeekends()
    ) -> [(date: Date, offset: Int)] {
        triggerOffsets(for: style).compactMap { offset -> (Date, Int)? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: dueDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = 0
            guard let date = calendar.date(from: components) else { return nil }
            let shifted = Self.shiftedForQuietWeekends(date, enabled: quietWeekends, calendar: calendar)
            guard shifted > now else { return nil }
            return (shifted, offset)
        }
        .sorted { $0.0 < $1.0 }
    }

    /// Quiet weekends: Saturday/Sunday reminders slide to Monday, same hour.
    static func shiftedForQuietWeekends(
        _ date: Date, enabled: Bool, calendar: Calendar = .current
    ) -> Date {
        guard enabled else { return date }
        let weekday = calendar.component(.weekday, from: date)  // 1 = Sunday, 7 = Saturday
        let shift = weekday == 7 ? 2 : (weekday == 1 ? 1 : 0)
        guard shift > 0, let moved = calendar.date(byAdding: .day, value: shift, to: date) else {
            return date
        }
        return moved
    }

    /// "Remind me tomorrow" — next day at the user's delivery hour.
    static func snoozeDate(
        from now: Date, hour: Int, calendar: Calendar = .current
    ) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? tomorrow
    }

    /// Mention dates for a bill that slipped past its due date: one every
    /// `dayStep` days after due, capped at `maxMentions`, never in the past.
    static func overdueTriggerDates(
        cadence: OverdueCadence,
        dueDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        (1...cadence.maxMentions).compactMap { mention in
            guard let day = calendar.date(byAdding: .day, value: mention * cadence.dayStep, to: dueDate) else {
                return nil
            }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = reminderHour
            components.minute = 0
            return calendar.date(from: components)
        }
        .filter { $0 > now }
        .sorted()
    }

    /// Overdue copy: factual, no guilt. "Ben here — AGL was due 24 July and still needs a look."
    static func overdueBody(issuer: String, dueDate: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMMM"
        return "Ben here. \(issuer) was due \(formatter.string(from: dueDate)) and still needs a look."
    }

    /// B1 "remind me tonight": 7pm today, or 9am tomorrow if 7pm has passed.
    static func tonightTrigger(now: Date = .now, calendar: Calendar = .current) -> Date {
        var tonight = calendar.dateComponents([.year, .month, .day], from: now)
        tonight.hour = 19
        tonight.minute = 0
        if let date = calendar.date(from: tonight), date > now { return date }
        var tomorrow = calendar.dateComponents(
            [.year, .month, .day],
            from: calendar.date(byAdding: .day, value: 1, to: now) ?? now
        )
        tomorrow.hour = reminderHour
        tomorrow.minute = 0
        return calendar.date(from: tomorrow) ?? now.addingTimeInterval(3600 * 14)
    }

    /// S10 "later" path: the single promised day-4 nudge.
    static func dayFourNudgeTrigger(now: Date = .now, calendar: Calendar = .current) -> Date {
        let day = calendar.date(byAdding: .day, value: 4, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = reminderHour
        components.minute = 0
        return calendar.date(from: components) ?? day
    }

    /// Notification copy, per voice rules: factual, one clear reason, no urgency.
    /// "Ben here — AGL is due Friday."
    static func reminderBody(issuer: String, dueDate: Date, triggerDate: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let daysAway = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: triggerDate),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0
        switch daysAway {
        case 0: return "Ben here. \(issuer) is due today."
        case 1: return "Ben here. \(issuer) is due tomorrow."
        case 2...6:
            formatter.dateFormat = "EEEE"
            return "Ben here. \(issuer) is due \(formatter.string(from: dueDate))."
        default:
            formatter.dateFormat = "d MMMM"
            return "Ben here. \(issuer) is due \(formatter.string(from: dueDate))."
        }
    }

    // MARK: OS integration

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func permissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Schedules reminders for a bill; returns the notification identifiers.
    /// Due-day payloads carry enough fields to start a Live Activity on delivery/tap.
    @discardableResult
    func scheduleReminders(
        billID: String,
        issuer: String,
        amount: Decimal = 0,
        dueDate: Date,
        style: ReminderStyle,
        withSecondBillRider: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [String] {
        let center = UNUserNotificationCenter.current()
        var identifiers: [String] = []
        let schedule = Self.triggerSchedule(style: style, dueDate: dueDate, now: now, calendar: calendar)
        for (trigger, offset) in schedule {
            let content = UNMutableNotificationContent()
            content.title = "Ben"
            var body = Self.reminderBody(issuer: issuer, dueDate: dueDate, triggerDate: trigger, calendar: calendar)
            if withSecondBillRider {
                body += " Want me watching your other bills too?"
            }
            content.body = body
            content.sound = .default
            content.userInfo = Self.reminderUserInfo(
                billID: billID,
                issuer: issuer,
                amount: amount,
                dueDate: dueDate,
                isDueDay: offset == 0
            )
            content.categoryIdentifier = "bill_reminder"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
            let identifier = "bill-\(billID)-\(components.day ?? 0)-\(components.month ?? 0)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            do {
                try await center.add(request)
                identifiers.append(identifier)
            } catch {
                // Scheduling failure is silent by design — the bill is still tracked.
            }
        }
        return identifiers
    }

    /// Schedules the capped overdue mentions for a bill; returns the identifiers.
    /// Paying the bill cancels these along with everything else on it.
    @discardableResult
    func scheduleOverdueReminders(
        billID: String,
        issuer: String,
        amount: Decimal = 0,
        dueDate: Date,
        cadence: OverdueCadence,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [String] {
        let center = UNUserNotificationCenter.current()
        var identifiers: [String] = []
        let triggers = Self.overdueTriggerDates(cadence: cadence, dueDate: dueDate, now: now, calendar: calendar)
        for (index, trigger) in triggers.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Ben"
            content.body = Self.overdueBody(issuer: issuer, dueDate: dueDate, calendar: calendar)
            content.sound = .default
            content.userInfo = Self.reminderUserInfo(
                billID: billID,
                issuer: issuer,
                amount: amount,
                dueDate: dueDate,
                isDueDay: true
            )
            content.categoryIdentifier = "bill_reminder"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
            let identifier = "bill-\(billID)-overdue-\(index)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            do {
                try await center.add(request)
                identifiers.append(identifier)
            } catch {
                // Scheduling failure is silent by design — the bill is still tracked.
            }
        }
        return identifiers
    }

    /// String-only payload so Bool/Double survive the notification round-trip as NSNumber.
    static func reminderUserInfo(
        billID: String,
        issuer: String,
        amount: Decimal,
        dueDate: Date,
        isDueDay: Bool
    ) -> [AnyHashable: Any] {
        [
            "billID": billID,
            "kind": "bill_reminder",
            "issuer": issuer,
            "amount": NSDecimalNumber(decimal: amount).stringValue ?? "0",
            "dueDate": String(dueDate.timeIntervalSince1970),
            "isDueDay": isDueDay ? "1" : "0"
        ]
    }
}

// MARK: - Nudges, expectations, snooze
extension ReminderScheduler {
    /// B1: one notification tonight deep-linking back to the upload step.
    @discardableResult
    func scheduleTonightNudge(now: Date = .now, calendar: Calendar = .current) async -> String? {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Ben"
        content.body = "Ben here. Got that bill handy now? Takes about a minute."
        content.sound = .default
        content.userInfo = ["kind": "resume_upload"]
        let trigger = Self.tonightTrigger(now: now, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
        let identifier = "resume-upload-tonight"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        do {
            try await center.add(request)
            return identifier
        } catch {
            return nil
        }
    }

    /// S10: the single promised second-bill nudge, ~day 4.
    @discardableResult
    func scheduleDayFourNudge(now: Date = .now, calendar: Calendar = .current) async -> String? {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Ben"
        content.body = "Ben here. Mentioned I'd ask once: any other bills for me?"
        content.sound = .default
        content.userInfo = ["kind": "second_bill_nudge"]
        let trigger = Self.dayFourNudgeTrigger(now: now, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: trigger)
        let identifier = "second-bill-day4"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        do {
            try await center.add(request)
            return identifier
        } catch {
            return nil
        }
    }

    /// Heads-up 3 days before an expected recurring bill lands.
    @discardableResult
    func scheduleExpectedHeadsUp(
        expectation: ExpectedBill,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String? {
        guard let headsUpDay = calendar.date(byAdding: .day, value: -3, to: expectation.expectedDate) else {
            return nil
        }
        var components = calendar.dateComponents([.year, .month, .day], from: headsUpDay)
        components.hour = ReminderPrefs.hour()
        components.minute = 0
        guard let trigger = calendar.date(from: components),
              Self.shiftedForQuietWeekends(
                  trigger, enabled: ReminderPrefs.quietWeekends(), calendar: calendar
              ) > now else { return nil }
        let shifted = Self.shiftedForQuietWeekends(
            trigger, enabled: ReminderPrefs.quietWeekends(), calendar: calendar
        )
        let content = UNMutableNotificationContent()
        content.title = "Ben"
        content.body = "Ben here. \(expectation.issuer) usually lands about now. I'll keep an eye out."
        content.sound = .default
        content.userInfo = ["kind": "expected_bill"]
        let identifier = "expect-\(expectation.sourceBillUUID)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: shifted),
                repeats: false
            )
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return identifier
        } catch {
            return nil
        }
    }

    /// "Remind me tomorrow" from a notification action.
    func scheduleSnooze(
        billID: String, body: String, now: Date = .now, calendar: Calendar = .current
    ) async {
        let trigger = Self.snoozeDate(from: now, hour: ReminderPrefs.hour(), calendar: calendar)
        let content = UNMutableNotificationContent()
        content.title = "Ben"
        content.body = body
        content.sound = .default
        content.userInfo = ["billID": billID, "kind": "bill_reminder"]
        content.categoryIdentifier = "bill_reminder"
        let request = UNNotificationRequest(
            identifier: "snooze-\(billID)-\(Int(trigger.timeIntervalSince1970))",
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: trigger),
                repeats: false
            )
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancel(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
