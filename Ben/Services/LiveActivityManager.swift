import Foundation
import OSLog
@preconcurrency import ActivityKit

/// Pure rules for when an unpaid bill should sit on the Lock Screen.
enum BillDueLiveActivityPolicy {
    /// Styles that include an on-the-day reminder. Notifications still follow this;
    /// Lock Screen presence does not — unpaid due/overdue bills always qualify.
    static func styleIncludesDueDay(_ style: ReminderStyle) -> Bool {
        switch style {
        case .justBefore, .both: true
        case .fewDaysEarly: false
        }
    }

    /// Unpaid, and the due day is today or already past.
    /// Reminder style only controls notifications — not Lock Screen presence.
    static func shouldPresent(
        dueDate: Date,
        paidAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard paidAt == nil else { return false }
        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        return dueDay <= today
    }

    /// One Live Activity at a time: the most overdue / due unpaid bill.
    static func snapshotsToPresent(
        _ bills: [BillLiveActivitySnapshot],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [BillLiveActivitySnapshot] {
        let eligible = bills
            .filter { shouldPresent(dueDate: $0.dueDate, paidAt: $0.paidAt, now: now, calendar: calendar) }
            .sorted { $0.dueDate < $1.dueDate }
        return Array(eligible.prefix(1))
    }
}

/// Fields copied onto local reminders so a tap can start a Live Activity.
enum LiveActivityNotificationPayload {
    /// Whether this notification should try to put Ben on the Lock Screen.
    static func shouldStart(
        from info: [String: any Sendable],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let kind = info["kind"] as? String
        if kind == "resume_upload" || kind == "second_bill_nudge" || kind == "expected_bill" {
            return false
        }
        guard info["billID"] is String else { return false }

        if boolValue(info["isDueDay"]) == true { return true }

        guard let dueDate = dateValue(info["dueDate"]) else { return false }
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: now)
        return dueDay <= today
    }

    static func billID(from info: [String: any Sendable]) -> String? {
        info["billID"] as? String
    }

    static func issuer(from info: [String: any Sendable]) -> String? {
        info["issuer"] as? String
    }

    static func amount(from info: [String: any Sendable]) -> Decimal {
        if let string = info["amount"] as? String, let decimal = Decimal(string: string) {
            return decimal
        }
        if let number = info["amount"] as? NSNumber {
            return number.decimalValue
        }
        return 0
    }

    static func dueDate(from info: [String: any Sendable], fallback: Date = .now) -> Date {
        dateValue(info["dueDate"]) ?? fallback
    }

    /// Notification `userInfo` round-trips Bool as NSNumber; keep encoding in strings.
    static func boolValue(_ raw: (any Sendable)?) -> Bool? {
        switch raw {
        case let bool as Bool: return bool
        case let number as NSNumber: return number.boolValue
        case let int as Int: return int != 0
        case let string as String:
            switch string.lowercased() {
            case "1", "true", "yes": return true
            case "0", "false", "no": return false
            default: return nil
            }
        default: return nil
        }
    }

    static func dateValue(_ raw: (any Sendable)?) -> Date? {
        switch raw {
        case let string as String:
            if let interval = Double(string) { return Date(timeIntervalSince1970: interval) }
            return nil
        case let interval as Double:
            return Date(timeIntervalSince1970: interval)
        case let number as NSNumber:
            return Date(timeIntervalSince1970: number.doubleValue)
        default:
            return nil
        }
    }
}

/// Snapshot used when syncing Live Activities from the app.
struct BillLiveActivitySnapshot: Sendable {
    var billID: String
    var issuer: String
    var amount: Decimal
    var dueDate: Date
    var paidAt: Date?
}

/// Starts and ends due-day Live Activities. Local-only — no push token.
@MainActor
enum LiveActivityManager {
    /// How long the paid outro stays on Lock Screen before dismissing.
    private static let paidOutroSeconds: Double = 2.8
    private static let logger = Logger(
        subsystem: "com.repertoirestudio.Ben",
        category: "LiveActivity"
    )

    /// Start (or refresh) a Live Activity for a bill that needs paying now.
    @discardableResult
    static func start(
        billID: String,
        issuer: String,
        amount: Decimal,
        dueDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> Bool {
        let auth = ActivityAuthorizationInfo()
        guard auth.areActivitiesEnabled else {
            logger.error("Live Activities are disabled in Settings")
            return false
        }

        let amountText = amount.formatted(.currency(code: "AUD"))
        let state = BillDueAttributes.ContentState(amountText: amountText, isPaid: false)
        let attributes = BillDueAttributes(
            billID: billID,
            issuer: issuer,
            dueDate: dueDate
        )
        let content = ActivityContent(
            state: state,
            staleDate: staleDate(for: dueDate, now: now, calendar: calendar)
        )

        // Already running for this bill — refresh content instead of stacking.
        if let existing = Activity<BillDueAttributes>.activities.first(where: { $0.attributes.billID == billID }) {
            await existing.update(content)
            return true
        }

        if await requestActivity(attributes: attributes, content: content) {
            return true
        }

        // Notification taps can land before the scene is active; retry once.
        logger.error("Activity.request failed; retrying shortly")
        try? await Task.sleep(for: .milliseconds(450))
        return await requestActivity(attributes: attributes, content: content)
    }

    /// Mark paid: update Lock Screen so the track fills to Paid, then dismiss.
    /// Live Activities animate UI changes when content updates — that's the fill.
    static func markPaid(billID: String) async {
        let matching = Activity<BillDueAttributes>.activities.filter { $0.attributes.billID == billID }
        guard !matching.isEmpty else { return }

        for activity in matching {
            var paid = activity.content.state
            paid.isPaid = true
            let content = ActivityContent(state: paid, staleDate: .now.addingTimeInterval(paidOutroSeconds + 1))
            await activity.update(content)
        }

        try? await Task.sleep(for: .seconds(paidOutroSeconds))

        for activity in Activity<BillDueAttributes>.activities where activity.attributes.billID == billID {
            let final = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(final, dismissalPolicy: .default)
        }
    }

    /// End the Live Activity for one bill immediately (remove / wipe).
    static func end(billID: String) async {
        let matching = Activity<BillDueAttributes>.activities.filter { $0.attributes.billID == billID }
        for activity in matching {
            let final = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(final, dismissalPolicy: .immediate)
        }
    }

    /// Bring Live Activities in line with unpaid bills that are due or overdue.
    static func sync(
        bills: [BillLiveActivitySnapshot],
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let shouldShow = BillDueLiveActivityPolicy.snapshotsToPresent(bills, now: now, calendar: calendar)
        let showIDs = Set(shouldShow.map(\.billID))

        for bill in shouldShow {
            _ = await start(
                billID: bill.billID,
                issuer: bill.issuer,
                amount: bill.amount,
                dueDate: bill.dueDate,
                now: now,
                calendar: calendar
            )
        }

        // Don't yank activities mid paid-outro — markPaid owns their dismiss.
        for activity in Activity<BillDueAttributes>.activities
        where !showIDs.contains(activity.attributes.billID) && !activity.content.state.isPaid {
            await end(billID: activity.attributes.billID)
        }
    }

    /// Start from a bill reminder when the OS delivers it or the user taps it.
    static func startFromNotificationUserInfo(
        _ info: [String: any Sendable],
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        guard LiveActivityNotificationPayload.shouldStart(from: info, now: now, calendar: calendar) else {
            return
        }
        guard let billID = LiveActivityNotificationPayload.billID(from: info),
              let issuer = LiveActivityNotificationPayload.issuer(from: info) else {
            return
        }
        let amount = LiveActivityNotificationPayload.amount(from: info)
        let dueDate = LiveActivityNotificationPayload.dueDate(from: info)
        _ = await start(billID: billID, issuer: issuer, amount: amount, dueDate: dueDate, now: now, calendar: calendar)
    }

    private static func requestActivity(
        attributes: BillDueAttributes,
        content: ActivityContent<BillDueAttributes.ContentState>
    ) async -> Bool {
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            return true
        } catch {
            logger.error("Activity.request error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Stale date must be in the future. Overdue bills' original due-day 23:59 is already past.
    private static func staleDate(for dueDate: Date, now: Date, calendar: Calendar) -> Date {
        let endOfDay: (Date) -> Date = { date in
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 23
            components.minute = 59
            return calendar.date(from: components) ?? date.addingTimeInterval(60 * 60 * 8)
        }
        let candidate = max(endOfDay(dueDate), endOfDay(now))
        if candidate > now { return candidate }
        return now.addingTimeInterval(60 * 60 * 8)
    }
}
