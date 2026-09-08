import Foundation

/// Bill cadence — how often an issuer comes around.
enum BillRecurrence: String, CaseIterable, Sendable {
    case none, monthly, quarterly, yearly

    var label: String {
        switch self {
        case .none: "Just this once"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }

    var detail: String? {
        switch self {
        case .none: "No expectations. I'll wait for the next photo."
        case .monthly: "Like phone or internet."
        case .quarterly: "Like power or water."
        case .yearly: "Like insurance or rego."
        }
    }

    var months: Int? {
        switch self {
        case .none: nil
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
}

/// A bill Ben expects but hasn't seen yet — derived, never stored, so it can't drift.
struct ExpectedBill: Equatable, Sendable, Identifiable {
    let sourceBillUUID: String
    let issuer: String
    let category: String
    let estimatedAmount: Decimal
    let expectedDate: Date

    var id: String { sourceBillUUID }
}

/// Pure derivation of expectations from bill history.
enum ExpectedBills {
    /// Minimal projection so the maths stays SwiftData-free.
    struct Entry: Sendable {
        let uuid: String
        let issuer: String
        let category: String
        let amount: Decimal
        let dueDate: Date
        let isPaid: Bool
        let recurrence: BillRecurrence
    }

    /// The next occurrence strictly after `now`, stepped from the source due date.
    static func nextDate(
        after dueDate: Date, recurrence: BillRecurrence, now: Date, calendar: Calendar = .current
    ) -> Date? {
        guard let step = recurrence.months else { return nil }
        var candidate = dueDate
        for _ in 0..<60 {  // five years of monthly steps, plenty
            guard let advanced = calendar.date(byAdding: .month, value: step, to: candidate) else { return nil }
            candidate = advanced
            if candidate > now { return candidate }
        }
        return nil
    }

    /// Expectations, soonest first. One per issuer (from its most recent
    /// recurring bill). Suppressed while an unpaid bill for the same issuer
    /// is already on the books near the expected date — the real thing arrived.
    static func expectations(
        from entries: [Entry], now: Date = .now, calendar: Calendar = .current
    ) -> [ExpectedBill] {
        let recurring = entries.filter { $0.recurrence != .none }
        // Most recent bill per issuer drives the expectation.
        var latestByIssuer: [String: Entry] = [:]
        for entry in recurring {
            let key = entry.issuer.lowercased()
            if let existing = latestByIssuer[key], existing.dueDate >= entry.dueDate { continue }
            latestByIssuer[key] = entry
        }

        return latestByIssuer.values.compactMap { source -> ExpectedBill? in
            guard let expected = nextDate(
                after: source.dueDate, recurrence: source.recurrence, now: now, calendar: calendar
            ) else { return nil }
            // Fulfilled? An unpaid bill from this issuer within ±21 days of the expectation.
            let fulfilled = entries.contains { candidate in
                candidate.uuid != source.uuid
                    && !candidate.isPaid
                    && candidate.issuer.lowercased() == source.issuer.lowercased()
                    && abs(candidate.dueDate.timeIntervalSince(expected)) < 21 * 86_400
            }
            guard !fulfilled else { return nil }
            return ExpectedBill(
                sourceBillUUID: source.uuid,
                issuer: source.issuer,
                category: source.category,
                estimatedAmount: source.amount,
                expectedDate: expected
            )
        }
        .sorted { $0.expectedDate < $1.expectedDate }
    }
}
