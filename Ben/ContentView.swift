import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(SubscriptionController.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    init() {
        // UI-test hook: a clean run every launch.
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }

    var body: some View {
        ZStack {
            BenCanvas()
            if hasCompletedOnboarding {
                if !subscriptions.hasResolved {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.chartreuse)
                } else if subscriptions.isEntitled {
                    TabView(selection: $selectedTab) {
                        Tab("Bills", systemImage: "doc.text.fill", value: 0) {
                            HomeView()
                        }
                        Tab("Insights", systemImage: "chart.pie.fill", value: 1) {
                            InsightsView()
                        }
                        Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                            SettingsView()
                        }
                    }
                    .onChange(of: notificationRouter.confirmEmailBillRequested) { _, requested in
                        // The confirm sheet lives on the Bills tab — land there first.
                        if requested { selectedTab = 0 }
                    }
                    .onAppear {
                        // Signing back in after a sign-out starts on Bills, not
                        // wherever Settings left the tab bar.
                        selectedTab = 0
                    }
                } else {
                    PaywallView(mode: .gate)
                }
            } else {
                OnboardingFlow()
            }
        }
        .onChange(of: notificationRouter.resumeUploadRequested) { _, requested in
            // B1: "remind me tonight" tap resumes onboarding at the ask.
            guard requested, !hasCompletedOnboarding else { return }
            notificationRouter.resumeUploadRequested = false
            coordinator.advance(to: .upload)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await subscriptions.refresh() }
            }
        }
        // UI-test hook for the dark-mode screenshot pass.
        .preferredColorScheme(
            ProcessInfo.processInfo.arguments.contains("-forceDark") ? .dark : nil
        )
    }
}

#Preview {
    ContentView()
        .environment(OnboardingCoordinator())
        .environment(NotificationRouter())
        .environment(PendingEmailMonitor())
        .environment(SubscriptionController(service: StubSubscriptionService()))
        .tint(.chartreuse)
}
