import SwiftUI

/// S1 — one promise, one CTA. Ben introduces himself in his own voice.
struct WelcomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    var body: some View {
        BenScreen {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 120)

                BenAvatar(size: 44)
                    .padding(.bottom, 20)

                Text("G'day — I'm Ben.")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Color.benInk)
                    .padding(.bottom, 14)

                BenVoiceText(
                    text: "Give me your bills and I'll tell you when they matter. The rest of the time, you won't hear from me."
                )
                .foregroundStyle(Color.benInkSecondary)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 480)
        } cta: {
            BenPrimaryButton(title: "Set up my first bill") {
                services.analytics.track(.onboardingStarted)
                coordinator.advance(to: .intent)
            }
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(OnboardingCoordinator())
        .tint(.benAccent)
}
