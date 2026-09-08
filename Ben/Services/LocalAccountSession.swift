import Foundation
import SwiftData
import UserNotifications

/// Local-first v1 keeps bills on-device only. Sign-out (or switching Firebase
/// users) must clear that shelf so the next account never inherits the last.
enum LocalAccountSession {
    static let lastAccountIdKey = "benLastAccountId"

    /// Drop every tracked bill, pending local notifications, and user-bound prefs.
    @MainActor
    static func wipeDeviceData(
        modelContext: ModelContext,
        scheduler: ReminderScheduler,
        pendingEmails: PendingEmailMonitor? = nil,
        defaults: UserDefaults = .standard
    ) {
        let bills = (try? modelContext.fetch(FetchDescriptor<Bill>())) ?? []
        for bill in bills {
            scheduler.cancel(identifiers: bill.notificationIDs)
            scheduler.cancel(identifiers: ["expect-\(bill.uuid)"])
            let billID = bill.uuid
            Task { await LiveActivityManager.end(billID: billID) }
            modelContext.delete(bill)
        }
        scheduler.cancel(identifiers: ["second-bill-day4"])
        try? modelContext.save()

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        pendingEmails?.clear()

        defaults.removeObject(forKey: lastAccountIdKey)
        defaults.removeObject(forKey: OnboardingAttributes.storageKey)
        defaults.removeObject(forKey: "notificationReaskPending")
    }

    /// Call after a successful sign-in.
    /// - Parameter assumeUnownedBillsAreForeign: Welcome "I already have an account"
    ///   path — if nothing is bound to this device yet but bills exist, they
    ///   belong to a prior session and must go before this account takes over.
    @MainActor
    static func bindAccount(
        _ account: BenAccount,
        modelContext: ModelContext,
        scheduler: ReminderScheduler,
        pendingEmails: PendingEmailMonitor? = nil,
        defaults: UserDefaults = .standard,
        assumeUnownedBillsAreForeign: Bool = false
    ) {
        let previous = defaults.string(forKey: lastAccountIdKey)
        let billCount = (try? modelContext.fetch(FetchDescriptor<Bill>()))?.count ?? 0

        let switchingUser = previous != nil && previous != account.id
        let unownedLeftovers = assumeUnownedBillsAreForeign && previous == nil && billCount > 0

        if switchingUser || unownedLeftovers {
            wipeDeviceData(
                modelContext: modelContext,
                scheduler: scheduler,
                pendingEmails: pendingEmails,
                defaults: defaults
            )
        }
        defaults.set(account.id, forKey: lastAccountIdKey)
    }

    /// Remember who owns this device shelf after a fresh onboarding account.
    static func remember(_ account: BenAccount, defaults: UserDefaults = .standard) {
        defaults.set(account.id, forKey: lastAccountIdKey)
    }
}
