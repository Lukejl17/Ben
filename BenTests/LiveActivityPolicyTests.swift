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

    private func snapshot(
        id: String = "a",
        due: Date,
        paidAt: Date? = nil
    ) -> BillLiveActivitySnapshot {
        BillLiveActivitySnapshot(
            billID: id, issuer: "AGL", amount: 100, dueDate: due, paidAt: paidAt
        )
    }

    @Test func fewDaysEarlyStillPresentsOnDueDay() {
        let due = date(2026, 8, 5)
        #expect(BillDueLiveActivityPolicy.shouldPresent(dueDate: due, paidAt: nil, now: due, calendar: calendar))
    }

    @Test func dueTodayPresents() {
        let due = date(2026, 8, 5)
        #expect(BillDueLiveActivityPolicy.shouldPresent(dueDate: due, paidAt: nil, now: due, calendar: calendar))
    }

    @Test func overduePresents() {
        let due = date(2026, 8, 1)
        let now = date(2026, 8, 5)
        #expect(BillDueLiveActivityPolicy.shouldPresent(dueDate: due, paidAt: nil, now: now, calendar: calendar))
    }

    @Test func futureDueDateDoesNotPresent() {
        let due = date(2026, 8, 5)
        let now = date(2026, 8, 4)
        #expect(!BillDueLiveActivityPolicy.shouldPresent(dueDate: due, paidAt: nil, now: now, calendar: calendar))
    }

    @Test func paidBillDoesNotPresent() {
        let due = date(2026, 8, 5)
        #expect(!BillDueLiveActivityPolicy.shouldPresent(dueDate: due, paidAt: due, now: due, calendar: calendar))
    }

    @Test func onlyTheMostUrgentUnpaidBillIsShown() {
        let now = date(2026, 8, 10)
        let shown = BillDueLiveActivityPolicy.snapshotsToPresent(
            [
                snapshot(id: "later-overdue", due: date(2026, 8, 8)),
                snapshot(id: "oldest-overdue", due: date(2026, 8, 1)),
                snapshot(id: "paid", due: date(2026, 8, 1), paidAt: now),
                snapshot(id: "future", due: date(2026, 8, 20))
            ],
            now: now,
            calendar: calendar
        )
        #expect(shown.map(\.billID) == ["oldest-overdue"])
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

struct LiveActivityNotificationPayloadTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func sendable(_ info: [AnyHashable: Any]) -> [String: any Sendable] {
        var out: [String: any Sendable] = [:]
        for (key, value) in info {
            guard let key = key as? String else { continue }
            switch value {
            case let string as String: out[key] = string
            case let bool as Bool: out[key] = bool
            case let number as NSNumber: out[key] = number
            case let double as Double: out[key] = double
            case let int as Int: out[key] = int
            default: break
            }
        }
        return out
    }

    @Test func stringEncodedDueDayStarts() {
        let due = date(2026, 8, 5)
        let info = sendable(
            ReminderScheduler.reminderUserInfo(
                billID: "1", issuer: "AGL", amount: 42, dueDate: due, isDueDay: true
            )
        )
        #expect(LiveActivityNotificationPayload.shouldStart(from: info, now: due, calendar: calendar))
        #expect(LiveActivityNotificationPayload.billID(from: info) == "1")
        #expect(LiveActivityNotificationPayload.issuer(from: info) == "AGL")
        #expect(LiveActivityNotificationPayload.amount(from: info) == 42)
    }

    @Test func nsNumberBoolFromLegacyPayloadStarts() {
        let due = date(2026, 8, 5)
        let info: [String: any Sendable] = [
            "billID": "1",
            "kind": "bill_reminder",
            "issuer": "AGL",
            "isDueDay": NSNumber(value: true)
        ]
        #expect(LiveActivityNotificationPayload.shouldStart(from: info, now: due, calendar: calendar))
    }

    @Test func threeDaysEarlyDoesNotStart() {
        let due = date(2026, 8, 10)
        let now = date(2026, 8, 7)
        let info = sendable(
            ReminderScheduler.reminderUserInfo(
                billID: "1", issuer: "AGL", amount: 10, dueDate: due, isDueDay: false
            )
        )
        #expect(!LiveActivityNotificationPayload.shouldStart(from: info, now: now, calendar: calendar))
    }

    @Test func overduePayloadStartsEvenWithoutDueDayFlag() {
        let due = date(2026, 8, 1)
        let now = date(2026, 8, 5)
        let info = sendable(
            ReminderScheduler.reminderUserInfo(
                billID: "1", issuer: "AGL", amount: 10, dueDate: due, isDueDay: false
            )
        )
        #expect(LiveActivityNotificationPayload.shouldStart(from: info, now: now, calendar: calendar))
    }

    @Test func nudgesNeverStartLiveActivity() {
        let info: [String: any Sendable] = ["kind": "second_bill_nudge", "billID": "1"]
        #expect(!LiveActivityNotificationPayload.shouldStart(from: info))
    }

    @Test func boolValueReadsAllCommonBridges() {
        #expect(LiveActivityNotificationPayload.boolValue(true) == true)
        #expect(LiveActivityNotificationPayload.boolValue(NSNumber(value: 1)) == true)
        #expect(LiveActivityNotificationPayload.boolValue("1") == true)
        #expect(LiveActivityNotificationPayload.boolValue("true") == true)
        #expect(LiveActivityNotificationPayload.boolValue(0) == false)
        #expect(LiveActivityNotificationPayload.boolValue("0") == false)
    }
}
