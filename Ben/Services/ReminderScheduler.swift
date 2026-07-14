import Foundation
import UserNotifications

/// All local-notification work: permission, scheduling maths, actual scheduling.
/// The maths is pure and static so it can be tested hard.
struct ReminderScheduler: Sendable {
    static let reminderHour = 9  // 9am local — early enough to act, late enough to be civil

    // MARK: Pure scheduling maths

    /// Trigger dates for a reminder style against a due date. Never returns a
    /// date in the past; drops (rather than moves) reminders that have passed.
    static func triggerDates(
        style: ReminderStyle,
        dueDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        var offsets: [Int] {
            switch style {
            case .fewDaysEarly: [-3]
            case .justBefore: [0]
            case .both: [-3, 0]
            }
        }
        return offsets.compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: dueDate) else { return nil }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = reminderHour
            components.minute = 0
            return calendar.date(from: components)
        }
        .filter { $0 > now }
        .sorted()
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
        return "Ben here — \(issuer) was due \(formatter.string(from: dueDate)) and still needs a look."
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
        case 0: return "Ben here — \(issuer) is due today."
        case 1: return "Ben here — \(issuer) is due tomorrow."
        case 2...6:
            formatter.dateFormat = "EEEE"
            return "Ben here — \(issuer) is due \(formatter.string(from: dueDate))."
        default:
            formatter.dateFormat = "d MMMM"
            return "Ben here — \(issuer) is due \(formatter.string(from: dueDate))."
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
    @discardableResult
    func scheduleReminders(
        billID: String,
        issuer: String,
        dueDate: Date,
        style: ReminderStyle,
        withSecondBillRider: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> [String] {
        let center = UNUserNotificationCenter.current()
        var identifiers: [String] = []
        for trigger in Self.triggerDates(style: style, dueDate: dueDate, now: now, calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = "Ben"
            var body = Self.reminderBody(issuer: issuer, dueDate: dueDate, triggerDate: trigger, calendar: calendar)
            if withSecondBillRider {
                body += " Want me watching your other bills too?"
            }
            content.body = body
            content.sound = .default
            content.userInfo = ["billID": billID, "kind": "bill_reminder"]
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
            content.userInfo = ["billID": billID, "kind": "bill_reminder"]
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

    /// B1: one notification tonight deep-linking back to the upload step.
    @discardableResult
    func scheduleTonightNudge(now: Date = .now, calendar: Calendar = .current) async -> String? {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Ben"
        content.body = "Ben here — got that bill handy now? Takes about a minute."
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
        content.body = "Ben here — mentioned I'd ask once: any other bills for me?"
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

    func cancel(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
