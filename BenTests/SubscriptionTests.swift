import Foundation
import Testing
@testable import Ben

struct SubscriptionTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func makeService() -> StubSubscriptionService {
        let suite = UserDefaults(suiteName: "trial-test-\(UUID().uuidString)")!
        return StubSubscriptionService(defaults: suite, calendar: calendar)
    }

    func date(_ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    @Test func startsAsNotStarted() {
        #expect(makeService().state(now: date(13)) == .notStarted)
    }

    @Test func dayZeroHasSevenDaysRemaining() {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 2, now: date(13))
        #expect(service.state(now: date(13)) == .active(daysRemaining: 7))
    }

    @Test func countsDownByCalendarDayNotClockTime() {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 2, now: date(13, hour: 23))
        // 25 hours later but 2 calendar days on: 5 remaining.
        #expect(service.state(now: date(15, hour: 0)) == .active(daysRemaining: 5))
    }

    @Test func lastTrialDayIsStillActive() {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 2, now: date(13))
        #expect(service.state(now: date(19, hour: 23)) == .active(daysRemaining: 1))
    }

    @Test func daySevenIsLapsed() {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 2, now: date(13))
        #expect(service.state(now: date(20, hour: 0)) == .lapsed)
    }

    @Test func trialCannotBeRestarted() {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 2, now: date(1))
        service.startTrial(preChargeReminderDaysBeforeEnd: 5, now: date(25))
        #expect(service.state(now: date(25)) == .lapsed)
        #expect(service.preChargeReminderDaysBeforeEnd == 2)
    }

    @Test func persistsChosenReminderDay() {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 3, now: date(13))
        #expect(service.preChargeReminderDaysBeforeEnd == 3)
    }
}
