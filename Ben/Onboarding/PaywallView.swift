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
        ZStack {
            BenCanvas()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    outcomePage.tag(0)
                    timelinePage.tag(1)
                    pricePage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if page < 2 {
                    BenPrimaryButton(title: "Continue") {
                        withAnimation(.spring(duration: 0.35)) { page += 1 }
                    }
                } else {
                    BenPrimaryButton(title: "Start my 7-day trial") { startTrial() }
                    Text(yearlySelected
                         ? "US$49.99/yr after the trial · cancel anytime in one tap"
                         : "US$5.99/mo after the trial · cancel anytime in one tap")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background {
                LinearGradient(
                    colors: [Color.forestBottom.opacity(0), Color.forestBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
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

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.chartreuse : Color.forestInk.opacity(0.5).opacity(0.25))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.spring(duration: 0.3), value: page)
            }
        }
    }

    // MARK: Page 1 — outcome

    private var outcomePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Never get surprised by a bill again — and never hear from Ben otherwise.")
                .font(.baloo("Baloo2-ExtraBold", 36, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .lineSpacing(2)
            Text("Every bill tracked, one calm reminder when it matters, silence the rest of the time.")
                .font(.benBody)
                .foregroundStyle(Color.forestInk.opacity(0.65))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Page 2 — the honest trial timeline

    private var timelinePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How the trial works")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 24)

                BenCard {
                    VStack(alignment: .leading, spacing: 18) {
                        timelineRow(symbol: "checkmark.circle.fill", fill: .chartreuse, iconColor: .onChartreuse,
                                    title: "Today",
                                    detail: "Full access. Every feature, no card charged.")
                        timelineRow(symbol: "bell.fill", fill: .amber, iconColor: .onAmber,
                                    title: "Day \(StubSubscriptionService.trialLengthDays - reminderDaysBeforeEnd)",
                                    detail: "I remind you the trial is ending — before any charge.")
                        timelineRow(symbol: "creditcard.fill", fill: .sky, iconColor: .onSky,
                                    title: "Day 7",
                                    detail: "Billed, unless you've cancelled. One tap, no hoops.")
                    }
                }

                Text("When should I mention it?")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.forestInk)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    reminderChip(days: 3)
                    reminderChip(days: 2)
                    reminderChip(days: 1)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func reminderChip(days: Int) -> some View {
        let isSelected = reminderDaysBeforeEnd == days
        return Button {
            reminderDaysBeforeEnd = days
        } label: {
            Text(days == 1 ? "1 day before" : "\(days) days before")
                .font(.benLabel)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.onChartreuse : Color.forestInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Color.chartreuse : Color.cream, in: Capsule())
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
        .animation(.spring(duration: 0.25), value: isSelected)
    }

    private func timelineRow(symbol: String, fill: Color, iconColor: Color, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            BenIconCircle(systemName: symbol, fill: fill, iconColor: iconColor, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.benCardTitle)
                    .foregroundStyle(Color.onCream)
                Text(detail)
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Page 3 — price

    private var pricePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Keep Ben on the job")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 24)

                recapCard

                PriceCard(
                    plan: .init(title: "Yearly", badge: "Best value", price: "US$49.99",
                                cadence: "/yr", detail: "≈ US$4.17 a month"),
                    selected: yearlySelected
                ) { yearlySelected = true }

                PriceCard(
                    plan: .init(title: "Monthly", badge: nil, price: "US$5.99",
                                cadence: "/mo", detail: "Cancel anytime"),
                    selected: !yearlySelected
                ) { yearlySelected = false }

                BenCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The deal, plainly")
                            .font(.benCardTitle)
                            .foregroundStyle(Color.onCream)
                        Text("You pay for Ben, so your data is never the product. Cancel in one tap. "
                             + "If the trial lapses, your bills stay visible — reminders stop, that's all.")
                            .font(.benMeta)
                            .foregroundStyle(Color.onCreamMuted)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// The interview, replayed one last time — the price lands against their
    /// problem, not a feature list.
    private var recapCard: some View {
        let fee = OnboardingCopy.feeMaths(coordinator.lateFees)
        var chips: [String] = []
        if let intent = coordinator.intent { chips.append(intent.label) }
        if let volume = coordinator.volume { chips.append("\(volume.label) bills a month") }
        if let feeling = coordinator.feeling { chips.append(feeling.label) }
        return BenCard {
            VStack(alignment: .leading, spacing: 10) {
                BenEyebrow(text: "What you're solving")
                FlowLayout(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.baloo("Baloo2-Bold", 12.5, relativeTo: .caption))
                            .foregroundStyle(Color.onCreamStrong)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.onCreamStrong.opacity(0.08), in: Capsule())
                    }
                }
                Text("Late fees: \(fee.number) · \(fee.line)")
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
            }
        }
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

/// One subscription option. Selection = wash fill + accent ring; badge floats the corner.
private struct PriceCard: View {
    struct Plan {
        let title: String
        let badge: String?
        let price: String
        let cadence: String
        let detail: String
    }

    let plan: Plan
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.benCardTitle)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(Color.onCream)
                    Text(plan.detail)
                        .font(.benMeta)
                        .lineLimit(1)
                        .foregroundStyle(Color.onCreamMuted)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(plan.price)
                        .font(.benAmount)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Color.onCream)
                    Text(plan.cadence)
                        .font(.benMeta)
                        .foregroundStyle(Color.onCreamMuted)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.onCreamStrong : Color.onCream.opacity(0.35))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.cream,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? Color.onCreamStrong : .clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if let badge = plan.badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(Color.onChartreuse)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.chartreuse, in: Capsule())
                        .offset(x: -14, y: -11)
                }
            }
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
        .animation(.spring(duration: 0.3), value: selected)
    }
}
