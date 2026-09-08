import Foundation

/// One editable row in the instalment split sheet.
struct InstallmentDraft: Identifiable, Equatable, Sendable {
    var id = UUID()
    var amount: Decimal
    var dueDate: Date
}

/// Pure maths for splitting a total into instalments that still add up.
enum InstallmentSplitter {
    /// Split `total` into `count` parts. Leftover cents go on the first
    /// instalment (how council rates usually work).
    static func equalAmounts(total: Decimal, count: Int) -> [Decimal] {
        let parts = max(count, 1)
        guard parts > 1 else { return [total] }

        let cents = NSDecimalNumber(decimal: total * 100).intValue
        let base = cents / parts
        let remainder = cents - (base * parts)
        return (0..<parts).map { index in
            let part = base + (index == 0 ? remainder : 0)
            return Decimal(part) / 100
        }
    }

    /// First due date, then the same day each `monthsApart` months.
    static func spacedDates(
        starting first: Date,
        count: Int,
        monthsApart: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        let parts = max(count, 1)
        let gap = max(monthsApart, 1)
        return (0..<parts).compactMap { index in
            calendar.date(byAdding: .month, value: index * gap, to: first)
        }
    }

    static func drafts(
        total: Decimal,
        firstDue: Date,
        count: Int,
        monthsApart: Int,
        calendar: Calendar = .current
    ) -> [InstallmentDraft] {
        let amounts = equalAmounts(total: total, count: count)
        let dates = spacedDates(
            starting: firstDue, count: count, monthsApart: monthsApart, calendar: calendar
        )
        return zip(amounts, dates).map { InstallmentDraft(amount: $0, dueDate: $1) }
    }

    static func sum(_ drafts: [InstallmentDraft]) -> Decimal {
        drafts.reduce(0) { $0 + $1.amount }
    }
}
