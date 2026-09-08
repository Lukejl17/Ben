import Foundation

struct ParsedBill: Equatable, Sendable {
    var issuer: String?
    var amount: Decimal?
    var dueDate: Date?
    /// 0–1: fraction of the three fields we found, discounted when fallbacks fired.
    var confidence: Double
    /// BPAY and EFT details found on the bill, for the copy-to-pay card.
    var payment = PaymentDetails()

    var isUsable: Bool { issuer != nil || amount != nil || dueDate != nil }
}

protocol BillParsing: Sendable {
    /// Accepts JPEG/PNG/HEIC image data or PDF data (detected by magic bytes).
    func parse(_ data: Data) async throws -> ParsedBill
}

enum BillParsingError: Error {
    case unreadableImage
    case noTextFound
}

// MARK: - Pure text heuristics
// Everything Vision-independent lives here so it can be tested on synthetic strings.

struct BillTextHeuristics: Sendable {
    var calendar: Calendar
    var now: Date

    init(calendar: Calendar = .current, now: Date = .now) {
        self.calendar = calendar
        self.now = now
    }

    /// Issuers we recognise outright — a hit here beats positional guessing.
    static let knownIssuers = [
        "AGL", "Origin Energy", "Origin", "EnergyAustralia", "Red Energy", "Alinta Energy",
        "Telstra", "Optus", "Vodafone", "TPG", "Aussie Broadband", "iiNet",
        "Sydney Water", "Yarra Valley Water", "SA Water", "Urban Utilities",
        "NRMA", "AAMI", "Allianz", "Bupa", "Medibank", "HCF", "NIB",
        "Council Rates", "Foxtel", "Jemena", "Ausgrid"
    ]

    /// Strong pay-this labels — prefer these over weak "total" / line items.
    private static let strongAmountKeywords = [
        "amount due", "total due", "total amount due", "amount payable",
        "total payable", "please pay", "balance due", "amount to pay",
        "invoice total", "total amount", "pay this amount", "total incl"
    ]

    private static let weakAmountKeywords = [
        "new charges", "total"
    ]

    /// Lines that usually hold excl-GST / fee lines — never win over a real total.
    private static let amountDeprioritize = [
        "excluding gst", "excl. gst", "excl gst", "ex gst", "ex-gst",
        "before gst", "without gst", "gst free", "gst-free", "subtotal",
        "sub total", "professional fees", "our fees", "fee for"
    ]

    private static let amountPrefer = [
        "including gst", "incl. gst", "incl gst", "inc gst", "inc. gst",
        "gst inclusive", "total incl", "amount due"
    ]

    private static let dueDateKeywords = [
        "due date", "due by", "payable by", "due on", "direct debit date", "due"
    ]

    func extract(from lines: [String]) -> ParsedBill {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let lowercased = cleaned.map { $0.lowercased() }

        let amount = extractAmount(cleaned: cleaned, lowercased: lowercased)
        let dueDate = extractDueDate(cleaned: cleaned, lowercased: lowercased)
        let issuer = extractIssuer(cleaned: cleaned)

        var percent = 0
        if issuer != nil { percent += 30 }
        if amount != nil { percent += 35 }
        if dueDate != nil { percent += 35 }
        return ParsedBill(
            issuer: issuer, amount: amount, dueDate: dueDate,
            confidence: Double(percent) / 100,
            payment: PaymentDetailsExtractor.extract(from: cleaned)
        )
    }

    // MARK: Amount

    func extractAmount(cleaned: [String], lowercased: [String]) -> Decimal? {
        let strong = amountsNearKeywords(
            cleaned: cleaned, lowercased: lowercased, keywords: Self.strongAmountKeywords
        )
        if let best = preferredAmount(from: strong) { return best }

        let weak = amountsNearKeywords(
            cleaned: cleaned, lowercased: lowercased, keywords: Self.weakAmountKeywords
        )
        if let best = preferredAmount(from: weak) { return best }

        // Fallback: largest $ anywhere, still skipping clear excl-GST lines.
        let anywhere = cleaned.enumerated().flatMap { index, line -> [Decimal] in
            let lower = lowercased[index]
            if Self.amountDeprioritize.contains(where: lower.contains) { return [] }
            return dollarAmounts(in: line)
        }
        return preferGSTInclusive(among: anywhere) ?? anywhere.max()
    }

    private func amountsNearKeywords(
        cleaned: [String], lowercased: [String], keywords: [String]
    ) -> [(amount: Decimal, line: String)] {
        var hits: [(amount: Decimal, line: String)] = []
        for (index, line) in lowercased.enumerated() where keywords.contains(where: line.contains) {
            for neighbour in index...min(cleaned.count - 1, index + 1) {
                let lower = lowercased[neighbour]
                if Self.amountDeprioritize.contains(where: lower.contains) { continue }
                for amount in dollarAmounts(in: cleaned[neighbour]) {
                    hits.append((amount, lower))
                }
            }
        }
        return hits
    }

    private func preferredAmount(from hits: [(amount: Decimal, line: String)]) -> Decimal? {
        guard !hits.isEmpty else { return nil }
        let preferred = hits.filter { hit in
            Self.amountPrefer.contains(where: hit.line.contains)
        }
        let pool = preferred.isEmpty ? hits.map(\.amount) : preferred.map(\.amount)
        return preferGSTInclusive(among: pool) ?? pool.max()
    }

    /// When both excl and incl GST appear (A and A×1.1), prefer the inclusive total.
    func preferGSTInclusive(among amounts: [Decimal]) -> Decimal? {
        let unique = Array(Set(amounts)).sorted()
        guard !unique.isEmpty else { return nil }
        guard unique.count >= 2 else { return unique.first }
        for excl in unique {
            let incl = excl * Decimal(string: "1.1")!
            if let match = unique.first(where: { absDiff($0, incl) <= Decimal(string: "0.02")! }) {
                return match
            }
        }
        return unique.max()
    }

    private func absDiff(_ a: Decimal, _ b: Decimal) -> Decimal {
        a > b ? a - b : b - a
    }

    func dollarAmounts(in line: String) -> [Decimal] {
        let pattern = /\$\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)/
        return line.matches(of: pattern).compactMap {
            Decimal(string: $0.1.replacingOccurrences(of: ",", with: ""))
        }
    }

    // MARK: Due date

    func extractDueDate(cleaned: [String], lowercased: [String]) -> Date? {
        // Prefer dates on/adjacent to a "due" keyword line; else any date found.
        for (index, line) in lowercased.enumerated() where Self.dueDateKeywords.contains(where: line.contains) {
            for neighbour in index...min(cleaned.count - 1, index + 1) {
                if let date = firstDate(in: cleaned[neighbour]) { return date }
            }
        }
        return cleaned.compactMap(firstDate(in:)).first
    }

    private static let monthNames: [String: Int] = {
        var map: [String: Int] = [:]
        let full = ["january", "february", "march", "april", "may", "june",
                    "july", "august", "september", "october", "november", "december"]
        for (i, name) in full.enumerated() {
            map[name] = i + 1
            map[String(name.prefix(3))] = i + 1
        }
        map["sept"] = 9
        return map
    }()

    /// AU formats: "24 Jul 2026", "24 July 2026", "24/07/2026", "24-07-26", "24.07.2026".
    func firstDate(in line: String) -> Date? {
        // Named month: 24 Jul 2026 / 24 July, 2026 / 24Jul26
        let named = /(\d{1,2})\s*(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{2,4})/
        if let match = line.firstMatch(of: named),
           let month = Self.monthNames[String(match.2).lowercased()],
           let date = makeDate(day: Int(match.1), month: month, year: Int(match.3)) {
            return date
        }
        // Numeric day-first: 24/07/2026, 24-07-26, 24.07.2026
        let numeric = /(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/
        if let match = line.firstMatch(of: numeric),
           let date = makeDate(day: Int(match.1), month: Int(match.2), year: Int(match.3)) {
            return date
        }
        return nil
    }

    private func makeDate(day: Int?, month: Int?, year rawYear: Int?) -> Date? {
        guard let day, let month, var year = rawYear,
              (1...31).contains(day), (1...12).contains(month) else { return nil }
        if year < 100 { year += 2000 }
        guard (2000...2100).contains(year) else { return nil }
        var components = DateComponents(year: year, month: month, day: day)
        components.hour = 12  // midday avoids DST edge weirdness
        guard let date = calendar.date(from: components),
              // Reject impossible dates like 31/02 that Calendar would roll over.
              calendar.component(.day, from: date) == day else { return nil }
        return date
    }

    // MARK: Issuer

    func extractIssuer(cleaned: [String]) -> String? {
        // Known issuer anywhere in the document wins; longest match first so
        // "Origin Energy" beats "Origin".
        let known = Self.knownIssuers.sorted { $0.count > $1.count }
        for line in cleaned {
            if let hit = known.first(where: { line.localizedCaseInsensitiveContains($0) }) {
                return hit
            }
        }
        // Fallback: first prominent header-ish line that isn't boilerplate or numbers.
        let boilerplate = ["tax invoice", "invoice", "bill", "statement", "account", "abn", "gst"]
        for line in cleaned.prefix(5) {
            let lower = line.lowercased()
            guard line.count >= 3, line.count <= 40,
                  line.rangeOfCharacter(from: .letters) != nil,
                  line.filter(\.isNumber).count < line.count / 2,
                  !boilerplate.contains(where: lower.contains) else { continue }
            return line
        }
        return nil
    }
}
