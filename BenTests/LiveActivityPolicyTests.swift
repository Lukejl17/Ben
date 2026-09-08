import Foundation
import Testing
@testable import Ben

struct LiveActivityPolicyTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func fewDaysEarlyNeverGetsLiveActivity() {
        let due = date(2026, 8, 5)
        #expect(!BillDueLiveActivityPolicy.shouldPresent(
            style: .fewDaysEarly, dueDate: due, paidAt: nil, now: due, calendar: calendar
        ))
    }

    @Test func justBeforeOnDueDayPresents() {
        let due = date(2026, 8, 5)
        #expect(BillDueLiveActivityPolicy.shouldPresent(
            style: .justBefore, dueDate: due, paidAt: nil, now: due, calendar: calendar
        ))
    }

    @Test func bothOnDueDayPresents() {
        let due = date(2026, 8, 5)
        #expect(BillDueLiveActivityPolicy.shouldPresent(
            style: .both, dueDate: due, paidAt: nil, now: due, calendar: calendar
        ))
    }

    @Test func notOnDueDayDoesNotPresent() {
        let due = date(2026, 8, 5)
        let now = date(2026, 8, 4)
        #expect(!BillDueLiveActivityPolicy.shouldPresent(
            style: .justBefore, dueDate: due, paidAt: nil, now: now, calendar: calendar
        ))
    }

    @Test func paidBillDoesNotPresent() {
        let due = date(2026, 8, 5)
        #expect(!BillDueLiveActivityPolicy.shouldPresent(
            style: .justBefore, dueDate: due, paidAt: due, now: due, calendar: calendar
        ))
    }

    @Test func styleIncludesDueDay() {
        #expect(!BillDueLiveActivityPolicy.styleIncludesDueDay(.fewDaysEarly))
        #expect(BillDueLiveActivityPolicy.styleIncludesDueDay(.justBefore))
        #expect(BillDueLiveActivityPolicy.styleIncludesDueDay(.both))
    }

    @Test func triggerScheduleTagsDueDayOffset() {
        let due = date(2026, 8, 10)
        let now = date(2026, 8, 1)
        let schedule = ReminderScheduler.triggerSchedule(
            style: .both, dueDate: due, now: now, calendar: calendar, hour: 9, quietWeekends: false
        )
        #expect(schedule.map(\.offset) == [-3, 0])
        #expect(schedule.contains { $0.offset == 0 })
    }
}
