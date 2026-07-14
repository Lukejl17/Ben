import Foundation
import Testing
@testable import Ben

struct ReminderSchedulerTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func date(_ day: Int, month: Int = 7, hour: Int = 10, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    func triggers(style: ReminderStyle, due: Date, now: Date) -> [Date] {
        ReminderScheduler.triggerDates(style: style, dueDate: due, now: now, calendar: calendar)
    }

    // MARK: Style × due date

    @Test func fewDaysEarlyFiresThreeDaysBeforeAtNine() {
        let dates = triggers(style: .fewDaysEarly, due: date(24), now: date(13))
        #expect(dates == [date(21, hour: 9)])
    }

    @Test func justBeforeFiresOnDueDayAtNine() {
        let dates = triggers(style: .justBefore, due: date(24), now: date(13))
        #expect(dates == [date(24, hour: 9)])
    }

    @Test func bothFiresTwiceInOrder() {
        let dates = triggers(style: .both, due: date(24), now: date(13))
        #expect(dates == [date(21, hour: 9), date(24, hour: 9)])
    }

    // MARK: Never in the past

    @Test func earlyReminderDropsWhenAlreadyPassed() {
        // Due in 2 days: the "3 days early" trigger would be yesterday.
        let dates = triggers(style: .both, due: date(15), now: date(13))
        #expect(dates == [date(15, hour: 9)])
    }

    @Test func dueDayReminderDropsAfterNineAM() {
        let dates = triggers(style: .justBefore, due: date(13), now: date(13, hour: 10))
        #expect(dates.isEmpty)
    }

    @Test func dueDayReminderKeptBeforeNineAM() {
        let dates = triggers(style: .justBefore, due: date(13), now: date(13, hour: 8))
        #expect(dates == [date(13, hour: 9)])
    }

    @Test func overdueBillGetsNoReminders() {
        let dates = triggers(style: .both, due: date(1), now: date(13))
        #expect(dates.isEmpty)
    }

    // MARK: Overdue cadence

    @Test func everyDayMentionsDailyFromDayAfterDue() {
        let dates = ReminderScheduler.overdueTriggerDates(
            cadence: .everyDay, dueDate: date(10), now: date(10), calendar: calendar
        )
        #expect(dates == (11...17).map { date($0, hour: 9) })
    }

    @Test func everySecondDayStepsByTwoCappedAtFour() {
        let dates = ReminderScheduler.overdueTriggerDates(
            cadence: .everySecondDay, dueDate: date(10), now: date(10), calendar: calendar
        )
        #expect(dates == [date(12, hour: 9), date(14, hour: 9), date(16, hour: 9), date(18, hour: 9)])
    }

    @Test func weeklyStepsBySevenCappedAtThree() {
        let dates = ReminderScheduler.overdueTriggerDates(
            cadence: .weekly, dueDate: date(1), now: date(1), calendar: calendar
        )
        #expect(dates == [date(8, hour: 9), date(15, hour: 9), date(22, hour: 9)])
    }

    @Test func onceMentionsExactlyOnce() {
        let dates = ReminderScheduler.overdueTriggerDates(
            cadence: .once, dueDate: date(10), now: date(10), calendar: calendar
        )
        #expect(dates == [date(11, hour: 9)])
    }

    @Test func overdueMentionsAlreadyPassedAreDropped() {
        // Bill went overdue days ago: only future mentions remain.
        let dates = ReminderScheduler.overdueTriggerDates(
            cadence: .everySecondDay, dueDate: date(10), now: date(15), calendar: calendar
        )
        #expect(dates == [date(16, hour: 9), date(18, hour: 9)])
    }

    @Test func overdueCopyIsFactualAndNamesTheDate() {
        let body = ReminderScheduler.overdueBody(issuer: "AGL", dueDate: date(24), calendar: calendar)
        #expect(body == "Ben here — AGL was due 24 July and still needs a look.")
    }

    // MARK: B1 tonight nudge

    @Test func tonightNudgeAtSevenPMWhenEarlier() {
        let trigger = ReminderScheduler.tonightTrigger(now: date(13, hour: 14), calendar: calendar)
        #expect(trigger == date(13, hour: 19))
    }

    @Test func tonightNudgeRollsToMorningWhenPastSeven() {
        let trigger = ReminderScheduler.tonightTrigger(now: date(13, hour: 20), calendar: calendar)
        #expect(trigger == date(14, hour: 9))
    }

    // MARK: Day-4 nudge

    @Test func dayFourNudgeLandsFourDaysOutAtNine() {
        let trigger = ReminderScheduler.dayFourNudgeTrigger(now: date(13, hour: 22), calendar: calendar)
        #expect(trigger == date(17, hour: 9))
    }

    // MARK: Copy — factual, calm, correct grain

    @Test func copySaysTodayOnDueDay() {
        let body = ReminderScheduler.reminderBody(
            issuer: "AGL", dueDate: date(24), triggerDate: date(24, hour: 9), calendar: calendar
        )
        #expect(body == "Ben here — AGL is due today.")
    }

    @Test func copySaysTomorrowOneDayOut() {
        let body = ReminderScheduler.reminderBody(
            issuer: "Telstra", dueDate: date(24), triggerDate: date(23, hour: 9), calendar: calendar
        )
        #expect(body == "Ben here — Telstra is due tomorrow.")
    }

    @Test func copyUsesWeekdayInsideAWeek() {
        // 24 July 2026 is a Friday.
        let body = ReminderScheduler.reminderBody(
            issuer: "AGL", dueDate: date(24), triggerDate: date(21, hour: 9), calendar: calendar
        )
        #expect(body == "Ben here — AGL is due Friday.")
    }

    @Test func copyUsesDateBeyondAWeek() {
        let body = ReminderScheduler.reminderBody(
            issuer: "Sydney Water", dueDate: date(24), triggerDate: date(13, hour: 9), calendar: calendar
        )
        #expect(body == "Ben here — Sydney Water is due 24 July.")
    }
}
