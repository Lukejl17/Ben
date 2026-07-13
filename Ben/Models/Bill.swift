import Foundation
import SwiftData

/// A bill Ben is tracking. Status is always derived from dates — never stored,
/// so it can't go stale overnight.
@Model
final class Bill {
    /// Stable identifier used in notification payloads.
    var uuid: String = UUID().uuidString
    var issuer: String
    var amount: Decimal
    var dueDate: Date
    var paidAt: Date?
    @Attribute(.externalStorage) var sourceImageData: Data?
    var notes: String
    var createdAt: Date
    /// How the bill got in: "photo", "pdf", "manual", "sample".
    var uploadMethod: String
    /// Set when reminders were scheduled for this bill.
    var hasNotification: Bool
    /// Notification identifiers scheduled for this bill, so they can be cancelled.
    var notificationIDs: [String]

    init(
        issuer: String,
        amount: Decimal,
        dueDate: Date,
        paidAt: Date? = nil,
        sourceImageData: Data? = nil,
        notes: String = "",
        createdAt: Date = .now,
        uploadMethod: String = "photo",
        hasNotification: Bool = false,
        notificationIDs: [String] = []
    ) {
        self.issuer = issuer
        self.amount = amount
        self.dueDate = dueDate
        self.paidAt = paidAt
        self.sourceImageData = sourceImageData
        self.notes = notes
        self.createdAt = createdAt
        self.uploadMethod = uploadMethod
        self.hasNotification = hasNotification
        self.notificationIDs = notificationIDs
    }

    var status: BillStatus {
        BillStatus.derive(dueDate: dueDate, paidAt: paidAt)
    }

    /// 1-based position of this bill by creation order. The PMF metric cares
    /// about the second bill specifically.
    func ordinal(in bills: [Bill]) -> Int {
        let sorted = bills.sorted { $0.createdAt < $1.createdAt }
        return (sorted.firstIndex { $0 === self } ?? sorted.count) + 1
    }

    func isSecondBill(in bills: [Bill]) -> Bool {
        ordinal(in: bills) == 2
    }
}

extension BillStatus {
    /// Days-until-due window that counts as "due soon".
    static let dueSoonWindowDays = 5

    /// Pure derivation so it can be tested hard: paid beats everything,
    /// overdue means the due day has fully passed, due soon is within 5 days
    /// (inclusive, including today), everything else is upcoming.
    static func derive(
        dueDate: Date,
        paidAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> BillStatus {
        if paidAt != nil { return .paid }
        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: dueDate)
        guard let days = calendar.dateComponents([.day], from: today, to: dueDay).day else {
            return .upcoming
        }
        if days < 0 { return .overdue }
        if days <= dueSoonWindowDays { return .dueSoon }
        return .upcoming
    }
}
