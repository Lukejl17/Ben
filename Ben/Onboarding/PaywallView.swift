import SwiftUI

/// S15 — the paywall, flow F from the lab: outcome, gift + bell, trial rail,
/// late fees vs Ben, then the offer. Hard paywall: the only way past without
/// a trial is leaving the app.
struct PaywallView: View {
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

    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: Page = .outcome
    @State private var trackedPages: Set<Int> = []
    @State private var abandonmentTracked = false

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
                        onStart: startTrial,
                        onOtherPlans: { advance(to: .plans) }
                    )
                case .plans:
                    PaywallPlansView(
                        onStart: startTrial,
                        onBack: { advance(to: .offer) }
                    )
                }
            }
            .transition(.opacity)
        }
        .animation(.spring(duration: 0.35), value: page)
        .onAppear {
            trackPage(.outcome)
            syncBackInterceptor(for: page)
        }
        .onChange(of: page) { _, newPage in
            trackPage(newPage)
            syncBackInterceptor(for: newPage)
        }
        .onDisappear { coordinator.backInterceptor = nil }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && !abandonmentTracked
                && services.subscriptions.state() == .notStarted {
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
            guard let previous = current.previous else { return false }
            withAnimation(.spring(duration: 0.35)) { page = previous }
            return true
        }
    }

    private func trackPage(_ page: Page) {
        guard !trackedPages.contains(page.rawValue) else { return }
        trackedPages.insert(page.rawValue)
        services.analytics.track(.paywallViewed(pageDepth: page.rawValue + 1))
    }

    private func startTrial() {
        // HUMAN: App Store Connect products (annual US$49.99 with 7-day intro
        // trial, monthly US$5.99, and the US$69.99 anchor price the 29%-off
        // badge claims) + RevenueCat purchase flow replace this stub. The
        // welcome-offer countdown must map to a real time-boxed intro offer.
        services.subscriptions.startTrial(preChargeReminderDaysBeforeEnd: 2)
        services.analytics.track(.trialStarted)
        coordinator.advance(to: .secondBill)
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
