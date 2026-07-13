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

/// S4/S5 — how the bill came in. Raw values feed analytics.
enum UploadMethod: String, Sendable {
    case photo
    case pdf
    case email
    case manual
    case sample
}
