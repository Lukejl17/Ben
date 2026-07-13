import Foundation
import Testing
@testable import Ben

struct BillStatusTests {
    // Fixed reference: Wed 15 July 2026, 10:00 AEST (Sydney, winter — no DST).
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    var now: Date { date(2026, 7, 15) }

    func derived(due: Date, paidAt: Date? = nil, now: Date? = nil) -> BillStatus {
        BillStatus.derive(dueDate: due, paidAt: paidAt, now: now ?? self.now, calendar: calendar)
    }

    // MARK: Paid beats everything

    @Test func paidBillIsPaidEvenWhenOverdue() {
        #expect(derived(due: date(2026, 7, 1), paidAt: date(2026, 7, 2)) == .paid)
    }

    @Test func paidBillIsPaidEvenWhenFarInFuture() {
        #expect(derived(due: date(2026, 12, 25), paidAt: now) == .paid)
    }

    // MARK: Due-soon window boundaries (≤5 days, inclusive of today)

    @Test func dueTodayIsDueSoon() {
        #expect(derived(due: date(2026, 7, 15)) == .dueSoon)
    }

    @Test func dueEachDayInsideWindowIsDueSoon() {
        for offset in 1...5 {
            #expect(derived(due: date(2026, 7, 15 + offset)) == .dueSoon, "day +\(offset)")
        }
    }

    @Test func dueSixDaysOutIsUpcoming() {
        #expect(derived(due: date(2026, 7, 21)) == .upcoming)
    }

    @Test func dueFarOutIsUpcoming() {
        #expect(derived(due: date(2026, 9, 1)) == .upcoming)
    }

    // MARK: Overdue boundary

    @Test func dueYesterdayIsOverdue() {
        #expect(derived(due: date(2026, 7, 14)) == .overdue)
    }

    @Test func dueLongAgoIsOverdue() {
        #expect(derived(due: date(2026, 1, 1)) == .overdue)
    }

    // MARK: Midnight boundaries — day granularity, time of day irrelevant

    @Test func dueTodayAtOneMinutePastMidnightStillDueSoonLateEvening() {
        let lateNow = date(2026, 7, 15, 23, 59)
        #expect(derived(due: date(2026, 7, 15, 0, 1), now: lateNow) == .dueSoon)
    }

    @Test func dueYesterdayAtLastMinuteIsOverdueJustAfterMidnight() {
        let justAfterMidnight = date(2026, 7, 15, 0, 1)
        #expect(derived(due: date(2026, 7, 14, 23, 59), now: justAfterMidnight) == .overdue)
    }

    @Test func windowEdgeComputedByCalendarDaysNotHours() {
        // Due in 5 days + 13 hours of clock time, but only 5 calendar days: still due soon.
        let earlyNow = date(2026, 7, 15, 1, 0)
        #expect(derived(due: date(2026, 7, 20, 14, 0), now: earlyNow) == .dueSoon)
        // Due 6 calendar days out even though barely 5.5 days of clock time: upcoming.
        let lateNow = date(2026, 7, 15, 23, 0)
        #expect(derived(due: date(2026, 7, 21, 9, 0), now: lateNow) == .upcoming)
    }

    // MARK: Month / year rollovers

    @Test func windowSpansMonthBoundary() {
        let endOfMonth = date(2026, 7, 30)
        #expect(derived(due: date(2026, 8, 3), now: endOfMonth) == .dueSoon)
        #expect(derived(due: date(2026, 8, 5), now: endOfMonth) == .upcoming)
    }

    @Test func windowSpansYearBoundary() {
        let endOfYear = date(2026, 12, 30)
        #expect(derived(due: date(2027, 1, 3), now: endOfYear) == .dueSoon)
        #expect(derived(due: date(2027, 1, 5), now: endOfYear) == .upcoming)
    }

    // MARK: Timezone sensitivity

    @Test func statusUsesSuppliedCalendarTimezone() {
        // 14 July 23:00 in Honolulu is already 15 July 19:00 in Sydney.
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let instant = honolulu.date(
            from: DateComponents(year: 2026, month: 7, day: 14, hour: 23)
        )!
        let dueSameInstantDay = honolulu.date(
            from: DateComponents(year: 2026, month: 7, day: 14, hour: 8)
        )!
        // In Honolulu the bill is due "today" → dueSoon, not overdue.
        #expect(BillStatus.derive(dueDate: dueSameInstantDay, paidAt: nil, now: instant, calendar: honolulu) == .dueSoon)
        // Same instants interpreted in Sydney: both fall on 15 July → still same day.
        #expect(BillStatus.derive(dueDate: dueSameInstantDay, paidAt: nil, now: instant, calendar: calendar) == .dueSoon)
    }

    // MARK: Bill helpers

    @Test func ordinalAndSecondBillHelper() {
        let first = Bill(issuer: "AGL", amount: 243, dueDate: now, createdAt: date(2026, 7, 1))
        let second = Bill(issuer: "Telstra", amount: 89, dueDate: now, createdAt: date(2026, 7, 2))
        let third = Bill(issuer: "Sydney Water", amount: 130, dueDate: now, createdAt: date(2026, 7, 3))
        let all = [third, first, second]  // deliberately unsorted
        #expect(first.ordinal(in: all) == 1)
        #expect(second.ordinal(in: all) == 2)
        #expect(third.ordinal(in: all) == 3)
        #expect(!first.isSecondBill(in: all))
        #expect(second.isSecondBill(in: all))
        #expect(!third.isSecondBill(in: all))
    }
}
