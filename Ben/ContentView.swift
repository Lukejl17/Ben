import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        // UI-test hook: a clean run every launch.
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }

    var body: some View {
        ZStack {
            Color.benCanvas.ignoresSafeArea()
            if hasCompletedOnboarding {
                HomeView()
            } else {
                OnboardingFlow()
            }
        }
    }
}

/// Placeholder — Phase 4 builds the real home screen.
struct HomeView: View {
    var body: some View {
        BenVoiceText(text: "Nothing needs your attention.")
    }
}

#Preview {
    ContentView()
        .environment(OnboardingCoordinator())
        .tint(.benAccent)
}
