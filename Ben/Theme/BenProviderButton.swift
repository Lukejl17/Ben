import SwiftUI

/// Standard provider sign-in pill — cream face, dark type, official mark.
/// Matches the familiar Apple/Google shape users expect.
struct BenProviderButton: View {
    enum Provider {
        case apple, google
    }

    /// Full-width "Continue with…" for account create; compact side-by-side for login.
    enum Style {
        case full, compact
    }

    let provider: Provider
    var style: Style = .full
    let action: () -> Void

    private var title: String {
        switch (provider, style) {
        case (.apple, .full): "Continue with Apple"
        case (.google, .full): "Continue with Google"
        case (.apple, .compact): "Apple"
        case (.google, .compact): "Google"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: style == .compact ? 8 : 10) {
                mark
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.system(size: style == .compact ? 16 : 17, weight: .semibold))
            }
            .foregroundStyle(style == .compact ? Color.forestInk : Color.onCreamStrong)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
        }
        .buttonStyle(BenPressable())
        .accessibilityIdentifier(style == .full ? title : "Continue with \(title)")
    }

    private var fill: Color {
        style == .compact ? Color.cream.opacity(0.12) : Color.cream
    }

    private var stroke: Color {
        style == .compact ? Color.cream.opacity(0.22) : Color.onCream.opacity(0.12)
    }

    @ViewBuilder
    private var mark: some View {
        switch provider {
        case .apple:
            Image(systemName: "applelogo")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(style == .compact ? Color.forestInk : Color.onCreamStrong)
        case .google:
            GoogleMark()
        }
    }
}

/// The multicolour Google "G" — drawn, not an SF Symbol stand-in.
struct GoogleMark: View {
    var body: some View {
        Text("G")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(
                AngularGradient(
                    colors: [
                        Color.googleBlue, Color.googleGreen,
                        Color.googleYellow, Color.googleRed, Color.googleBlue
                    ],
                    center: .center
                )
            )
            .accessibilityHidden(true)
    }
}
