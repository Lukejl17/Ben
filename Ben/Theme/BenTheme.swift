import SwiftUI

// MARK: - Ben Design System v2 · Warm Earthy, Tactile
// Soft atmospheric canvas · elevation instead of borders · capsules · one accent.
// Full spec: docs/design-system.md. Hex values live here and nowhere else.

extension Color {
    private static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Core palette
    static let benAccent        = dynamic(light: "3F6B52", dark: "7FA98E") // eucalyptus — the ONLY interactive colour
    static let benAccentDeep    = dynamic(light: "2F4A3A", dark: "5E8A70") // gradient stop, pressed states
    static let benCard          = dynamic(light: "FFFFFF", dark: "26241F") // floating surfaces
    static let benField         = dynamic(light: "F1EEE6", dark: "2E2B25") // filled inputs
    static let benHairline      = dynamic(light: "E3DCCB", dark: "3A372F") // dark-mode-only card edge
    static let benInk           = dynamic(light: "2C2A23", dark: "F0EDE4")
    static let benInkSecondary  = dynamic(light: "6B6557", dark: "A8A294")
    static let benInkMuted      = dynamic(light: "8A8271", dark: "7A7466")
    static let benClay          = dynamic(light: "C4744A", dark: "D08D66") // Ben's illustration ONLY

    // Canvas gradient stops
    static let benCanvasTop     = dynamic(light: "EEF2F7", dark: "191C1E")
    static let benCanvasMid     = dynamic(light: "F7F3EA", dark: "1C1B17")
    static let benCanvasBottom  = dynamic(light: "EDF2EA", dark: "1A211C")
    /// Flat approximation where a solid is needed (sheet backgrounds).
    static let benCanvas        = dynamic(light: "F7F3EA", dark: "1C1B17")

    // Icon-circle washes (bg) + matching deep foregrounds
    static let washEucalyptusBg = dynamic(light: "E4EEE6", dark: "243528")
    static let washEucalyptusFg = dynamic(light: "2F4A3A", dark: "9DC3AA")
    static let washAmberBg      = dynamic(light: "F6ECD4", dark: "3E3520")
    static let washAmberFg      = dynamic(light: "6E5A24", dark: "D9C27A")
    static let washSkyBg        = dynamic(light: "E1EBF0", dark: "20313A")
    static let washSkyFg        = dynamic(light: "33525F", dark: "9CC0CF")
    static let washClayBg       = dynamic(light: "F3E0D5", dark: "3B2A20")
    static let washClayFg       = dynamic(light: "8A4A2B", dark: "D8A17E")

    // Bill status — tint + matching deep text
    static let statusUpcomingBg = dynamic(light: "EDEAE0", dark: "33302A")
    static let statusUpcomingFg = dynamic(light: "57534A", dark: "B5AF9F")
    static let statusDueSoonBg  = dynamic(light: "F3E4D4", dark: "3E2F1E")
    static let statusDueSoonFg  = dynamic(light: "7A4A23", dark: "D9A96F")
    static let statusPaidBg     = dynamic(light: "E4EEE6", dark: "243528")
    static let statusPaidFg     = dynamic(light: "2F4A3A", dark: "9DC3AA")
    static let statusOverdueBg  = dynamic(light: "EBD6CB", dark: "3F281E") // terracotta, never red
    static let statusOverdueFg  = dynamic(light: "8A3B22", dark: "D98F6C")
}

// MARK: - Canvas

/// The atmospheric background every screen sits on. Never flat.
struct BenCanvas: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .benCanvasTop, location: 0),
                .init(color: .benCanvasMid, location: 0.45),
                .init(color: .benCanvasBottom, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Elevation

enum BenElevation {
    case card, floating, overlay

    var opacity: Double {
        switch self {
        case .card: 0.06
        case .floating: 0.10
        case .overlay: 0.14
        }
    }

    var radius: CGFloat {
        switch self {
        case .card: 16
        case .floating: 20
        case .overlay: 28
        }
    }

    var y: CGFloat {
        switch self {
        case .card: 6
        case .floating: 8
        case .overlay: 10
        }
    }
}

private struct BenShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let level: BenElevation

    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(scheme == .dark ? level.opacity / 2 : level.opacity),
            radius: level.radius,
            y: level.y
        )
    }
}

extension View {
    func benShadow(_ level: BenElevation) -> some View {
        modifier(BenShadow(level: level))
    }
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

extension Font {
    /// Screen titles
    static let benTitle = Font.largeTitle.bold()
    /// Hero amounts — pair with .monospacedDigit()
    static let benHeroAmount = Font.system(size: 44, weight: .bold, design: .serif)
    /// Every line Ben speaks — and nothing else, ever
    static let benVoice = Font.system(.title3, design: .serif)
    /// Smaller Ben asides
    static let benVoiceQuiet = Font.system(.body, design: .serif)
    /// Card titles
    static let benCardTitle = Font.headline
    /// Bill amounts in rows
    static let benAmount = Font.title3.weight(.semibold)
    static let benBody = Font.body
    /// Buttons, chips, field labels
    static let benLabel = Font.subheadline.weight(.semibold)
    /// Meta, captions — colour with benInkMuted
    static let benMeta = Font.footnote
}

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
