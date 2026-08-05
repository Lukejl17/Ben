import Foundation
@preconcurrency import ActivityKit

/// Pure rules for when a due-day Live Activity should be on Lock Screen.
enum BillDueLiveActivityPolicy {
    /// Styles that include an on-the-day reminder also get a Live Activity.
    static func styleIncludesDueDay(_ style: ReminderStyle) -> Bool {
        switch style {
        case .justBefore, .both: true
        case .fewDaysEarly: false
        }
    }

    /// Unpaid, style includes due day, and the calendar due date is today.
    static func shouldPresent(
        style: ReminderStyle,
        dueDate: Date,
        paidAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard paidAt == nil else { return false }
        guard styleIncludesDueDay(style) else { return false }
        return calendar.isDate(dueDate, inSameDayAs: now)
    }
}

/// Snapshot used when syncing due-day Live Activities from Home.
struct BillLiveActivitySnapshot: Sendable {
    var billID: String
    var issuer: String
    var amount: Decimal
    var dueDate: Date
    var paidAt: Date?
    var style: ReminderStyle
}

/// Starts and ends due-day Live Activities. Local-only — no push token.
@MainActor
enum LiveActivityManager {
    /// How long the paid outro stays on Lock Screen before dismissing.
    private static let paidOutroSeconds: Double = 2.8

    /// Start (or refresh) a Live Activity for a bill due today.
    @discardableResult
    static func start(
        billID: String,
        issuer: String,
        amount: Decimal,
        dueDate: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }

        let amountText = amount.formatted(.currency(code: "AUD"))
        let state = BillDueAttributes.ContentState(amountText: amountText, isPaid: false)
        let attributes = BillDueAttributes(
            billID: billID,
            issuer: issuer,
            dueDate: dueDate
        )
        let content = ActivityContent(state: state, staleDate: staleDate(for: dueDate, calendar: calendar))

        // Already running for this bill — refresh content instead of stacking.
        if let existing = Activity<BillDueAttributes>.activities.first(where: { $0.attributes.billID == billID }) {
            await existing.update(content)
            return true
        }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            return true
        } catch {
            return false
        }
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

    /// Bring Live Activities in line with unpaid bills that are due today.
    static func sync(
        bills: [BillLiveActivitySnapshot],
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let shouldShow = bills.filter {
            BillDueLiveActivityPolicy.shouldPresent(
                style: $0.style,
                dueDate: $0.dueDate,
                paidAt: $0.paidAt,
                now: now,
                calendar: calendar
            )
        }
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

    /// Start from a due-day notification payload when the OS delivers or the user taps.
    static func startFromNotificationUserInfo(_ info: [String: any Sendable]) async {
        guard let isDueDay = info["isDueDay"] as? Bool, isDueDay else { return }
        guard let billID = info["billID"] as? String,
              let issuer = info["issuer"] as? String else { return }

        let amount: Decimal
        if let string = info["amount"] as? String,
           let decimal = Decimal(string: string) {
            amount = decimal
        } else if let number = info["amount"] as? NSNumber {
            amount = number.decimalValue
        } else {
            amount = 0
        }

        let dueDate: Date
        if let interval = info["dueDate"] as? Double {
            dueDate = Date(timeIntervalSince1970: interval)
        } else if let number = info["dueDate"] as? NSNumber {
            dueDate = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            dueDate = .now
        }

        _ = await start(billID: billID, issuer: issuer, amount: amount, dueDate: dueDate)
    }

    private static func staleDate(for dueDate: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 23
        components.minute = 59
        return calendar.date(from: components) ?? dueDate.addingTimeInterval(60 * 60 * 12)
    }
}
