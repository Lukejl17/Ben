import SwiftUI

/// S1 — the handshake. Ben in person, once, at full size.
struct WelcomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(PendingEmailMonitor.self) private var pendingMonitor
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSignIn = false

    var body: some View {
        BenScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 70)

                BenCharacter(size: 190)
                    .padding(.bottom, 22)

                WelcomeGreetingReel()
                    .padding(.bottom, 14)

                BenVoiceText(
                    text: "Give me your bills and I'll tell you when they matter. First, watch me read one."
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 560)
        } cta: {
            BenPrimaryButton(title: "Watch Ben work") {
                services.analytics.track(.onboardingStarted)
                coordinator.advance(to: .demoScan)
            }
            Button {
                showSignIn = true
            } label: {
                Text("I already have an account")
                    .font(.benLabel)
                    .foregroundStyle(Color.forestInk.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(BenPressable())
            .accessibilityIdentifier("I already have an account")
        }
        .sheet(isPresented: $showSignIn) {
            SignInView { account in
                // Different Firebase user → wipe the previous owner's local bills.
                LocalAccountSession.bindAccount(
                    account,
                    modelContext: modelContext,
                    scheduler: services.scheduler,
                    pendingEmails: pendingMonitor,
                    assumeUnownedBillsAreForeign: true
                )
                hasCompletedOnboarding = true
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(OnboardingCoordinator())
        .tint(.chartreuse)
}
