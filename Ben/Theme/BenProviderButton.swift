import SwiftUI

/// Standard provider sign-in pill — cream face, dark type, official mark.
/// Matches the familiar Apple/Google shape users expect.
struct BenProviderButton: View {
    enum Provider {
        case apple, google
    }

    let provider: Provider
    let action: () -> Void

    private var title: String {
        switch provider {
        case .apple: "Continue with Apple"
        case .google: "Continue with Google"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                mark
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Color.onCreamStrong)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.cream, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.onCream.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(BenPressable())
        .accessibilityIdentifier(title)
    }

    @ViewBuilder
    private var mark: some View {
        switch provider {
        case .apple:
            Image(systemName: "applelogo")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.onCreamStrong)
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
