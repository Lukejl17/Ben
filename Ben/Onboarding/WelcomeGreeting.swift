import Foundation

/// Locale-aware hello for S1 only. Ben stays Australian everywhere else —
/// this is a one-beat wink keyed off device region, not language.
enum WelcomeGreeting {
    static let brand = "G'day"

    /// Region code (ISO 3166-1 alpha-2) → greeting word without comma.
    static let byRegion: [String: String] = [
        "AU": "G'day",
        "NZ": "Kia ora",
        "US": "Howdy",
        "CA": "Oh hey bud",
        "GB": "Alright",
        "IE": "Howaya",
        "FR": "Bonjour",
        "ES": "Hola",
        "DE": "Hallo",
        "IT": "Ciao",
        "PT": "Olá",
        "BR": "Olá",
        "NL": "Hoi",
        "JP": "Konnichiwa",
        "KR": "Annyeong"
    ]

    /// Unique greeting words used to size the reel and build distractors.
    static var allWords: [String] {
        Array(Set(byRegion.values)).sorted()
    }

    static func word(forRegionCode code: String?) -> String {
        guard let code, !code.isEmpty else { return brand }
        return byRegion[code.uppercased()] ?? brand
    }

    static func word(locale: Locale = .current) -> String {
        word(forRegionCode: locale.region?.identifier)
    }

    /// Display form with the trailing comma attached (flips with the word).
    static func display(_ word: String) -> String {
        "\(word),"
    }

    /// Vertical strip for the wheel: brand → shuffled distractors → landing word.
    /// Pass a seeded generator in tests for a stable sequence.
    static func reelStrip(
        landingOn targetWord: String,
        distractorCount: Int = 10,
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        let brandDisplay = display(brand)
        let targetDisplay = display(targetWord)
        var pool = allWords
            .filter { $0 != targetWord }
            .map(display)
            .shuffled(using: &generator)

        if pool.isEmpty {
            return [brandDisplay, targetDisplay]
        }

        var mid: [String] = []
        while mid.count < distractorCount {
            mid.append(contentsOf: pool.shuffled(using: &generator))
        }
        mid = Array(mid.prefix(distractorCount))

        if mid.first == brandDisplay, let swap = pool.first(where: { $0 != brandDisplay }) {
            mid[0] = swap
        }
        if mid.last == targetDisplay, let swap = pool.first(where: { $0 != targetDisplay }) {
            mid[mid.count - 1] = swap
        }

        if targetWord == brand {
            return [brandDisplay] + Array(mid.prefix(8)) + [brandDisplay]
        }
        return [brandDisplay] + mid + [targetDisplay]
    }

    static func reelStrip(landingOn targetWord: String, distractorCount: Int = 10) -> [String] {
        var rng = SystemRandomNumberGenerator()
        return reelStrip(landingOn: targetWord, distractorCount: distractorCount, using: &rng)
    }
}
