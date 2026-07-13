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

#Preview {
    ContentView()
        .environment(OnboardingCoordinator())
        .tint(.benAccent)
}
