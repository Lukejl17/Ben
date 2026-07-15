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
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        analytics.track(.notificationTriggered)
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
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
        Task { @MainActor in
            self.route(kind: kind, billID: billID)
        }
        completionHandler()
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
