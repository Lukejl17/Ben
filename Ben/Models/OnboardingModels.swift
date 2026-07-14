import Foundation

/// S2 — life-stage context. Flavours later copy and S10 category suggestions.
enum IntentContext: String, CaseIterable, Codable, Sendable {
    case justBoughtHome = "just_bought_home"
    case movedInTogether = "moved_in_together"
    case billsPilingUp = "bills_piling_up"
    case gettingOrganised = "getting_organised"

    var label: String {
        switch self {
        case .justBoughtHome: "Just bought a home"
        case .movedInTogether: "Moved in with someone"
        case .billsPilingUp: "Bills piling up lately"
        case .gettingOrganised: "Just getting organised"
        }
    }
}

/// S3 — when Ben speaks up.
enum ReminderStyle: String, CaseIterable, Codable, Sendable {
    case fewDaysEarly = "few_days_early"
    case justBefore = "just_before"
    case both = "both"

    var label: String {
        switch self {
        case .fewDaysEarly: "A few days early"
        case .justBefore: "Just before it's due"
        case .both: "Both, for big bills"
        }
    }

    var detail: String {
        switch self {
        case .fewDaysEarly: "A heads-up three days out — time to sort it without rushing."
        case .justBefore: "One mention on the day it's due."
        case .both: "Three days out and again on the day."
        }
    }
}

/// S7b — how often Ben mentions a bill that has slipped past its due date.
/// Capped mention counts keep the constitution's "silence is a feature" promise.
enum OverdueCadence: String, CaseIterable, Codable, Sendable {
    case everyDay = "every_day"
    case everySecondDay = "every_second_day"
    case weekly = "weekly"
    case once = "once"

    static let storageKey = "overdueCadence"

    var label: String {
        switch self {
        case .everyDay: "Every day"
        case .everySecondDay: "Every second day"
        case .weekly: "Once a week"
        case .once: "Just the once"
        }
    }

    var detail: String {
        switch self {
        case .everyDay: "A daily mention until it's sorted — for the must-not-miss."
        case .everySecondDay: "Persistent without being a pest."
        case .weekly: "A gentle weekly check-in."
        case .once: "One mention the day after, then silence."
        }
    }

    /// Days between overdue mentions.
    var dayStep: Int {
        switch self {
        case .everyDay: 1
        case .everySecondDay: 2
        case .weekly: 7
        case .once: 1
        }
    }

    /// Hard cap on mentions — Ben never nags forever.
    var maxMentions: Int {
        switch self {
        case .everyDay: 7
        case .everySecondDay: 4
        case .weekly: 3
        case .once: 1
        }
    }
}

/// S4/S5 — how the bill came in. Raw values feed analytics.
enum UploadMethod: String, Sendable {
    case photo
    case pdf
    case email
    case manual
    case sample
}
