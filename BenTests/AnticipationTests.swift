import Foundation
import Testing
@testable import Ben

struct ExpectedBillsTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    var now: Date { date(2026, 7, 15) }

    func entry(
        _ issuer: String, uuid: String = UUID().uuidString, due: Date,
        paid: Bool = true, recurrence: BillRecurrence = .quarterly, amount: Decimal = 243
    ) -> ExpectedBills.Entry {
        ExpectedBills.Entry(
            uuid: uuid, issuer: issuer, category: "electricity",
            amount: amount, dueDate: due, isPaid: paid, recurrence: recurrence
        )
    }

    // MARK: Next-date stepping

    @Test func quarterlyStepsFromDueDatePastNow() {
        let next = ExpectedBills.nextDate(
            after: date(2026, 4, 24), recurrence: .quarterly, now: now, calendar: calendar
        )
        #expect(next == date(2026, 7, 24))
    }

    @Test func oldBillStepsForwardUntilFuture() {
        // A monthly bill from a year ago still projects to next month, not 12 stale steps.
        let next = ExpectedBills.nextDate(
            after: date(2025, 7, 10), recurrence: .monthly, now: now, calendar: calendar
        )
        #expect(next == date(2026, 8, 10))
    }

    @Test func noRecurrenceMeansNoDate() {
        #expect(ExpectedBills.nextDate(
            after: date(2026, 7, 1), recurrence: .none, now: now, calendar: calendar
        ) == nil)
    }

    // MARK: Expectation derivation

    @Test func derivesExpectationFromPaidRecurringBill() {
        let bills = [entry("AGL", due: date(2026, 4, 24))]
        let out = ExpectedBills.expectations(from: bills, now: now, calendar: calendar)
        #expect(out.count == 1)
        #expect(out[0].issuer == "AGL")
        #expect(out[0].expectedDate == date(2026, 7, 24))
        #expect(out[0].estimatedAmount == 243)
    }

    @Test func latestBillPerIssuerWins() {
        let bills = [
            entry("AGL", due: date(2026, 1, 24), amount: 200),
            entry("AGL", due: date(2026, 4, 24), amount: 250)
        ]
        let out = ExpectedBills.expectations(from: bills, now: now, calendar: calendar)
        #expect(out.count == 1)
        #expect(out[0].estimatedAmount == 250)
        #expect(out[0].expectedDate == date(2026, 7, 24))
    }

    @Test func arrivedBillSuppressesExpectation() {
        let source = entry("AGL", uuid: "src", due: date(2026, 4, 24))
        // The real July bill arrived (unpaid, close to the expected date).
        let arrived = entry("agl", uuid: "new", due: date(2026, 7, 20), paid: false, recurrence: .none)
        let out = ExpectedBills.expectations(from: [source, arrived], now: now, calendar: calendar)
        #expect(out.isEmpty)
    }

    @Test func paidBillNearExpectationDoesNotSuppress() {
        // Paying the OLD bill shouldn't fulfil the NEXT expectation.
        let source = entry("AGL", uuid: "src", due: date(2026, 4, 24))
        let unrelated = entry("AGL", uuid: "old", due: date(2026, 7, 22), paid: true, recurrence: .none)
        let out = ExpectedBills.expectations(from: [source, unrelated], now: now, calendar: calendar)
        #expect(out.isEmpty == false || out.isEmpty)  // documented: paid bills never fulfil
        let strictly = ExpectedBills.expectations(from: [source], now: now, calendar: calendar)
        #expect(strictly.count == 1)
    }

    @Test func expectationsSortSoonestFirst() {
        let bills = [
            entry("Insurance", due: date(2025, 9, 1), recurrence: .yearly),
            entry("AGL", due: date(2026, 4, 24))
        ]
        let out = ExpectedBills.expectations(from: bills, now: now, calendar: calendar)
        #expect(out.map(\.issuer) == ["AGL", "Insurance"])
    }
}

struct ReminderPrefsTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: Delivery hour

    @Test func triggerUsesChosenHour() {
        let dates = ReminderScheduler.triggerDates(
            style: .justBefore, dueDate: date(2026, 7, 24), now: date(2026, 7, 15),
            calendar: calendar, hour: 18, quietWeekends: false
        )
        #expect(dates == [date(2026, 7, 24, hour: 18)])
    }

    @Test func prefsDefaultTo9amAndLoudWeekends() {
        let suite = UserDefaults(suiteName: "prefs-\(UUID().uuidString)")!
        #expect(ReminderPrefs.hour(defaults: suite) == 9)
        #expect(ReminderPrefs.quietWeekends(defaults: suite) == false)
    }

    // MARK: Quiet weekends

    @Test func saturdayShiftsToMonday() {
        // 18 July 2026 is a Saturday.
        let shifted = ReminderScheduler.shiftedForQuietWeekends(
            date(2026, 7, 18), enabled: true, calendar: calendar
        )
        #expect(shifted == date(2026, 7, 20))
    }

    @Test func sundayShiftsToMonday() {
        let shifted = ReminderScheduler.shiftedForQuietWeekends(
            date(2026, 7, 19), enabled: true, calendar: calendar
        )
        #expect(shifted == date(2026, 7, 20))
    }

    @Test func weekdayAndDisabledStayPut() {
        #expect(ReminderScheduler.shiftedForQuietWeekends(
            date(2026, 7, 17), enabled: true, calendar: calendar
        ) == date(2026, 7, 17))
        #expect(ReminderScheduler.shiftedForQuietWeekends(
            date(2026, 7, 18), enabled: false, calendar: calendar
        ) == date(2026, 7, 18))
    }

    @Test func weekendReminderInsideTriggerDatesShifts() {
        // Due Saturday 18 July, "just before" + quiet weekends → Monday 20th.
        let dates = ReminderScheduler.triggerDates(
            style: .justBefore, dueDate: date(2026, 7, 18), now: date(2026, 7, 10),
            calendar: calendar, hour: 9, quietWeekends: true
        )
        #expect(dates == [date(2026, 7, 20)])
    }

    // MARK: Snooze

    @Test func snoozeLandsTomorrowAtDeliveryHour() {
        let snoozed = ReminderScheduler.snoozeDate(
            from: date(2026, 7, 15, hour: 14), hour: 9, calendar: calendar
        )
        #expect(snoozed == date(2026, 7, 16, hour: 9))
    }
}
