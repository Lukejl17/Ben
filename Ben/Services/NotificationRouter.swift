import Foundation
import Observation
import UserNotifications

/// Where a notification tap should land the user. Views observe and act.
@Observable @MainActor
final class NotificationRouter {
    /// Bill uuid to open (bill reminder tapped).
    var openBillID: String?
    /// B1 "remind me tonight" tapped — resume onboarding at S4.
    var resumeUploadRequested = false
    /// Day-4 nudge tapped — open the add-bill flow.
    var addBillRequested = false
    /// An emailed bill is staged on the coordinator — open the confirm flow.
    var confirmEmailBillRequested = false
}

/// UNUserNotificationCenter delegate: foreground presentation + tap routing.
/// MainActor-isolated; the async delegate requirements hop safely.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: NotificationRouter
    private let analytics: any AnalyticsService

    init(router: NotificationRouter, analytics: any AnalyticsService) {
        self.router = router
        self.analytics = analytics
    }

    /// Reminders stay visible even if the app happens to be open.
    /// Due-day deliveries also start the Lock Screen Live Activity.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        analytics.track(.notificationTriggered)
        let info = Self.sendableUserInfo(notification.request.content.userInfo)
        Task { @MainActor in
            await LiveActivityManager.startFromNotificationUserInfo(info)
        }
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo
        let info = Self.sendableUserInfo(raw)
        let kind = info["kind"] as? String
        let billID = info["billID"] as? String

        // "Remind me tomorrow": reschedule quietly, no app opening.
        if response.actionIdentifier == "snooze_tomorrow", let billID {
            let body = response.notification.request.content.body
            Task {
                await ReminderScheduler().scheduleSnooze(billID: billID, body: body)
            }
            completionHandler()
            return
        }

        analytics.track(.appOpenedFromNotification)
        // Tap on a due-day reminder is the reliable wake path to start the Live Activity.
        Task { @MainActor in
            await LiveActivityManager.startFromNotificationUserInfo(info)
            self.route(kind: kind, billID: billID)
        }
        completionHandler()
    }

    /// Copy notification payload into a Sendable dictionary for MainActor hops.
    nonisolated private static func sendableUserInfo(
        _ info: [AnyHashable: Any]
    ) -> [String: any Sendable] {
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

    private func route(kind: String?, billID: String?) {
        switch kind {
        case "resume_upload":
            router.resumeUploadRequested = true
        case "second_bill_nudge":
            router.addBillRequested = true
        default:
            router.openBillID = billID
        }
    }
}
