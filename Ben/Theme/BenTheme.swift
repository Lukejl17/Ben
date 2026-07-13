import SwiftUI

// MARK: - Ben Design System v1 · Warm Earthy
// Colour + type tokens only. Everything structural defers to stock SwiftUI / Liquid Glass.
// Rules: one accent per view · colour is state, not decoration · serif = Ben speaking · no reds.

extension Color {
    private static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Core palette
    static let benAccent        = dynamic(light: "3F6B52", dark: "7FA98E") // eucalyptus — the ONLY interactive colour
    static let benAccentDeep    = dynamic(light: "2F4A3A", dark: "A8C6B3") // pressed states, text on tint
    static let benCanvas        = dynamic(light: "F7F3EA", dark: "1C1B17") // sand page background
    static let benCard          = dynamic(light: "FFFFFF", dark: "26241F") // bill cards, sheets
    static let benHairline      = dynamic(light: "E3DCCB", dark: "3A372F") // borders, separators
    static let benInk           = dynamic(light: "2C2A23", dark: "F0EDE4") // primary text
    static let benInkSecondary  = dynamic(light: "6B6557", dark: "A8A294") // supporting text
    static let benInkMuted      = dynamic(light: "8A8271", dark: "7A7466") // placeholders, meta
    static let benClay          = dynamic(light: "C4744A", dark: "D08D66") // Ben's illustration ONLY — never controls

    // Bill status — tint + matching text (always same-family deep stop, never black on tint)
    static let statusUpcomingBg = dynamic(light: "EDEAE0", dark: "33302A")
    static let statusUpcomingFg = dynamic(light: "57534A", dark: "B5AF9F")
    static let statusDueSoonBg  = dynamic(light: "F3E4D4", dark: "3E2F1E")
    static let statusDueSoonFg  = dynamic(light: "7A4A23", dark: "D9A96F")
    static let statusPaidBg     = dynamic(light: "E4EEE6", dark: "243528")
    static let statusPaidFg     = dynamic(light: "2F4A3A", dark: "9DC3AA")
    static let statusOverdueBg  = dynamic(light: "EBD6CB", dark: "3F281E") // terracotta — serious, never red
    static let statusOverdueFg  = dynamic(light: "8A3B22", dark: "D98F6C")
}

// MARK: - Bill status

enum BillStatus: String, Codable {
    case upcoming, dueSoon, paid, overdue

    var label: String {
        switch self {
        case .upcoming: "Upcoming"
        case .dueSoon:  "Due soon"
        case .paid:     "Paid"
        case .overdue:  "Overdue"
        }
    }

    var background: Color {
        switch self {
        case .upcoming: .statusUpcomingBg
        case .dueSoon:  .statusDueSoonBg
        case .paid:     .statusPaidBg
        case .overdue:  .statusOverdueBg
        }
    }

    var foreground: Color {
        switch self {
        case .upcoming: .statusUpcomingFg
        case .dueSoon:  .statusDueSoonFg
        case .paid:     .statusPaidFg
        case .overdue:  .statusOverdueFg
        }
    }
}

// MARK: - Typography roles
// Dynamic Type everywhere — text styles, never fixed sizes. Test at xxxLarge.

extension Font {
    /// S1 welcome line, S8 set-state headline
    static let benPromise = Font.largeTitle.bold()
    /// Section headers, paywall pages
    static let benTitle = Font.title2.weight(.semibold)
    /// Every line Ben speaks — and nothing else, ever
    static let benVoice = Font.system(.body, design: .serif)
    /// Bill amounts — pair with .monospacedDigit() on the Text
    static let benAmount = Font.title3.weight(.semibold)
    /// General UI copy, trust block
    static let benBody = Font.body
    /// Field labels, status pills, buttons
    static let benLabel = Font.subheadline.weight(.medium)
    /// Due dates, captions, trial fine print — colour with benInkMuted
    static let benMeta = Font.footnote
}

// MARK: - Reusable atoms

/// The status capsule — the only situational colour in the app.
struct StatusPill: View {
    let status: BillStatus
    var body: some View {
        Text(status.label)
            .font(.benLabel)
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(status.background, in: Capsule())
    }
}

/// A line spoken by Ben. Serif signals who's talking before a word is read.
struct BenVoiceText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.benVoice)
            .foregroundStyle(Color.benInk)
    }
}

/// Card container: opaque content surface on the sand canvas.
/// Glass is for chrome, not data — amounts stay legible.
struct BenCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.benHairline, lineWidth: 0.5))
    }
}

// MARK: - App root usage
//
// @main struct BenApp: App {
//     var body: some Scene {
//         WindowGroup {
//             ContentView()
//                 .tint(.benAccent)                       // Liquid Glass chrome picks this up
//                 .background(Color.benCanvas)
//         }
//     }
// }

// MARK: - Hex helper

private extension UIColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: CGFloat((value & 0xFF0000) >> 16) / 255,
            green: CGFloat((value & 0x00FF00) >> 8) / 255,
            blue: CGFloat(value & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
