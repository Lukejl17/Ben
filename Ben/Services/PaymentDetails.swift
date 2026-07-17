import Foundation

/// How a bill wants to be paid, pulled from the scan. Values are stored as
/// bare digits so they paste cleanly into banking apps; display formatting
/// is computed. Ben never moves money — he just saves you the squinting.
struct PaymentDetails: Equatable, Sendable {
    var bpayBillerCode: String?
    var bpayReference: String?
    var bsb: String?
    var accountNumber: String?
    var eftReference: String?

    var isEmpty: Bool {
        bpayBillerCode == nil && bpayReference == nil
            && bsb == nil && accountNumber == nil && eftReference == nil
    }

    /// "062000" shown as "062-000".
    static func displayBSB(_ digits: String) -> String {
        guard digits.count == 6 else { return digits }
        return "\(digits.prefix(3))-\(digits.suffix(3))"
    }

    /// Long references grouped in fours: "204344556677" shown as "2043 4455 6677".
    static func displayReference(_ digits: String) -> String {
        guard digits.count > 6 else { return digits }
        var grouped: [String] = []
        var rest = Substring(digits)
        while !rest.isEmpty {
            grouped.append(String(rest.prefix(4)))
            rest = rest.dropFirst(4)
        }
        return grouped.joined(separator: " ")
    }
}

/// Pure text heuristics for Australian payment blocks: BPAY biller code and
/// customer reference, and EFT BSB, account and reference. Keyword-gated so
/// random digit runs never masquerade as bank details.
struct PaymentDetailsExtractor: Sendable {
    static func extract(from lines: [String]) -> PaymentDetails {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let lowercased = cleaned.map { $0.lowercased() }
        var details = PaymentDetails()

        if let billerIndex = lowercased.firstIndex(where: { $0.contains("biller code") }) {
            details.bpayBillerCode = digits(nearKeyword: "biller code", at: billerIndex,
                                            cleaned: cleaned, lowercased: lowercased, bounds: 3...6)
            // The BPAY ref sits on or just after the biller code line.
            details.bpayReference = reference(after: billerIndex, cleaned: cleaned, lowercased: lowercased)
        }
        if details.bpayReference == nil,
           let crnIndex = lowercased.firstIndex(where: {
               $0.contains("customer reference number") || $0.contains("crn")
           }) {
            details.bpayReference = longDigits(onOrAfter: crnIndex, cleaned: cleaned)
        }

        if let bsbIndex = lowercased.firstIndex(where: { $0.contains("bsb") }) {
            details.bsb = bsb(at: bsbIndex, cleaned: cleaned)
            // Bank account and EFT reference only count near an actual BSB —
            // "account number" on its own is usually the customer account.
            let window = max(0, bsbIndex - 2)...min(cleaned.count - 1, bsbIndex + 3)
            for index in window where lowercased[index].contains("account") {
                if let account = digits(nearKeyword: "account", at: index,
                                        cleaned: cleaned, lowercased: lowercased, bounds: 5...12) {
                    details.accountNumber = account
                    break
                }
            }
            for index in bsbIndex...min(cleaned.count - 1, bsbIndex + 3)
            where lowercased[index].contains("ref") {
                details.eftReference = longDigits(onOrAfter: index, cleaned: cleaned)
                break
            }
        }
        return details
    }

    // MARK: Pieces

    /// Digits on the keyword line (after the keyword) or the next line.
    private static func digits(
        nearKeyword keyword: String, at index: Int,
        cleaned: [String], lowercased: [String],
        bounds: ClosedRange<Int>
    ) -> String? {
        // Same line, after the keyword so we don't grab e.g. a line number.
        if let range = lowercased[index].range(of: keyword) {
            let tail = String(cleaned[index][range.upperBound...])
            if let run = digitRun(in: tail, bounds: bounds) { return run }
        }
        guard index + 1 < cleaned.count else { return nil }
        return digitRun(in: cleaned[index + 1], bounds: bounds)
    }

    /// A "Ref"-labelled digit run on the biller line or the two after it.
    private static func reference(
        after index: Int, cleaned: [String], lowercased: [String]
    ) -> String? {
        for probe in index...min(cleaned.count - 1, index + 2) where lowercased[probe].contains("ref") {
            if let range = lowercased[probe].range(of: "ref") {
                let tail = String(cleaned[probe][range.upperBound...])
                if let run = digitRun(in: tail, bounds: 6...20) { return run }
            }
            if probe + 1 < cleaned.count,
               let run = digitRun(in: cleaned[probe + 1], bounds: 6...20) {
                return run
            }
        }
        return nil
    }

    private static func bsb(at index: Int, cleaned: [String]) -> String? {
        let pattern = /(\d{3})[\s-]?(\d{3})\b/
        for probe in index...min(cleaned.count - 1, index + 1) {
            if let match = cleaned[probe].firstMatch(of: pattern) {
                return "\(match.1)\(match.2)"
            }
        }
        return nil
    }

    private static func longDigits(onOrAfter index: Int, cleaned: [String]) -> String? {
        for probe in index...min(cleaned.count - 1, index + 1) {
            if let run = digitRun(in: cleaned[probe], bounds: 6...20) { return run }
        }
        return nil
    }

    /// The longest run of digits (spaces allowed between groups) within bounds.
    private static func digitRun(in text: String, bounds: ClosedRange<Int>) -> String? {
        let pattern = /(\d[\d ]*\d|\d+)/
        let candidates = text.matches(of: pattern)
            .map { String($0.1).replacingOccurrences(of: " ", with: "") }
            .filter { bounds.contains($0.count) }
        return candidates.max { $0.count < $1.count }
    }
}
