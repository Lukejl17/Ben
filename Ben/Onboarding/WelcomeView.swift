import SwiftUI

/// S1 — one promise, one CTA. No signup, no carousel.
struct WelcomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(alignment: .top, spacing: 12) {
                BenAvatar()
                BenVoiceText(
                    text: "G'day — I'm Ben. Give me your bills and I'll tell you when they matter. "
                        + "The rest of the time, you won't hear from me."
                )
            }
            .padding(.horizontal, 24)
            Spacer()
            BenPrimaryButton(title: "Set up my first bill") {
                services.analytics.track(.onboardingStarted)
                coordinator.advance(to: .intent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(OnboardingCoordinator())
        .tint(.benAccent)
}
