import SwiftUI
import UIKit

// MARK: - Ben Design System v3 · Forest Bold components
// Cream widgets float on the forest; secondary rows are translucent.
// Chartreuse is the only interactive colour.

// MARK: Surfaces

/// Cream widget — the star surface. Content inside renders in light scheme so
/// native controls (fields, pickers) stay dark-on-cream.
struct BenCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 28
    private let content: Content

    init(padding: CGFloat = 18, radius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.colorScheme, .light)
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cream, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .benShadow(.cream)
    }
}

/// Translucent forest row — the supporting surface for lists and options.
struct BenRowSurface: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(Color.rowFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.rowStroke, lineWidth: 1.5)
            )
    }
}

extension View {
    func benRowSurface(radius: CGFloat = 24) -> some View {
        modifier(BenRowSurface(radius: radius))
    }
}

// MARK: Atoms

/// The status capsule — the only situational colour in the app.
struct StatusPill: View {
    let status: BillStatus
    var body: some View {
        Text(status.label)
            .font(.benLabel)
            .foregroundStyle(status.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(status.background, in: Capsule())
    }
}

/// Status chip for CREAM surfaces — solid fills (the translucent StatusPill
/// disappears on cream).
struct StatusChipOnCream: View {
    let status: BillStatus

    var body: some View {
        let style: (Color, Color) = switch status {
        case .dueSoon: (.amber, .onAmber)
        case .overdue: (.clay, .onClay)
        case .paid: (.chartreuse, .onChartreuse)
        case .upcoming: (.lavender, .onLavender)
        }
        return Text(status.label)
            .font(.benLabel)
            .foregroundStyle(style.1)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(style.0, in: Capsule())
    }
}

/// A line spoken by Ben — soft cream, Baloo Medium. Never shouty.
struct BenVoiceText: View {
    let text: String
    var quiet = false
    var body: some View {
        Text(text)
            .font(quiet ? .benVoiceQuiet : .benVoice)
            .foregroundStyle(Color.forestInkSoft)
            .lineSpacing(3)
    }
}

/// Solid accent chip with an SF Symbol — where colour variety lives.
struct BenIconCircle: View {
    let systemName: String
    var fill: Color = .amber
    var iconColor: Color = .onAmber
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
    }
}

/// Standard sheet chrome: a close X pinned top-right so every sheet has an
/// obvious way out.
private struct BenSheetCloseModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            BenCircleButton(systemName: "xmark", accessibilityLabel: "Close") { dismiss() }
                .padding(.top, 16)
                .padding(.trailing, 20)
        }
    }
}

extension View {
    func benSheetClose() -> some View { modifier(BenSheetCloseModifier()) }

    /// Done above the keyboard / number pad — decimal pads have no return key.
    func benKeyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.benLabel)
                .foregroundStyle(Color.chartreuse)
            }
        }
    }
}

/// Widget eyebrow: tiny tracked uppercase label.
struct BenEyebrow: View {
    let text: String
    var color: Color = .onCreamEyebrow
    var body: some View {
        Text(text.uppercased())
            .font(.benEyebrow)
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

// MARK: Buttons

/// Primary CTA: chartreuse capsule with a soft glow.
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
            .foregroundStyle(Color.onChartreuse)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.chartreuse, in: Capsule())
        }
        .buttonStyle(BenPressable())
        .benShadow(.glow)
    }
}

/// Secondary: cream capsule.
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
            .foregroundStyle(Color.onCream)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.cream, in: Capsule())
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
    }
}

/// Tertiary: quiet chartreuse text link.
struct BenTextButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.onChartreuse)
                        .frame(width: 24, height: 24)
                        .background(Color.chartreuse, in: Circle())
                }
                Text(title)
                    .font(.benLabel)
                    .foregroundStyle(Color.chartreuse)
            }
        }
        .buttonStyle(BenPressable())
    }
}

/// Floating circular chrome action (close, toolbar) — translucent on forest.
struct BenCircleButton: View {
    let systemName: String
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.forestInk)
                .frame(width: 44, height: 44)
                .background(Color.rowFill, in: Circle())
                .overlay(Circle().strokeBorder(Color.rowStroke, lineWidth: 1.5))
        }
        .buttonStyle(BenPressable())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct BenPressable: ButtonStyle {
    /// Medium for CTAs / onboarding; light for browsing into bills and rows.
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle = .medium

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed else { return }
                UIImpactFeedbackGenerator(style: haptic).impactOccurred(intensity: 0.9)
            }
    }
}

// MARK: Selection row (S2/S3/S7/S7b pickers)

/// Unselected: translucent forest. Selected: cream, lifted, chartreuse check.
struct SelectablePill: View {
    let label: String
    var detail: String?
    var emoji: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let emoji {
                    Text(emoji).font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.benCardTitle)
                        .foregroundStyle(isSelected ? Color.onCream : Color.forestInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(.benMeta)
                            .foregroundStyle(
                                isSelected ? Color.onCreamMuted : Color.forestInk.opacity(0.6)
                            )
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? Color.onCreamStrong : Color.forestInk.opacity(0.35))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.cream : Color.rowFill,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.rowStroke, lineWidth: 1.5)
            )
        }
        .buttonStyle(BenPressable())
        .benShadow(isSelected ? .cream : .floating)
        .animation(.spring(duration: 0.3), value: isSelected)
        .accessibilityIdentifier(label)
    }
}

// MARK: Filled input field

/// Cream field: eyebrow label above the value. Light scheme inside.
struct BenField<Content: View>: View {
    let label: String
    private let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            BenEyebrow(text: label)
            content
                .font(.benBody)
                .foregroundStyle(Color.onCream)
        }
        .environment(\.colorScheme, .light)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .benShadow(.floating)
    }
}

// MARK: Screen scaffold

/// Standard screen: forest canvas, scrolling content, CTA pinned to bottom.
struct BenScreen<Content: View, CTA: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    @ViewBuilder var cta: CTA

    var body: some View {
        ZStack {
            BenCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let title {
                        Text(title)
                            .font(.benTitle)
                            .foregroundStyle(Color.chartreuse)
                            .padding(.top, 22)
                            .padding(.bottom, 2)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .benKeyboardDoneToolbar()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                cta
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background {
                LinearGradient(
                    colors: [Color.forestBottom.opacity(0), Color.forestBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}
