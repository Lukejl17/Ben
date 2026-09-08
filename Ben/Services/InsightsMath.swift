import Foundation

/// Time windows for the Insights breakdown. Bills are lumpy (quarterly power,
/// yearly insurance), so the default window is long enough to be honest.
enum InsightsPeriod: String, CaseIterable, Sendable {
    case threeMonths = "3m"
    case sixMonths = "6m"
    case year = "12m"
    case all = "All"

    var label: String {
        switch self {
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .year: "12 months"
        case .all: "All time"
        }
    }

    /// Compact form for the chip row — all four must fit one line on any phone.
    var chipLabel: String {
        switch self {
        case .threeMonths: "3 mo"
        case .sixMonths: "6 mo"
        case .year: "12 mo"
        case .all: "All"
        }
    }

    var months: Int? {
        switch self {
        case .threeMonths: 3
        case .sixMonths: 6
        case .year: 12
        case .all: nil
        }
    }
}

/// One donut slice / list row.
struct CategorySlice: Equatable, Sendable {
    let category: String
    let total: Decimal
    let billCount: Int
    /// 0–1 share of the period total.
    let share: Double
}

/// Minimal projection of a Bill for the breakdown — keeps the maths SwiftData-free.
struct BillEntry: Sendable {
    let category: String
    let amount: Decimal
    /// nil = still owing.
    let paidAt: Date?
}

/// Pure grouping maths — no SwiftData, fully testable.
enum InsightsMath {
    /// Paid money is windowed on when it was paid: [months back, now].
    /// `all` has no lower bound.
    static func isInWindow(
        _ date: Date,
        period: InsightsPeriod,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard date <= now || calendar.isDate(date, inSameDayAs: now) else { return false }
        guard let months = period.months else { return true }
        guard let start = calendar.date(byAdding: .month, value: -months, to: calendar.startOfDay(for: now)) else {
            return true
        }
        return date >= start
    }

    /// Whether a bill counts toward the period. Paid bills window on their
    /// payment date; unpaid bills are money owing *now*, so they always count
    /// while `includeUnpaid` is on — otherwise a new user with only upcoming
    /// bills would stare at an empty chart.
    static func isEligible(
        paidAt: Date?,
        period: InsightsPeriod,
        includeUnpaid: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        if let paidAt {
            return isInWindow(paidAt, period: period, now: now, calendar: calendar)
        }
        return includeUnpaid
    }

    /// Groups bills into ranked slices: money paid in the window plus
    /// (optionally) everything still owing.
    static func breakdown(
        bills: [BillEntry],
        period: InsightsPeriod,
        includeUnpaid: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (slices: [CategorySlice], total: Decimal) {
        let eligible = bills.filter { bill in
            isEligible(
                paidAt: bill.paidAt, period: period, includeUnpaid: includeUnpaid, now: now, calendar: calendar
            )
        }
        let total = eligible.reduce(Decimal.zero) { $0 + $1.amount }
        guard total > 0 else { return ([], .zero) }

        let totalDouble = (total as NSDecimalNumber).doubleValue
        let grouped = Dictionary(grouping: eligible, by: \.category)
        var slices: [CategorySlice] = []
        for (category, items) in grouped {
            var sum = Decimal.zero
            for item in items {
                sum += item.amount
            }
            let share = (sum as NSDecimalNumber).doubleValue / totalDouble
            slices.append(CategorySlice(category: category, total: sum, billCount: items.count, share: share))
        }
        slices.sort { $0.total == $1.total ? $0.category < $1.category : $0.total > $1.total }
        return (slices, total)
    }

    /// Ben's one factual line about the biggest slice. No judgment, no advice.
    /// Period lives on the donut centre — keep this sentence short.
    static func headline(slices: [CategorySlice], period _: InsightsPeriod = .threeMonths) -> String? {
        guard let top = slices.first, slices.count > 1 else { return nil }
        let percent = Int((top.share * 100).rounded())
        return "\(BillCategory.label(for: top.category)) is your biggest, about \(percent)%."
    }
}
