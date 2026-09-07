import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(SubscriptionController.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
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
        .onAppear { syncLiveActivities() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncLiveActivities()
                Task { await subscriptions.refresh() }
            }
        }
        .onChange(of: notificationRouter.pendingLiveActivityBillID) { _, id in
            if id != nil { syncLiveActivities() }
        }
        .onChange(of: liveActivityFingerprint) { _, _ in
            syncLiveActivities()
        }
        // UI-test hook for the dark-mode screenshot pass.
        .preferredColorScheme(
            ProcessInfo.processInfo.arguments.contains("-forceDark") ? .dark : nil
        )
    }

    /// Bills, due dates, and paid state — anything that should move the Lock Screen.
    private var liveActivityFingerprint: String {
        bills.map { "\($0.uuid)-\($0.dueDate.timeIntervalSince1970)-\($0.paidAt == nil)" }
            .joined(separator: "|")
    }

    /// Lock Screen presence can't be scheduled ahead — start whenever the app is active.
    private func syncLiveActivities() {
        let snapshot = bills.map {
            BillLiveActivitySnapshot(
                billID: $0.uuid,
                issuer: $0.issuer,
                amount: $0.amount,
                dueDate: $0.dueDate,
                paidAt: $0.paidAt
            )
        }
        let pendingID = notificationRouter.pendingLiveActivityBillID
        Task { @MainActor in
            await LiveActivityManager.sync(bills: snapshot)
            if let pendingID, let bill = snapshot.first(where: { $0.billID == pendingID }) {
                if BillDueLiveActivityPolicy.shouldPresent(dueDate: bill.dueDate, paidAt: bill.paidAt) {
                    _ = await LiveActivityManager.start(
                        billID: bill.billID,
                        issuer: bill.issuer,
                        amount: bill.amount,
                        dueDate: bill.dueDate
                    )
                }
                notificationRouter.pendingLiveActivityBillID = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(OnboardingCoordinator())
        .environment(NotificationRouter())
        .environment(PendingEmailMonitor())
        .environment(SubscriptionController(service: StubSubscriptionService()))
        .modelContainer(for: Bill.self, inMemory: true)
        .tint(.chartreuse)
}
