import Foundation

/// Export windows. Standard periods plus a user-picked range.
enum ExportPeriod: Equatable {
    case last7Days
    case last30Days
    case last12Months
    /// Everything still ahead — committed spend for the next 12 months.
    case upcoming
    case custom(from: Date, to: Date)

    var label: String {
        switch self {
        case .last7Days: "Last 7 days"
        case .last30Days: "Last 30 days"
        case .last12Months: "Last 12 months"
        case .upcoming: "Upcoming"
        case .custom: "Custom range"
        }
    }

    /// Inclusive day range, resolved against `now`. Custom ranges are
    /// normalised so a backwards pick (from > to) still works.
    func dateRange(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let endOfToday = calendar.startOfDay(for: now).addingTimeInterval(86_399)
        switch self {
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
            return start...endOfToday
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))!
            return start...endOfToday
        case .last12Months:
            let start = calendar.date(byAdding: .month, value: -12, to: calendar.startOfDay(for: now))!
            return start...endOfToday
        case .upcoming:
            let end = calendar.date(byAdding: .month, value: 12, to: endOfToday)!
            return calendar.startOfDay(for: now)...end
        case .custom(let from, let to):
            let lo = calendar.startOfDay(for: min(from, to))
            let hi = calendar.startOfDay(for: max(from, to)).addingTimeInterval(86_399)
            return lo...hi
        }
    }
}

/// Pure CSV export of bills — filtered on due date within the window.
enum BillExporter {
    struct Row: Sendable {
        let issuer: String
        let category: String
        let amount: Decimal
        let dueDate: Date
        let paidAt: Date?
        let status: String
        let uploadMethod: String
        let createdAt: Date
    }

    static func rows(in period: ExportPeriod, from rows: [Row],
                     now: Date = .now, calendar: Calendar = .current) -> [Row] {
        let range = period.dateRange(now: now, calendar: calendar)
        return rows
            .filter { range.contains($0.dueDate) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    /// RFC-4180-ish CSV: quoted fields, ISO dates, dot-decimal amounts.
    static func csv(for rows: [Row]) -> String {
        var lines = ["Issuer,Category,Amount,Due date,Status,Paid date,Added,Upload method"]
        let day = Date.ISO8601FormatStyle.iso8601.year().month().day()
        for row in rows {
            let fields = [
                row.issuer,
                row.category,
                "\(row.amount)",
                row.dueDate.formatted(day),
                row.status,
                row.paidAt.map { $0.formatted(day) } ?? "",
                row.createdAt.formatted(day),
                row.uploadMethod
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Quote a field when it contains commas, quotes, or newlines.
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    /// Writes the CSV to a shareable temp file. Filename carries the export day.
    static func writeTempFile(csv: String, now: Date = .now) throws -> URL {
        let stamp = now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ben-bills-\(stamp).csv")
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }
}
