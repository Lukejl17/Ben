import Foundation
import os

// MARK: - Events
// Names and properties are locked by docs/onboarding-flow.md — do not rename.

enum AnalyticsEvent: Sendable {
    case onboardingStarted
    case intentSelected(intent: String)
    case reminderStyleSelected(style: String)
    case billUploadStarted(uploadMethod: String)
    case billParseSucceeded
    case billParseFailed
    case manualEntryStarted
    case manualEntryCompleted
    case billUploadCompleted(
        billCountAfterUpload: Int,
        isFirstBill: Bool,
        isSecondBill: Bool,
        uploadMethod: String,
        hasNotification: Bool
    )
    case notificationSet
    case osPermissionGranted
    case osPermissionDenied
    case accountCreated
    case paywallViewed(pageDepth: Int)
    case trialStarted
    case trialAbandonedAtPaywall
    case secondBillPromptShown
    case forwardingSetup
    /// Funnel end — `path` is `second_bill` or `deferred` (S10 “Later's fine”).
    case onboardingCompleted(path: String)
    case activationDeferred
    case notificationTriggered
    case appOpenedFromNotification

    var name: String {
        switch self {
        case .onboardingStarted: "onboarding_started"
        case .intentSelected: "intent_selected"
        case .reminderStyleSelected: "reminder_style_selected"
        case .billUploadStarted: "bill_upload_started"
        case .billParseSucceeded: "bill_parse_succeeded"
        case .billParseFailed: "bill_parse_failed"
        case .manualEntryStarted: "manual_entry_started"
        case .manualEntryCompleted: "manual_entry_completed"
        case .billUploadCompleted: "bill_upload_completed"
        case .notificationSet: "notification_set"
        case .osPermissionGranted: "os_permission_granted"
        case .osPermissionDenied: "os_permission_denied"
        case .accountCreated: "account_created"
        case .paywallViewed: "paywall_viewed"
        case .trialStarted: "trial_started"
        case .trialAbandonedAtPaywall: "trial_abandoned_at_paywall"
        case .secondBillPromptShown: "second_bill_prompt_shown"
        case .forwardingSetup: "forwarding_setup"
        case .onboardingCompleted: "onboarding_completed"
        case .activationDeferred: "activation_deferred"
        case .notificationTriggered: "notification_triggered"
        case .appOpenedFromNotification: "app_opened_from_notification"
        }
    }

    var properties: [String: AnalyticsValue] {
        switch self {
        case .intentSelected(let intent):
            ["intent_context": .string(intent)]
        case .reminderStyleSelected(let style):
            ["reminder_style": .string(style)]
        case .billUploadStarted(let method):
            ["upload_method": .string(method)]
        case .billUploadCompleted(let count, let first, let second, let method, let notif):
            [
                "bill_count_after_upload": .int(count),
                "is_first_bill": .bool(first),
                "is_second_bill": .bool(second),
                "upload_method": .string(method),
                "has_notification": .bool(notif)
            ]
        case .paywallViewed(let depth):
            ["page_depth": .int(depth)]
        case .onboardingCompleted(let path):
            ["path": .string(path)]
        default:
            [:]
        }
    }
}

enum AnalyticsValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value) } else
        if let value = try? container.decode(Int.self) { self = .int(value) } else {
            self = .string(try container.decode(String.self))
        }
    }
}

// MARK: - Service

protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}

/// Console + local JSON-lines log. PostHog replaces this later.
/// HUMAN: PostHog API key required for the real integration.
final class LocalAnalytics: AnalyticsService {
    struct Record: Codable {
        let name: String
        let properties: [String: AnalyticsValue]
        let timestamp: Date
    }

    private let logger = Logger(subsystem: "com.lukelongworth.Ben", category: "analytics")
    private let fileURL: URL
    private let queue = DispatchQueue(label: "ben.analytics", qos: .utility)

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "analytics-log.jsonl")
    }

    func track(_ event: AnalyticsEvent) {
        let record = Record(name: event.name, properties: event.properties, timestamp: .now)
        logger.info("\(record.name, privacy: .public) \(String(describing: event.properties), privacy: .public)")
        let url = fileURL
        queue.async {
            guard var line = try? JSONEncoder().encode(record) else { return }
            line.append(Data("\n".utf8))
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
            } else {
                try? line.write(to: url)
            }
        }
    }

    /// Test hook: block until pending writes land.
    func flush() {
        queue.sync {}
    }
}

/// No-op sink for previews and UI tests.
final class NullAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
}
