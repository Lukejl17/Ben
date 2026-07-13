import Foundation
import Testing
@testable import Ben

struct BillHeuristicsTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    var heuristics: BillTextHeuristics {
        BillTextHeuristics(
            calendar: calendar,
            now: calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 10))!
        )
    }

    func day(_ date: Date?) -> DateComponents? {
        guard let date else { return nil }
        return calendar.dateComponents([.year, .month, .day], from: date)
    }

    // MARK: Full AGL-style bill

    @Test func parsesTypicalElectricityBill() {
        let lines = [
            "AGL",
            "Tax Invoice",
            "Your electricity bill",
            "Account number 123 456 789",
            "Billing period 1 Apr 2026 - 30 Jun 2026",
            "Amount due",
            "$243.00",
            "Due date 24 Jul 2026",
            "Pay by direct debit"
        ]
        let parsed = heuristics.extract(from: lines)
        #expect(parsed.issuer == "AGL")
        #expect(parsed.amount == Decimal(243))
        #expect(day(parsed.dueDate) == DateComponents(year: 2026, month: 7, day: 24))
        #expect(parsed.confidence == 1.0)
    }

    // MARK: Amount heuristics

    @Test func picksAmountNearKeywordOverLargerAmountElsewhere() {
        let lines = [
            "Telstra",
            "Charges this year to date $1,890.55",
            "Total due",
            "$89.50",
            "Due 24/08/2026"
        ]
        let parsed = heuristics.extract(from: lines)
        // $1,890.55 is bigger but nowhere near an amount keyword's neighbourhood.
        #expect(parsed.amount == Decimal(string: "89.50"))
    }

    @Test func picksLargestOfSeveralKeywordAmounts() {
        let lines = ["Total amount due $410.20 (includes overdue $120.00)"]
        #expect(heuristics.extract(from: lines).amount == Decimal(string: "410.20"))
    }

    @Test func fallsBackToLargestAmountAnywhere() {
        let lines = ["Origin Energy", "$15.00 discount applied", "$310.45", "Thanks for your business"]
        #expect(heuristics.extract(from: lines).amount == Decimal(string: "310.45"))
    }

    @Test func parsesCommaThousandsAndBareDollars() {
        #expect(heuristics.dollarAmounts(in: "Pay $1,234.56 now") == [Decimal(string: "1234.56")!])
        #expect(heuristics.dollarAmounts(in: "$ 500") == [Decimal(500)])
        #expect(heuristics.dollarAmounts(in: "no money here") == [])
    }

    // MARK: Date formats (AU)

    @Test func parsesNamedMonthFormats() {
        #expect(day(heuristics.firstDate(in: "Due 24 Jul 2026")) == DateComponents(year: 2026, month: 7, day: 24))
        #expect(day(heuristics.firstDate(in: "Due 24 July 2026")) == DateComponents(year: 2026, month: 7, day: 24))
        #expect(day(heuristics.firstDate(in: "Due 3rd September 2026")) == DateComponents(year: 2026, month: 9, day: 3))
        #expect(day(heuristics.firstDate(in: "due 1 Sept 26")) == DateComponents(year: 2026, month: 9, day: 1))
    }

    @Test func parsesNumericDayFirstFormats() {
        #expect(day(heuristics.firstDate(in: "24/07/2026")) == DateComponents(year: 2026, month: 7, day: 24))
        #expect(day(heuristics.firstDate(in: "24-07-26")) == DateComponents(year: 2026, month: 7, day: 24))
        #expect(day(heuristics.firstDate(in: "24.07.2026")) == DateComponents(year: 2026, month: 7, day: 24))
    }

    @Test func rejectsImpossibleDates() {
        #expect(heuristics.firstDate(in: "31/02/2026") == nil)
        #expect(heuristics.firstDate(in: "24/13/2026") == nil)
        #expect(heuristics.firstDate(in: "no date at all") == nil)
    }

    @Test func prefersDateOnDueKeywordLine() {
        let lines = [
            "AGL",
            "Billing period ends 30/06/2026",
            "Due date: 24/07/2026"
        ]
        #expect(day(heuristics.extract(from: lines).dueDate) == DateComponents(year: 2026, month: 7, day: 24))
    }

    @Test func dueDateOnFollowingLineIsFound() {
        let lines = ["Payment due by", "15 August 2026"]
        #expect(day(heuristics.extract(from: lines).dueDate) == DateComponents(year: 2026, month: 8, day: 15))
    }

    // MARK: Issuer heuristics

    @Test func knownIssuerBeatsHeaderGuess() {
        let lines = ["Monthly statement", "Sydney Water", "Total due $130.00"]
        #expect(heuristics.extract(from: lines).issuer == "Sydney Water")
    }

    @Test func longestKnownIssuerWins() {
        let lines = ["Origin Energy Pty Ltd", "Total due $99.00"]
        #expect(heuristics.extract(from: lines).issuer == "Origin Energy")
    }

    @Test func unknownIssuerFallsBackToHeaderLine() {
        let lines = ["Bob's Plumbing Co", "Tax Invoice", "Total due $180.00 due 24/07/2026"]
        #expect(heuristics.extract(from: lines).issuer == "Bob's Plumbing Co")
    }

    @Test func skipsBoilerplateHeaders() {
        let lines = ["Tax Invoice", "ABN 12 345 678 901", "Acme Gas", "Amount due $50.00"]
        #expect(heuristics.extract(from: lines).issuer == "Acme Gas")
    }

    // MARK: Confidence + partials

    @Test func partialParseScoresPartialConfidence() {
        let parsed = heuristics.extract(from: ["Some Retailer", "no amount, no date"])
        #expect(parsed.issuer == "Some Retailer")
        #expect(parsed.amount == nil)
        #expect(parsed.dueDate == nil)
        #expect(parsed.confidence == 0.3)
        #expect(parsed.isUsable)
    }

    @Test func emptyInputIsUnusable() {
        let parsed = heuristics.extract(from: [])
        #expect(!parsed.isUsable)
        #expect(parsed.confidence == 0)
    }
}
