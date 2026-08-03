import Foundation
import Testing
@testable import Ben

struct InstallmentSplitterTests {
    @Test func equalAmountsPutsRemainderOnFirst() {
        // $3,034.29 / 4 → leftover cent on the first part.
        let parts = InstallmentSplitter.equalAmounts(total: Decimal(string: "3034.29")!, count: 4)
        #expect(parts.count == 4)
        #expect(parts[0] == Decimal(string: "758.58"))
        #expect(parts[1] == Decimal(string: "758.57"))
        #expect(parts[2] == Decimal(string: "758.57"))
        #expect(parts[3] == Decimal(string: "758.57"))
        #expect(InstallmentSplitter.sum(parts.map { InstallmentDraft(amount: $0, dueDate: .now) })
                == Decimal(string: "3034.29"))
    }

    @Test func singleInstalmentIsTheTotal() {
        let parts = InstallmentSplitter.equalAmounts(total: 100, count: 1)
        #expect(parts == [100])
    }

    @Test func spacedDatesQuarterly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let dates = InstallmentSplitter.spacedDates(
            starting: first, count: 4, monthsApart: 3, calendar: calendar
        )
        #expect(dates.count == 4)
        #expect(calendar.component(.month, from: dates[0]) == 8)
        #expect(calendar.component(.month, from: dates[1]) == 11)
        #expect(calendar.component(.month, from: dates[2]) == 2)
        #expect(calendar.component(.year, from: dates[2]) == 2027)
        #expect(calendar.component(.month, from: dates[3]) == 5)
    }

    @Test func draftsMatchCount() {
        let drafts = InstallmentSplitter.drafts(
            total: 100, firstDue: .now, count: 3, monthsApart: 1
        )
        #expect(drafts.count == 3)
        #expect(InstallmentSplitter.sum(drafts) == 100)
    }
}
