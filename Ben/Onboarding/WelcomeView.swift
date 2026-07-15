import SwiftUI

/// S1 — the handshake. Ben in person, once, at full size.
struct WelcomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    var body: some View {
        BenScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 70)

                BenCharacter(size: 190)
                    .padding(.bottom, 22)

                Text("G'day —\nI'm Ben.")
                    .font(.baloo("Baloo2-ExtraBold", 44, relativeTo: .largeTitle))
                    .foregroundStyle(Color.chartreuse)
                    .multilineTextAlignment(.center)
                    .lineSpacing(0)
                    .padding(.bottom, 14)

                BenVoiceText(
                    text: "Give me your bills and I'll tell you when they matter. The rest of the time, you won't hear from me."
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 560)
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
        .tint(.chartreuse)
}
