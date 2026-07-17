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
                case .demoScan: DemoScanView()
                case .intent: IntentView()
                case .sources: SourcesView()
                case .volume: VolumeView()
                case .statMaths: StatMathsView()
                case .lateFees: LateFeesView()
                case .feeling: FeelingView()
                case .mirror: MirrorView()
                case .statOdds: StatOddsView()
                case .reminderStyle: ReminderStyleView()
                case .plan: PlanView()
                case .commit: CommitView()
                case .upload: UploadBillView()
                case .capture: CaptureExtractView()
                case .manualEntry: ManualEntryView()
                case .confirm: ConfirmBillView()
                case .reminderSetup: ReminderSetupView()
                case .overdueStyle: OverdueStyleView()
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
