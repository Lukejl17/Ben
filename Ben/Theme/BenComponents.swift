import SwiftUI

// MARK: - Ben Design System v2 · Reusable components
// Atoms, buttons, selection rows, fields, and the screen scaffold.

// MARK: - Atoms

/// The status capsule — the only situational colour in the app.
struct StatusPill: View {
    let status: BillStatus
    var body: some View {
        Text(status.label)
            .font(.benLabel)
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(status.background, in: Capsule())
    }
}

/// A line spoken by Ben. Serif signals who's talking before a word is read.
struct BenVoiceText: View {
    let text: String
    var quiet = false
    var body: some View {
        Text(text)
            .font(quiet ? .benVoiceQuiet : .benVoice)
            .foregroundStyle(Color.benInk)
            .lineSpacing(3)
    }
}

/// Opaque floating surface. Elevation, not borders (hairline only in dark).
struct BenCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 18
    private let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.benHairline, lineWidth: 0.5)
                }
            }
            .benShadow(.card)
    }
}

/// Icon in a pastel tinted circle — where colour variety lives.
struct BenIconCircle: View {
    let systemName: String
    var wash: (bg: Color, fg: Color) = (.washEucalyptusBg, .washEucalyptusFg)
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(wash.fg)
            .frame(width: size, height: size)
            .background(wash.bg, in: Circle())
    }
}

/// Ben's placeholder avatar. HUMAN: replace with the final illustration
/// (clay + ink palette, one calm expression). Never above 44pt, never floating.
struct BenAvatar: View {
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: size * 0.6, weight: .regular))
            .foregroundStyle(Color.washClayFg)
            .frame(width: size, height: size)
            .background(Color.washClayBg, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// Primary CTA: 56pt accent-gradient capsule with soft shadow.
struct BenPrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.benLabel)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.benAccent, .benAccentDeep],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
    }
}

/// Secondary: eucalyptus wash capsule.
struct BenSecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.benLabel)
            .foregroundStyle(Color.washEucalyptusFg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.washEucalyptusBg, in: Capsule())
        }
        .buttonStyle(BenPressable())
    }
}

/// Tertiary: quiet text link with a small accent circle (Unscripted "Add item").
struct BenTextButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.benAccent, in: Circle())
                }
                Text(title)
                    .font(.benLabel)
                    .foregroundStyle(Color.benAccent)
            }
        }
        .buttonStyle(BenPressable())
    }
}

/// Floating circular chrome action (back, close, toolbar).
struct BenCircleButton: View {
    let systemName: String
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.benInk)
                .frame(width: 44, height: 44)
                .background(Color.benCard, in: Circle())
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct BenPressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - Selection row (S2/S3/S7 pickers)

/// Filled selectable row: wash tint + accent ring when chosen, e1 card otherwise.
struct SelectablePill: View {
    let label: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.benLabel)
                        .foregroundStyle(Color.benInk)
                    if let detail {
                        Text(detail)
                            .font(.benMeta)
                            .foregroundStyle(Color.benInkSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.benAccent : Color.benInkMuted.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.washEucalyptusBg : Color.benCard,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.benAccent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(BenPressable())
        .benShadow(.card)
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

// MARK: - Filled input field

/// Unscripted-style filled field: accent-toned label above the value, no borders.
struct BenField<Content: View>: View {
    let label: String
    private let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.benMeta.weight(.medium))
                .foregroundStyle(Color.benAccent)
            content
                .font(.benBody)
                .foregroundStyle(Color.benInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.benCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .benShadow(.card)
    }
}

// MARK: - Screen scaffold

/// Standard screen: atmospheric canvas, scrolling content, CTA pinned to bottom.
struct BenScreen<Content: View, CTA: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    @ViewBuilder var cta: CTA

    var body: some View {
        ZStack {
            BenCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let title {
                        Text(title)
                            .font(.benTitle)
                            .foregroundStyle(Color.benInk)
                            .padding(.top, 24)
                            .padding(.bottom, 4)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                cta
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background {
                LinearGradient(
                    colors: [Color.benCanvasBottom.opacity(0), Color.benCanvasBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}
