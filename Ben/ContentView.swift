import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter

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
                TabView {
                    Tab("Bills", systemImage: "doc.text.fill") {
                        HomeView()
                    }
                    Tab("Insights", systemImage: "chart.pie.fill") {
                        InsightsView()
                    }
                    Tab("Settings", systemImage: "gearshape.fill") {
                        SettingsView()
                    }
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
        // UI-test hook for the dark-mode screenshot pass.
        .preferredColorScheme(
            ProcessInfo.processInfo.arguments.contains("-forceDark") ? .dark : nil
        )
    }
}

#Preview {
    ContentView()
        .environment(OnboardingCoordinator())
        .tint(.chartreuse)
}
