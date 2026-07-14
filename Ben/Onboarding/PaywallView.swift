import SwiftUI

/// S9 — hard paywall. Three pages, honesty offsets throughout.
/// Continuing requires starting the trial; declining is view-only mode.
struct PaywallView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    @Environment(\.scenePhase) private var scenePhase
    @State private var page = 0
    @State private var reminderDaysBeforeEnd = 2  // pre-charge reminder, user-adjustable
    @State private var yearlySelected = true
    @State private var trackedPages: Set<Int> = []
    @State private var abandonmentTracked = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                outcomePage.tag(0)
                timelinePage.tag(1)
                pricePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 10) {
                if page < 2 {
                    BenPrimaryButton(title: "Continue") {
                        withAnimation { page += 1 }
                    }
                } else {
                    BenPrimaryButton(title: "Start my 7-day trial") { startTrial() }
                    Text(yearlySelected
                         ? "US$49.99/yr after the trial · cancel anytime in Settings in one tap"
                         : "US$5.99/mo after the trial · cancel anytime in Settings in one tap")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkMuted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear { trackPage(0) }
        .onChange(of: page) { _, newPage in trackPage(newPage) }
        .onChange(of: scenePhase) { _, phase in
            // Hard paywall: the only way out without a trial is leaving the app.
            if phase == .background && !abandonmentTracked && services.subscriptions.state() == .notStarted {
                abandonmentTracked = true
                services.analytics.track(.trialAbandonedAtPaywall)
            }
        }
    }

    // MARK: Page 1 — outcome

    private var outcomePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Never get surprised by a bill again — and never hear from Ben otherwise.")
                .font(.benPromise)
                .foregroundStyle(Color.benInk)
            Text("Every bill tracked, one calm reminder when it matters, silence the rest of the time.")
                .font(.benBody)
                .foregroundStyle(Color.benInkSecondary)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: Page 2 — the honest trial timeline

    private var timelinePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How the trial works")
                .font(.benTitle)
                .foregroundStyle(Color.benInk)
                .padding(.top, 48)

            BenCard {
                VStack(alignment: .leading, spacing: 14) {
                    timelineRow(symbol: "checkmark.circle", title: "Today", detail: "Full access. Every feature, no card charged.")
                    timelineRow(
                        symbol: "bell",
                        title: "Day \(StubSubscriptionService.trialLengthDays - reminderDaysBeforeEnd)",
                        detail: "I remind you the trial is ending — before any charge."
                    )
                    timelineRow(symbol: "creditcard", title: "Day 7", detail: "Billed, unless you've cancelled. One tap, no hoops.")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("When should I mention it?")
                    .font(.benLabel)
                    .foregroundStyle(Color.benInk)
                Picker("Pre-charge reminder", selection: $reminderDaysBeforeEnd) {
                    Text("3 days before").tag(3)
                    Text("2 days before").tag(2)
                    Text("1 day before").tag(1)
                }
                .pickerStyle(.segmented)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func timelineRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Color.benAccent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.benLabel)
                    .foregroundStyle(Color.benInk)
                Text(detail)
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkSecondary)
            }
        }
    }

    // MARK: Page 3 — price

    private var pricePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keep Ben on the job")
                .font(.benTitle)
                .foregroundStyle(Color.benInk)
                .padding(.top, 48)

            priceCard(
                title: "Yearly",
                price: "US$49.99/yr",
                detail: "≈ US$4.17 a month",
                selected: yearlySelected
            ) { yearlySelected = true }

            priceCard(
                title: "Monthly",
                price: "US$5.99/mo",
                detail: "Cancel anytime",
                selected: !yearlySelected
            ) { yearlySelected = false }

            BenCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The deal, plainly")
                        .font(.benLabel)
                        .foregroundStyle(Color.benInk)
                    Text("You pay for Ben, so your data is never the product. Cancel in one tap. "
                         + "If the trial lapses, your bills stay visible — reminders stop, that's all.")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func priceCard(title: String, price: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.benLabel)
                        .foregroundStyle(Color.benInk)
                    Text(detail)
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkMuted)
                }
                Spacer()
                Text(price)
                    .font(.benAmount)
                    .monospacedDigit()
                    .foregroundStyle(Color.benInk)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.benAccent)
                }
            }
            .padding(16)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.benAccent : Color.benHairline, lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func trackPage(_ index: Int) {
        guard !trackedPages.contains(index) else { return }
        trackedPages.insert(index)
        services.analytics.track(.paywallViewed(pageDepth: index + 1))
    }

    private func startTrial() {
        // HUMAN: App Store Connect products (annual US$49.99 / monthly US$5.99,
        // 7-day intro trial) + RevenueCat purchase flow replace this stub.
        services.subscriptions.startTrial(preChargeReminderDaysBeforeEnd: reminderDaysBeforeEnd)
        services.analytics.track(.trialStarted)
        coordinator.advance(to: .secondBill)
    }
}
