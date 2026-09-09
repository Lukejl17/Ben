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

    @Test func stubPurchaseAnnualStartsTrial() async throws {
        let service = makeService()
        service.startTrial(preChargeReminderDaysBeforeEnd: 2, now: date(13))
        let outcome = try await service.purchase(.annual)
        #expect(outcome == .entitled)
        #expect(service.state(now: date(13)) == .active(daysRemaining: 7))
    }

    @Test func stubPurchaseMonthlyIsSubscribed() async throws {
        let service = makeService()
        let outcome = try await service.purchase(.monthly)
        #expect(outcome == .entitled)
        #expect(service.state(now: date(13)) == .subscribed)
    }

    @Test func stubRestoreWithoutEntitlementFails() async {
        let service = makeService()
        await #expect(throws: SubscriptionError.notEntitled) {
            try await service.restore()
        }
    }

    @Test func productIDsMatchAppStoreConnect() {
        #expect(RevenueCatConfig.annualProductID == "com.repertoirestudio.Ben.pro.yearly")
        #expect(RevenueCatConfig.monthlyProductID == "com.repertoirestudio.Ben.pro.monthly")
        #expect(RevenueCatConfig.entitlementID == "ben_pro")
    }

    @Test func entitlementMappingTrialCountsRemainingDays() {
        let expiry = date(20)
        let state = EntitlementMapping.state(
            isActive: true, expirationDate: expiry, period: .trial, now: date(13), calendar: calendar
        )
        #expect(state == .active(daysRemaining: 7))
    }

    @Test func entitlementMappingInactiveIsLapsed() {
        #expect(
            EntitlementMapping.state(
                isActive: false, expirationDate: date(20), period: .normal, now: date(13), calendar: calendar
            ) == .lapsed
        )
    }

    @Test func entitlementMappingPaidIsSubscribed() {
        #expect(
            EntitlementMapping.state(
                isActive: true, expirationDate: date(20), period: .normal, now: date(13), calendar: calendar
            ) == .subscribed
        )
    }

    @Test func legalLinksAreTheLiveSite() {
        #expect(BenLegalLinks.privacy.absoluteString == "https://benandbill.app/privacy")
        #expect(BenLegalLinks.terms.absoluteString == "https://benandbill.app/terms")
        #expect(BenLegalLinks.support.absoluteString == "https://benandbill.app/support")
    }
}

