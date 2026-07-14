import Foundation
import SwiftUI

/// The standard category set plus user-created customs. Customs are name-only —
/// Ben assigns a consistent wash so everything stays inside the palette.
enum BillCategory {
    static let standard = [
        "electricity", "gas", "internet", "phone", "water", "insurance",
        "council rates", "rent", "streaming", "subscriptions", "other"
    ]

    private static let customsKey = "customCategories"

    static func customs(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: customsKey) ?? []
    }

    /// Adds a custom category (trimmed, deduplicated against standards + customs).
    /// Returns the canonical stored name.
    @discardableResult
    static func addCustom(_ name: String, defaults: UserDefaults = .standard) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return "other" }
        var existing = customs(defaults: defaults)
        if standard.contains(cleaned) || existing.contains(cleaned) { return cleaned }
        existing.append(cleaned)
        defaults.set(existing, forKey: customsKey)
        return cleaned
    }

    static func all(defaults: UserDefaults = .standard) -> [String] {
        standard.dropLast() + customs(defaults: defaults) + ["other"]
    }

    // MARK: Styling

    private static let symbols: [String: String] = [
        "electricity": "bolt.fill",
        "gas": "flame.fill",
        "internet": "wifi",
        "phone": "iphone",
        "water": "drop.fill",
        "insurance": "shield.fill",
        "council rates": "building.columns.fill",
        "rent": "house.fill",
        "streaming": "play.tv.fill",
        "subscriptions": "arrow.trianglehead.2.clockwise.rotate.90",
        "other": "doc.text.fill"
    ]

    static func symbol(for category: String) -> String {
        symbols[category] ?? "tag.fill"  // customs get the tag
    }

    static func wash(for category: String) -> (bg: Color, fg: Color) {
        switch category {
        case "electricity", "gas": return (Color.washAmberBg, Color.washAmberFg)
        case "internet", "phone", "water": return (Color.washSkyBg, Color.washSkyFg)
        case "insurance", "rent": return (Color.washEucalyptusBg, Color.washEucalyptusFg)
        case "council rates", "streaming": return (Color.washClayBg, Color.washClayFg)
        case "other": return (Color.washEucalyptusBg, Color.washEucalyptusFg)
        default:
            // Customs: stable wash picked from the name itself.
            let washes: [(Color, Color)] = [
                (.washEucalyptusBg, .washEucalyptusFg), (.washAmberBg, .washAmberFg),
                (.washSkyBg, .washSkyFg), (.washClayBg, .washClayFg)
            ]
            let index = abs(category.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % washes.count
            return washes[index]
        }
    }

    /// Display casing: standards and customs are stored lowercase.
    static func label(for category: String) -> String {
        category.capitalized
    }
}
