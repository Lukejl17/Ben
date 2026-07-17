import Foundation

/// Every echo and playback line in onboarding, in one place so the copy pass
/// stays easy. Pure functions of the answers — no view logic.
enum OnboardingCopy {
    // MARK: - Per-moment playback flavour

    static func momentMirror(_ moment: IntentContext) -> String {
        switch moment {
        case .justBoughtHome: "New house, new bills. Rates, water, insurance, all firsts."
        case .movedInTogether: "Two people, two inboxes, and bills falling in the gap."
        case .billsPilingUp: "The pile got on top of you. That ends today."
        case .gettingOrganised: "You want one tidy place for everything. Sensible."
        }
    }

    static func momentPlan(_ moment: IntentContext) -> String {
        switch moment {
        case .justBoughtHome:
            "I'll catch the first-time bills you've never had before. Rates, water, strata, nothing slips."
        case .movedInTogether:
            "One shared picture of every bill, whoever's name it's in. No more 'I thought you paid it'."
        case .billsPilingUp:
            "We'll clear the pile one photo at a time, and I'll take the watching from here."
        case .gettingOrganised:
            "Every bill in one place, categorised and exportable. Tidy enough to make your accountant smile."
        }
    }

    static func momentEmotion(_ moment: IntentContext) -> String {
        switch moment {
        case .justBoughtHome: "🤩"
        case .movedInTogether: "💚"
        case .billsPilingUp: "💪"
        case .gettingOrganised: "✨"
        }
    }

    // MARK: - Sources echo: one pick gets its line, several get the catch-all

    static func sourcesEcho(_ sources: Set<BillSource>) -> String? {
        guard let only = sources.first, sources.count == 1 else {
            return sources.isEmpty ? nil
                : "However they arrive, they all funnel into Ben: photo, PDF, or straight from the inbox."
        }
        return switch only {
        case .paper: "That drawer's retired. One photo and the paper's my problem."
        case .email: "Forward them straight in. Your inbox stops being a filing cabinet."
        case .apps: "One place instead of five apps. That's the whole point of me."
        case .partner: "Both of you see the same picture, whoever's name it's in."
        case .dog: "Snap them before the dog does. Photo, PDF or inbox, they all beat him."
        }
    }

    static func sourcesEmotion(_ sources: Set<BillSource>) -> String {
        guard let only = sources.first, sources.count == 1 else { return "⚡" }
        return switch only {
        case .paper: "📸"
        case .email: "📥"
        case .apps: "📱"
        case .partner: "💚"
        case .dog: "🐕"
        }
    }

    // MARK: - Volume echo

    static func volumeEcho(_ volume: BillVolume) -> String {
        switch volume {
        case .oneToThree: "Even 3 bills a month is 3 things you shouldn't have to remember."
        case .fourToSeven: "5-ish bills a month means something's due almost every week. No wonder it hums."
        case .eightToTwelve: "10 bills a month is a part-time job you never applied for."
        case .lostCount: "Step one: we'll count them. Step two: you stop counting forever."
        }
    }

    static func volumeEmotion(_ volume: BillVolume) -> String {
        volume == .lostCount ? "🤝" : "🧮"
    }

    // MARK: - Late fees echo

    static func lateFeesEcho(_ fees: LateFeeHistory) -> String {
        fees == .never
            ? "Then my job is keeping it that way, and taking the worrying off your plate too."
            : "Noted. My job is making that number $0 and keeping it there."
    }

    static func lateFeesEmotion(_ fees: LateFeeHistory) -> String {
        switch fees {
        case .never: "🛡️"
        case .once, .few: "🎯"
        case .ratherNot: "🤝"
        }
    }

    // MARK: - Feeling echo (also the mirror's voice line and the plan row)

    static func feelingEcho(_ feeling: BillFeeling) -> String {
        switch feeling {
        case .dread: "No more opening the banking app with one eye closed. You'll always know what's coming."
        case .load: "That background hum of 'wait, is something due?' That's the part I take off you."
        case .fights: "One shared source of truth. The 'did you pay it' conversation stops."
        case .mess: "Photos in, order out. You'll never file anything again."
        }
    }

    // MARK: - Reminder echo

    static func reminderEcho(_ style: ReminderStyle) -> String {
        "Locked in: \(style.label.lowercased()). And never otherwise."
    }

    // MARK: - Fee maths, reused on the paywall recap

    static func feeMaths(_ fees: LateFeeHistory?) -> (number: String, line: String) {
        switch fees {
        case .once: ("~$25", "one late fee a year, gone")
        case .few: ("~$100+", "a few late fees a year, gone")
        case .ratherNot: ("$0", "where late fees are heading")
        case .never, nil: ("$0", "late fees, staying right there")
        }
    }

    // MARK: - Stat screens

    static func oddsVoice(_ fees: LateFeeHistory?) -> String {
        fees == LateFeeHistory.never
            ? "You've dodged them so far. Let's make that permanent."
            : "You told me they've caught you before. That stops today."
    }

    static func mathsSub(_ volume: BillVolume) -> String {
        volume.isEstimate
            ? "a year at the average Aussie household, give or take"
            : "currently tracked by memory at your place"
    }

    static func mathsVoice(_ volume: BillVolume) -> String {
        volume.isEstimate
            ? "Sounds about right for lost count. We'll pin down your real number as bills land. Mine either way."
            : "From today: zero. I hold every one of them."
    }
}
