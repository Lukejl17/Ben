import Foundation
import Testing
@testable import Ben

struct ExporterTests {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    var now: Date { date(2026, 7, 15) }

    func row(_ issuer: String, due: Date, amount: Decimal = 100, paidAt: Date? = nil) -> BillExporter.Row {
        BillExporter.Row(
            issuer: issuer, category: "electricity", amount: amount, dueDate: due,
            paidAt: paidAt, status: "Upcoming", uploadMethod: "photo", createdAt: due
        )
    }

    // MARK: Period windows

    @Test func sevenDayWindowFiltersInclusive() {
        let rows = [
            row("edge", due: date(2026, 7, 8, hour: 0)),      // exactly 7 days back
            row("outside", due: date(2026, 7, 7)),
            row("today", due: date(2026, 7, 15, hour: 23)),
            row("future", due: date(2026, 7, 16))
        ]
        let out = BillExporter.rows(in: .last7Days, from: rows, now: now, calendar: calendar)
        #expect(out.map(\.issuer) == ["edge", "today"])
    }

    @Test func twelveMonthWindow() {
        let rows = [
            row("in", due: date(2025, 7, 20)),
            row("out", due: date(2025, 7, 10))
        ]
        let out = BillExporter.rows(in: .last12Months, from: rows, now: now, calendar: calendar)
        #expect(out.map(\.issuer) == ["in"])
    }

    @Test func customRangeNormalisesBackwardsPick() {
        let rows = [row("in", due: date(2026, 6, 10)), row("out", due: date(2026, 6, 20))]
        let period = ExportPeriod.custom(from: date(2026, 6, 15), to: date(2026, 6, 1))  // backwards
        let out = BillExporter.rows(in: period, from: rows, now: now, calendar: calendar)
        #expect(out.map(\.issuer) == ["in"])
    }

    @Test func rowsSortByDueDate() {
        let rows = [row("b", due: date(2026, 7, 14)), row("a", due: date(2026, 7, 10))]
        let out = BillExporter.rows(in: .last30Days, from: rows, now: now, calendar: calendar)
        #expect(out.map(\.issuer) == ["a", "b"])
    }

    // MARK: CSV shape

    @Test func csvHasHeaderAndISO8601Dates() {
        let csv = BillExporter.csv(for: [row("AGL", due: date(2026, 7, 24), amount: 243)])
        let lines = csv.split(separator: "\n")
        #expect(lines[0] == "Issuer,Category,Amount,Due date,Status,Paid date,Added,Upload method")
        #expect(lines[1].contains("AGL,electricity,243,2026-07-24,Upcoming,,2026-07-24,photo"))
    }

    @Test func csvEscapesCommasAndQuotes() {
        #expect(BillExporter.escape("Bob's Plumbing, Sydney") == "\"Bob's Plumbing, Sydney\"")
        #expect(BillExporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(BillExporter.escape("plain") == "plain")
    }

    @Test func paidDateAppearsWhenPresent() {
        let csv = BillExporter.csv(for: [row("AGL", due: date(2026, 7, 1), paidAt: date(2026, 7, 3))])
        #expect(csv.contains("2026-07-03"))
    }

    @Test func tempFileWritesAndNamesByDay() throws {
        let url = try BillExporter.writeTempFile(csv: "a,b\n", now: now)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "ben-bills-2026-07-15.csv")
        #expect(try String(contentsOf: url, encoding: .utf8) == "a,b\n")
    }
}

struct AccountServiceTests {
    func makeService() -> StubAccountService {
        StubAccountService(defaults: UserDefaults(suiteName: "acct-\(UUID().uuidString)")!)
    }

    @Test func signInCreatesAndPersistsAccount() async throws {
        let service = makeService()
        #expect(service.account == nil)
        let account = try await service.signIn(with: .apple)
        #expect(account.provider == .apple)
        #expect(service.account == account)
        #expect(account.forwardingAddress.hasPrefix("bills-"))
        #expect(account.forwardingAddress.hasSuffix("@ben.app"))
    }

    @Test func repeatSignInReturnsSameAccount() async throws {
        let service = makeService()
        let first = try await service.signIn(with: .google)
        let second = try await service.signIn(with: .apple)  // already signed in
        #expect(first == second)
    }

    @Test func signOutClearsAccount() async throws {
        let service = makeService()
        try await service.signIn(with: .apple)
        service.signOut()
        #expect(service.account == nil)
    }

    @Test func forwardingAddressIsDeterministicAndClean() {
        let address = StubAccountService.forwardingAddress(for: "ABCD-1234-EF56-7890")
        #expect(address == "bills-abcd1234@ben.app")
    }
}
