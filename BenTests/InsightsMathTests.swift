import Foundation
import Testing
@testable import Ben

struct InsightsMathTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    var now: Date { date(2026, 7, 14) }

    typealias Entry = BillEntry

    func run(
        _ bills: [Entry], period: InsightsPeriod = .threeMonths, includeUnpaid: Bool = true
    ) -> (slices: [CategorySlice], total: Decimal) {
        InsightsMath.breakdown(
            bills: bills, period: period, includeUnpaid: includeUnpaid, now: now, calendar: calendar
        )
    }

    // MARK: Window semantics — paid money windows on payment date

    @Test func paidWindowIncludesEdgeAndExcludesOlder() {
        let inside = BillEntry(category: "electricity", amount: 100, paidAt: date(2026, 4, 15))
        let edge = BillEntry(category: "water", amount: 50, paidAt: date(2026, 4, 14))      // exactly 3 months back
        let outside = BillEntry(category: "gas", amount: 75, paidAt: date(2026, 4, 13))
        let result = run([inside, edge, outside])
        #expect(result.total == 150)
        #expect(result.slices.map(\.category) == ["electricity", "water"])
    }

    @Test func owingBillsAlwaysCountWhileToggleOn() {
        // Money still owed is current regardless of due date — a fresh user
        // with only upcoming bills must not see an empty chart.
        let owing = BillEntry(category: "electricity", amount: 243, paidAt: nil)
        let result = run([owing])
        #expect(result.total == 243)
        #expect(result.slices.first?.category == "electricity")
    }

    @Test func allTimeHasNoLowerBound() {
        let ancient = BillEntry(category: "rent", amount: 2000, paidAt: date(2020, 1, 1))
        let result = run([ancient], period: .all)
        #expect(result.total == 2000)
    }

    // MARK: Paid toggle

    @Test func paidOnlyExcludesOwingBills() {
        let paid = BillEntry(category: "electricity", amount: 100, paidAt: date(2026, 7, 1))
        let owing = BillEntry(category: "electricity", amount: 80, paidAt: nil)
        let result = run([paid, owing], includeUnpaid: false)
        #expect(result.total == 100)
        #expect(result.slices.first?.billCount == 1)
    }

    // MARK: Grouping + shares

    @Test func groupsSumAndRankDescending() {
        let bills: [Entry] = [
            BillEntry(category: "electricity", amount: 200, paidAt: date(2026, 7, 1)),
            BillEntry(category: "electricity", amount: 100, paidAt: date(2026, 6, 1)),
            BillEntry(category: "internet", amount: 90, paidAt: date(2026, 6, 15)),
            BillEntry(category: "water", amount: 110, paidAt: date(2026, 5, 20))
        ]
        let result = run(bills)
        #expect(result.total == 500)
        #expect(result.slices.map(\.category) == ["electricity", "water", "internet"])
        #expect(result.slices[0].total == 300)
        #expect(result.slices[0].billCount == 2)
        #expect(abs(result.slices[0].share - 0.6) < 0.0001)
    }

    @Test func tiedTotalsBreakAlphabetically() {
        let bills: [Entry] = [
            BillEntry(category: "water", amount: 100, paidAt: date(2026, 7, 1)),
            BillEntry(category: "gas", amount: 100, paidAt: date(2026, 7, 2))
        ]
        #expect(run(bills).slices.map(\.category) == ["gas", "water"])
    }

    @Test func emptyPeriodYieldsNoSlices() {
        let result = run([BillEntry(category: "electricity", amount: 100, paidAt: date(2025, 1, 1))])
        #expect(result.slices.isEmpty)
        #expect(result.total == 0)
    }

    // MARK: Headline

    @Test func headlineNamesTopCategoryAndShare() {
        let slices = [
            CategorySlice(category: "electricity", total: 300, billCount: 2, share: 0.6),
            CategorySlice(category: "internet", total: 200, billCount: 2, share: 0.4)
        ]
        #expect(
            InsightsMath.headline(slices: slices, period: .threeMonths)
                == "Electricity is your biggest, about 60% of the last 3 months."
        )
    }

    @Test func noHeadlineForSingleCategory() {
        let slices = [CategorySlice(category: "electricity", total: 300, billCount: 2, share: 1.0)]
        #expect(InsightsMath.headline(slices: slices, period: .threeMonths) == nil)
    }

    // MARK: Custom categories

    @Test func customCategoryRoundTripsAndDeduplicates() {
        let suite = UserDefaults(suiteName: "cat-test-\(UUID().uuidString)")!
        #expect(BillCategory.addCustom("  Body Corporate ", defaults: suite) == "body corporate")
        #expect(BillCategory.addCustom("body corporate", defaults: suite) == "body corporate")
        #expect(BillCategory.customs(defaults: suite) == ["body corporate"])
        // Standards never get duplicated into customs.
        #expect(BillCategory.addCustom("Electricity", defaults: suite) == "electricity")
        #expect(BillCategory.customs(defaults: suite) == ["body corporate"])
    }
}
