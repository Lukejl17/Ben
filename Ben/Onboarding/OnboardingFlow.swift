import SwiftUI

/// Container switching between onboarding steps. Springs, not theatrics.
struct OnboardingFlow: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            BenCanvas()
            Group {
                switch coordinator.step {
                case .welcome: WelcomeView()
                case .intent: IntentView()
                case .reminderStyle: ReminderStyleView()
                case .upload: UploadBillView()
                case .capture: CaptureExtractView()
                case .manualEntry: ManualEntryView()
                case .confirm: ConfirmBillView()
                case .reminderSetup: ReminderSetupView()
                case .setState: SetStateView()
                case .paywall: PaywallView()
                case .secondBill: SecondBillView()
                case .done: Color.clear
                }
            }
            .transition(.opacity)
        }
        .animation(.spring(duration: 0.35), value: coordinator.step)
    }
}
