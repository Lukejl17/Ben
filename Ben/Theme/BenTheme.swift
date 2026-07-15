import SwiftUI

// MARK: - Ben Design System v3 · Forest Bold
// One committed world: deep forest ground, chartreuse display, cream widgets
// floating on top. Baloo 2 everywhere. Spec: docs/design-system.md +
// design-boards/home-board-01.html (direction B). Hex values live here only.

extension Color {
    private static func hex(_ value: String) -> Color {
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        return Color(
            red: Double((int & 0xFF0000) >> 16) / 255,
            green: Double((int & 0x00FF00) >> 8) / 255,
            blue: Double(int & 0x0000FF) / 255
        )
    }

    // Ground
    static let forestTop      = hex("25401C")
    static let forestBottom   = hex("1B3015")
    static let forestGlowWarm = hex("3E6B2E")   // radial glow, top-right
    static let forestGlowDeep = hex("173014")   // radial glow, bottom-left

    // Display + interactive
    static let chartreuse     = hex("D3E97A")   // THE accent: display type, CTAs, FAB
    static let onChartreuse   = hex("22361B")   // text/icons on chartreuse

    // Cream widgets
    static let cream          = hex("FAF3E3")
    static let onCream        = hex("293223")   // primary ink on cream
    static let onCreamStrong  = hex("2F4A26")   // hero amounts on cream
    static let onCreamEyebrow = hex("5E7A3A")   // eyebrow labels on cream
    static let onCreamMuted   = hex("6B6B57")   // secondary on cream

    // Text on forest
    static let forestInk      = hex("F8F1DE")   // primary on forest
    static let forestInkSoft  = hex("EFE8D2")   // Ben's voice
    // secondary on forest = forestInk.opacity(0.65); meta = 0.5

    // Accent chips (solid fills + their dark foregrounds)
    static let amber          = hex("E9A13B")
    static let onAmber        = hex("2A2A20")
    static let sky            = hex("9CC0CF")
    static let onSky          = hex("1E3540")
    static let lavender       = hex("E7CFF2")
    static let onLavender     = hex("4A2F5E")
    static let clay           = hex("D08D66")
    static let onClay         = hex("3B2415")

    // Status pills (on forest rows)
    static let statusWarnBg   = hex("E9A13B").opacity(0.20)
    static let statusWarnFg   = hex("F0C27E")
    static let statusCalmBg   = hex("F8F1DE").opacity(0.13)
    static let statusCalmFg   = hex("E7E0C8")
    static let statusPaidBg   = hex("D3E97A").opacity(0.15)
    static let statusPaidFg   = hex("D3E97A")
    static let statusLateBg   = hex("C4744A").opacity(0.25)  // terracotta, never red
    static let statusLateFg   = hex("E8A98A")

    // Translucent forest surfaces (rows, secondary widgets)
    static let rowFill        = hex("F8F1DE").opacity(0.07)
    static let rowStroke      = hex("F8F1DE").opacity(0.15)
}

// MARK: - Canvas

/// The forest ground with its two glows. Every screen sits on this — never flat.
struct BenCanvas: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.forestTop, .forestBottom],
                startPoint: UnitPoint(x: 0.35, y: 0),
                endPoint: UnitPoint(x: 0.65, y: 1)
            )
            RadialGradient(
                colors: [Color.forestGlowWarm.opacity(0.55), .clear],
                center: UnitPoint(x: 0.85, y: -0.1),
                startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [Color.forestGlowDeep.opacity(0.55), .clear],
                center: UnitPoint(x: -0.1, y: 1.1),
                startRadius: 0, endRadius: 420
            )
        }
        .ignoresSafeArea()
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
        case .upcoming: .statusCalmBg
        case .dueSoon:  .statusWarnBg
        case .paid:     .statusPaidBg
        case .overdue:  .statusLateBg
        }
    }

    var foreground: Color {
        switch self {
        case .upcoming: .statusCalmFg
        case .dueSoon:  .statusWarnFg
        case .paid:     .statusPaidFg
        case .overdue:  .statusLateFg
        }
    }
}

// MARK: - Typography · Baloo 2 (bundled variable font, named instances)

extension Font {
    static func baloo(_ instance: String, _ size: CGFloat, relativeTo style: TextStyle) -> Font {
        .custom(instance, size: size, relativeTo: style)
    }

    /// Screen titles — chartreuse by convention
    static let benTitle = baloo("Baloo2-ExtraBold", 32, relativeTo: .largeTitle)
    /// Hero amounts on cream widgets
    static let benHeroAmount = baloo("Baloo2-ExtraBold", 46, relativeTo: .largeTitle)
    /// Ben's voice — cream, warm, never shouty
    static let benVoice = baloo("Baloo2-Medium", 18, relativeTo: .title3)
    static let benVoiceQuiet = baloo("Baloo2-Medium", 16, relativeTo: .body)
    /// Card/row titles
    static let benCardTitle = baloo("Baloo2-Bold", 17, relativeTo: .headline)
    /// Amounts in rows
    static let benAmount = baloo("Baloo2-Bold", 17, relativeTo: .title3)
    static let benBody = baloo("Baloo2-Medium", 16, relativeTo: .body)
    /// Buttons, chips, field labels
    static let benLabel = baloo("Baloo2-Bold", 15, relativeTo: .subheadline)
    /// Meta, captions
    static let benMeta = baloo("Baloo2-Medium", 13, relativeTo: .footnote)
    /// Tiny eyebrow labels on widgets (pair with tracking + uppercase)
    static let benEyebrow = baloo("Baloo2-Bold", 11, relativeTo: .caption)
}

// MARK: - Elevation
// On the dark ground, borders and fill contrast do most of the separating;
// shadows are reserved for cream surfaces and floating chrome.

enum BenElevation {
    case cream, floating, glow

    var color: Color {
        switch self {
        case .cream, .floating: Color.black.opacity(0.35)
        case .glow: Color.chartreuse.opacity(0.30)
        }
    }

    var radius: CGFloat {
        switch self {
        case .cream: 22
        case .floating: 18
        case .glow: 24
        }
    }

    var y: CGFloat {
        switch self {
        case .cream: 12
        case .floating: 8
        case .glow: 6
        }
    }
}

extension View {
    func benShadow(_ level: BenElevation) -> some View {
        shadow(color: level.color, radius: level.radius, y: level.y)
    }
}

// MARK: - The character
// Guest, not resident: welcome, working states, empty states, B2 apology.
// The artwork breaks its own lime disc (hat + thumb) — NEVER circle-mask it.

struct BenCharacter: View {
    var size: CGFloat = 120

    var body: some View {
        Image("BenCharacter")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Ben")
    }
}
