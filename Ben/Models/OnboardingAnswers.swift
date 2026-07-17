import Foundation

/// Where bills currently end up. Multi-select; each maps to a capture pitch.
enum BillSource: String, CaseIterable, Codable, Sendable {
    case paper
    case email
    case apps
    case partner
    case dog

    var label: String {
        switch self {
        case .paper: "Paper, in a drawer somewhere"
        case .email: "Buried in my email"
        case .apps: "Scattered across apps"
        case .partner: "My partner handles some"
        case .dog: "The dog eats them"
        }
    }

    var emoji: String {
        switch self {
        case .paper: "📄"
        case .email: "📧"
        case .apps: "📱"
        case .partner: "👥"
        case .dog: "🐕"
        }
    }
}

/// How many bills land each month. Powers the yearly maths beat.
enum BillVolume: String, CaseIterable, Codable, Sendable {
    case oneToThree = "1_3"
    case fourToSeven = "4_7"
    case eightToTwelve = "8_12"
    case lostCount = "lost_count"

    var label: String {
        switch self {
        case .oneToThree: "1–3"
        case .fourToSeven: "4–7"
        case .eightToTwelve: "8–12"
        case .lostCount: "Honestly? Lost count"
        }
    }

    var detail: String {
        switch self {
        case .oneToThree: "Just the basics"
        case .fourToSeven: "A regular household"
        case .eightToTwelve: "A busy one"
        case .lostCount: "That's exactly why Ben exists"
        }
    }

    /// Monthly midpoint multiplied out to a year. Lost count assumes the
    /// average household, roughly 8 a month.
    var dueDatesPerYear: Int {
        switch self {
        case .oneToThree: 24
        case .fourToSeven: 66
        case .eightToTwelve: 120
        case .lostCount: 100
        }
    }

    /// Lost count shows "100+" — an assumption, not their answer.
    var isEstimate: Bool { self == .lostCount }
}

/// Late fees in the last year. The money question.
enum LateFeeHistory: String, CaseIterable, Codable, Sendable {
    case never
    case once
    case few
    case ratherNot = "rather_not"

    var label: String {
        switch self {
        case .never: "Never"
        case .once: "Once"
        case .few: "A few times"
        case .ratherNot: "Rather not think about it"
        }
    }

    var detail: String {
        switch self {
        case .never: "But the worrying is work too"
        case .once: "~$25 you didn't need to spend"
        case .few: "That adds up fast"
        case .ratherNot: "Fair. Ben will."
        }
    }
}

/// What bill stress feels like. Quoted back at the mirror and the paywall.
enum BillFeeling: String, CaseIterable, Codable, Sendable {
    case dread
    case load
    case fights
    case mess

    var label: String {
        switch self {
        case .dread: "Due-date dread"
        case .load: "It's always in the back of my mind"
        case .fights: "It causes arguments at home"
        case .mess: "It's just… messy"
        }
    }

    var emoji: String {
        switch self {
        case .dread: "😰"
        case .load: "🧠"
        case .fights: "⚡"
        case .mess: "🌀"
        }
    }
}

/// Everything the interview collects, persisted as user attributes so it can
/// be passed to the analytics backend later. // HUMAN: map to PostHog person
/// properties once PostHog is wired up.
struct OnboardingAttributes {
    static let storageKey = "onboardingAttributes"

    /// Everything the interview knows at any point in the flow.
    struct Snapshot {
        var moment: IntentContext?
        var sources: Set<BillSource> = []
        var volume: BillVolume?
        var lateFees: LateFeeHistory?
        var feeling: BillFeeling?
        var reminderStyle: ReminderStyle?
        var committed = false
    }

    /// Persists the interview answers as a flat string dictionary.
    static func save(_ snapshot: Snapshot, defaults: UserDefaults = .standard) {
        var attrs: [String: String] = [:]
        if let moment = snapshot.moment { attrs["moment"] = moment.rawValue }
        if !snapshot.sources.isEmpty {
            attrs["bill_sources"] = snapshot.sources.map(\.rawValue).sorted().joined(separator: ",")
        }
        if let volume = snapshot.volume { attrs["bills_per_month"] = volume.rawValue }
        if let lateFees = snapshot.lateFees { attrs["late_fees"] = lateFees.rawValue }
        if let feeling = snapshot.feeling { attrs["bill_feeling"] = feeling.rawValue }
        if let style = snapshot.reminderStyle { attrs["reminder_style"] = style.rawValue }
        attrs["commitment_made"] = snapshot.committed ? "true" : "false"
        defaults.set(attrs, forKey: storageKey)
    }

    static func load(defaults: UserDefaults = .standard) -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}
