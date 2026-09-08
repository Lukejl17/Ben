import Foundation
import Testing
@testable import Ben

struct AnalyticsTests {
    @Test func eventNamesAreExactlyAsSpecced() {
        let expectations: [(AnalyticsEvent, String)] = [
            (.onboardingStarted, "onboarding_started"),
            (.intentSelected(intent: "new_home"), "intent_selected"),
            (.reminderStyleSelected(style: "few_days_early"), "reminder_style_selected"),
            (.billUploadStarted(uploadMethod: "photo"), "bill_upload_started"),
            (.billParseSucceeded, "bill_parse_succeeded"),
            (.billParseFailed, "bill_parse_failed"),
            (.manualEntryStarted, "manual_entry_started"),
            (.manualEntryCompleted, "manual_entry_completed"),
            (
                .billUploadCompleted(
                    billCountAfterUpload: 1, isFirstBill: true, isSecondBill: false,
                    uploadMethod: "photo", hasNotification: true
                ),
                "bill_upload_completed"
            ),
            (.notificationSet, "notification_set"),
            (.osPermissionGranted, "os_permission_granted"),
            (.osPermissionDenied, "os_permission_denied"),
            (.accountCreated, "account_created"),
            (.paywallViewed(pageDepth: 2), "paywall_viewed"),
            (.trialStarted, "trial_started"),
            (.trialAbandonedAtPaywall, "trial_abandoned_at_paywall"),
            (.secondBillPromptShown, "second_bill_prompt_shown"),
            (.forwardingSetup, "forwarding_setup"),
            (.onboardingCompleted(path: "second_bill"), "onboarding_completed"),
            (.activationDeferred, "activation_deferred"),
            (.notificationTriggered, "notification_triggered"),
            (.appOpenedFromNotification, "app_opened_from_notification")
        ]
        for (event, name) in expectations {
            #expect(event.name == name)
        }
    }

    @Test func onboardingCompletedCarriesPath() {
        #expect(
            AnalyticsEvent.onboardingCompleted(path: "deferred").properties["path"]
                == .string("deferred")
        )
    }

    @Test func billUploadCompletedCarriesAllSpeccedProperties() {
        let event = AnalyticsEvent.billUploadCompleted(
            billCountAfterUpload: 2, isFirstBill: false, isSecondBill: true,
            uploadMethod: "pdf", hasNotification: false
        )
        let props = event.properties
        #expect(props["bill_count_after_upload"] == .int(2))
        #expect(props["is_first_bill"] == .bool(false))
        #expect(props["is_second_bill"] == .bool(true))
        #expect(props["upload_method"] == .string("pdf"))
        #expect(props["has_notification"] == .bool(false))
    }

    @Test func paywallViewedCarriesPageDepth() {
        #expect(AnalyticsEvent.paywallViewed(pageDepth: 3).properties["page_depth"] == .int(3))
    }

    @Test func localAnalyticsWritesJSONLines() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "analytics-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let analytics = LocalAnalytics(fileURL: url)
        analytics.track(.onboardingStarted)
        analytics.track(.paywallViewed(pageDepth: 1))
        analytics.flush()

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
        #expect(lines.count == 2)
        let decoder = JSONDecoder()
        let first = try decoder.decode(LocalAnalytics.Record.self, from: Data(lines[0].utf8))
        let second = try decoder.decode(LocalAnalytics.Record.self, from: Data(lines[1].utf8))
        #expect(first.name == "onboarding_started")
        #expect(second.name == "paywall_viewed")
        #expect(second.properties["page_depth"] == .int(1))
    }
}
