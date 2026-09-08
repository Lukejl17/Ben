import SwiftUI

/// S15 — the paywall, flow F from the lab: outcome, gift + bell, trial rail,
/// late fees vs Ben, then the offer. Hard paywall: the only way past without
/// a trial or subscription is leaving the app.
struct PaywallView: View {
    enum Mode {
        /// First run, inside onboarding — success continues to the second-bill bridge.
        case onboarding
        /// Returning user with no entitlement — success unlocks home.
        case gate
    }

    enum Page: Int, CaseIterable {
        case outcome, gift, rail, compare, offer, plans

        var previous: Page? {
            switch self {
            case .outcome: nil
            case .gift: .outcome
            case .rail: .gift
            case .compare: .rail
            case .offer: .compare
            case .plans: .offer
            }
        }
    }

    var mode: Mode = .onboarding

    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(SubscriptionController.self) private var subscriptions
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page: Page
    @State private var trackedPages: Set<Int> = []
    @State private var abandonmentTracked = false
    @State private var purchaseError: String?

    init(mode: Mode = .onboarding) {
        self.mode = mode
        _page = State(initialValue: mode == .gate ? .offer : .outcome)
    }

    var body: some View {
        ZStack {
            BenCanvas()
            Group {
                switch page {
                case .outcome: outcomePage
                case .gift: GiftBellView { advance(to: .rail) }
                case .rail: TrialRailView { advance(to: .compare) }
                case .compare: FeeCompareView { advance(to: .offer) }
                case .offer:
                    PaywallOfferView(
                        onStart: { Task { await purchase(.annual) } },
                        onOtherPlans: { advance(to: .plans) },
                        isBusy: subscriptions.isBusy,
                        errorLine: purchaseError,
                        onRestore: { Task { await restore() } },
                        pricing: subscriptions.pricing
                    )
                case .plans:
                    PaywallPlansView(
                        onPurchase: { plan in Task { await purchase(plan) } },
                        onBack: { advance(to: .offer) },
                        isBusy: subscriptions.isBusy,
                        errorLine: purchaseError,
                        onRestore: { Task { await restore() } },
                        pricing: subscriptions.pricing
                    )
                }
            }
            .transition(.opacity)
        }
        .animation(.spring(duration: 0.35), value: page)
        .onAppear {
            trackPage(page)
            syncBackInterceptor(for: page)
        }
        .onChange(of: page) { _, newPage in
            trackPage(newPage)
            syncBackInterceptor(for: newPage)
        }
        .onDisappear { coordinator.backInterceptor = nil }
        .task { await subscriptions.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && !abandonmentTracked
                && !subscriptions.isEntitled {
                abandonmentTracked = true
                services.analytics.track(.trialAbandonedAtPaywall)
            }
        }
    }

    // MARK: Page 1 — the outcome, kept

    private var outcomePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Never get surprised by a bill again. And never hear from Ben otherwise.")
                .font(.baloo("Baloo2-ExtraBold", 36, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .lineSpacing(2)
            Text("Every bill tracked, one calm reminder when it matters, silence the rest of the time.")
                .font(.benBody)
                .foregroundStyle(Color.forestInk.opacity(0.65))
            Spacer()
            Spacer()
            PaywallDots(current: 0)
                .frame(maxWidth: .infinity)
            BenPrimaryButton(title: "Continue") { advance(to: .gift) }
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func advance(to next: Page) {
        withAnimation(.spring(duration: 0.35)) { page = next }
    }

    private func syncBackInterceptor(for current: Page) {
        coordinator.backInterceptor = {
            guard mode == .onboarding, let previous = current.previous else { return false }
            withAnimation(.spring(duration: 0.35)) { page = previous }
            return true
        }
    }

    private func trackPage(_ page: Page) {
        guard !trackedPages.contains(page.rawValue) else { return }
        trackedPages.insert(page.rawValue)
        services.analytics.track(.paywallViewed(pageDepth: page.rawValue + 1))
    }

    private func purchase(_ plan: SubscriptionPlan) async {
        purchaseError = nil
        subscriptions.rememberPreChargeReminder(daysBeforeEnd: 2)
        if let userID = services.accounts.account?.id {
            await subscriptions.identify(userID: userID)
        }
        do {
            let outcome = try await subscriptions.purchase(plan)
            guard outcome == .entitled else { return }
            if plan == .annual, subscriptions.pricing.annualHasIntro {
                services.analytics.track(.trialStarted)
            }
            finishIfEntitled()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func restore() async {
        purchaseError = nil
        do {
            let outcome = try await subscriptions.restore()
            guard outcome == .entitled else { return }
            finishIfEntitled()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func finishIfEntitled() {
        guard subscriptions.isEntitled else { return }
        if mode == .onboarding, !hasCompletedOnboarding {
            coordinator.advance(to: .secondBill)
        }
    }
}

/// The little page indicator: five steps to the offer.
struct PaywallDots: View {
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.chartreuse : Color.forestInk.opacity(0.18))
                    .frame(width: index == current ? 22 : 7, height: 7)
            }
        }
    }
}

#Preview {
    PaywallView(mode: .onboarding)
        .environment(OnboardingCoordinator())
        .environment(SubscriptionController(service: StubSubscriptionService()))
        .environment(\.services, AppServices.fromLaunchArguments(["-freshTrial", "-stubAccount"]))
        .tint(.chartreuse)
}
