import SwiftUI

/// S8 placeholder — replaced in Phase 4.
struct SetStateView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            BenVoiceText(text: "Done. That one's my problem now.")
            Spacer()
            BenPrimaryButton(title: "Continue") {
                coordinator.advance(to: .paywall)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

/// S9 placeholder — replaced in Phase 4.
struct PaywallView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Paywall")
                .font(.benTitle)
            Spacer()
            BenPrimaryButton(title: "Continue") {
                coordinator.advance(to: .secondBill)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

/// S10 placeholder — replaced in Phase 4.
struct SecondBillView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Second bill bridge")
                .font(.benTitle)
            Spacer()
            BenPrimaryButton(title: "Finish") {
                hasCompletedOnboarding = true
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
