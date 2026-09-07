import SwiftUI

/// Paywall page 5 — the offer. Countdown up top, Ben and the personal pitch
/// centred, everything transactional gathered at the thumb.
struct PaywallOfferView: View {
    let onStart: () -> Void
    let onOtherPlans: () -> Void
    var isBusy: Bool = false
    var errorLine: String?
    var onRestore: () -> Void = {}
    var pricing: PlanPricing = .fallback
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    var body: some View {
        VStack(spacing: 14) {
            PaywallDots(current: 4)
                .padding(.top, 14)
            if pricing.annualHasIntro {
                WelcomeOfferChip()
                    .padding(.top, 6)
            }
            Spacer()
            BenCharacter(size: 78)
                .padding(.bottom, -4)
            Text("G'day\(firstName).\nKeep Ben on the job.")
                .font(.baloo("Baloo2-ExtraBold", 26, relativeTo: .title))
                .foregroundStyle(Color.chartreuse)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
            recapCard
            VStack(alignment: .leading, spacing: 10) {
                tick("Bills tracked and reminded, calmly")
                tick("Payment details ready to copy and pay")
                tick(pricing.annualHasIntro
                     ? "$0 due today. 7 days free first"
                     : "Annual plan. Cancel anytime")
            }
            .padding(.horizontal, 10)
            Spacer()
            PaywallAssurance(text: pricing.annualHasIntro
                             ? "No payment due now. Cancel anytime"
                             : "Cancel anytime")
            if let errorLine {
                Text(errorLine)
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            BenPrimaryButton(
                title: pricing.annualHasIntro ? "Start for $0.00" : "Subscribe annually",
                isBusy: isBusy,
                action: onStart
            )
            equivalentLines
            BenTextButton(title: "Show me other plans", action: onOtherPlans)
                .frame(maxWidth: .infinity)
            PaywallLegalRow(onRestore: onRestore)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }

    private var firstName: String {
        guard let name = services.accounts.account?.name.components(separatedBy: " ").first,
              !name.isEmpty else { return "" }
        return " \(name)"
    }

    private var recapCard: some View {
        var chips: [String] = []
        if let intent = coordinator.intent { chips.append(intent.label) }
        if let volume = coordinator.volume { chips.append("\(volume.label) bills a month") }
        if let feeling = coordinator.feeling { chips.append(feeling.label) }
        return BenCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
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
            }
        }
    }

    private func tick(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.chartreuse)
                .padding(.top, 2)
            Text(text)
                .font(.benBody)
                .foregroundStyle(Color.forestInk.opacity(0.85))
        }
    }

    private var equivalentLines: some View {
        VStack(spacing: 2) {
            (Text("Equivalent to ")
                + Text(pricing.annualPerMonth).foregroundStyle(Color.chartreuse)
                + Text("/month"))
                .font(.baloo("Baloo2-Bold", 14.5, relativeTo: .footnote))
                .foregroundStyle(Color.forestInk)
            Text(pricing.annualHasIntro
                 ? "7 days free, then \(pricing.annualPrice)/yr"
                 : "Then \(pricing.annualPrice)/yr")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.55))
        }
    }
}

/// Paywall page 6 — other plans. Annual framed as the standing offer;
/// selection switches the assurance line and the CTA.
struct PaywallPlansView: View {
    let onPurchase: (SubscriptionPlan) -> Void
    let onBack: () -> Void
    var isBusy: Bool = false
    var errorLine: String?
    var onRestore: () -> Void = {}
    var pricing: PlanPricing = .fallback
    @State private var monthlySelected = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Plans, plainly.")
                .font(.baloo("Baloo2-ExtraBold", 26, relativeTo: .title))
                .foregroundStyle(Color.chartreuse)
                .padding(.bottom, 8)
            annualCard
            monthlyCard
            Text("If a plan ends, Ben waits here. Reminders pause until you're back.")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
            PaywallAssurance(
                text: monthlySelected
                    ? "No commitment, cancel anytime"
                    : (pricing.annualHasIntro
                       ? "No payment due now. Cancel anytime"
                       : "Cancel anytime")
            )
            if let errorLine {
                Text(errorLine)
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            BenPrimaryButton(
                title: monthlySelected
                    ? "Subscribe monthly"
                    : (pricing.annualHasIntro ? "Start for $0.00" : "Subscribe annually"),
                isBusy: isBusy
            ) {
                onPurchase(monthlySelected ? .monthly : .annual)
            }
            BenTextButton(title: "Back to the offer", action: onBack)
                .frame(maxWidth: .infinity)
            PaywallLegalRow(onRestore: onRestore)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .animation(.spring(duration: 0.3), value: monthlySelected)
    }

    private var annualCard: some View {
        Button {
            monthlySelected = false
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Annual")
                        .font(.baloo("Baloo2-ExtraBold", 17, relativeTo: .headline))
                    Spacer()
                    (Text(pricing.annualPerMonth).font(.baloo("Baloo2-ExtraBold", 17, relativeTo: .headline))
                        + Text("/month").font(.baloo("Baloo2-Bold", 12, relativeTo: .caption)))
                        .monospacedDigit()
                }
                annualDetail
                    .font(.benMeta)
            }
            .foregroundStyle(monthlySelected ? Color.forestInk : Color.onCream)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                monthlySelected ? Color.rowFill : Color.cream,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(monthlySelected ? Color.rowStroke : Color.clear, lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if pricing.annualHasIntro {
                    Text("FREE TRIAL + 29% OFF")
                        .font(.baloo("Baloo2-ExtraBold", 11, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(Color.chartreuse)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.onCreamStrong, in: Capsule())
                        .offset(x: -14, y: -12)
                }
            }
        }
        .buttonStyle(BenPressable())
        .benShadow(monthlySelected ? .floating : .cream)
    }

    private var monthlyCard: some View {
        Button {
            monthlySelected = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Monthly")
                        .font(.baloo("Baloo2-ExtraBold", 17, relativeTo: .headline))
                    Spacer()
                    (Text(pricing.monthlyPrice).font(.baloo("Baloo2-ExtraBold", 17, relativeTo: .headline))
                        + Text("/mo").font(.baloo("Baloo2-Bold", 12, relativeTo: .caption)))
                        .monospacedDigit()
                }
                Text("No trial. Cancel anytime.")
                    .font(.benMeta)
                    .foregroundStyle(planMuted(selected: monthlySelected))
            }
            .foregroundStyle(monthlySelected ? Color.onCream : Color.forestInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                monthlySelected ? Color.cream : Color.rowFill,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(monthlySelected ? Color.clear : Color.rowStroke, lineWidth: 1.5)
            )
        }
        .buttonStyle(BenPressable())
        .benShadow(monthlySelected ? .cream : .floating)
    }

    private var annualDetail: Text {
        if let standing = pricing.standingPrice {
            return Text(standing).strikethrough().foregroundStyle(planMuted(selected: !monthlySelected))
                + Text("  \(pricing.annualPrice)/year")
        }
        return Text("\(pricing.annualPrice)/year")
    }

    private func planMuted(selected: Bool) -> Color {
        selected ? Color.onCreamMuted : Color.forestInk.opacity(0.5)
    }
}

/// The tick-and-line reassurance that sits directly above the CTA.
struct PaywallAssurance: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.onChartreuse)
                .frame(width: 18, height: 18)
                .background(Color.chartreuse, in: Circle())
            Text(text)
                .font(.baloo("Baloo2-Bold", 13.5, relativeTo: .footnote))
                .foregroundStyle(Color.forestInk)
        }
    }
}

/// Honest intro chip — the 7-day trial is Apple's, not a fake countdown.
struct WelcomeOfferChip: View {
    var body: some View {
        Text("7 days free")
            .font(.baloo("Baloo2-Bold", 12.5, relativeTo: .caption))
            .foregroundStyle(Color.onChartreuse)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.chartreuse, in: Capsule())
            .benShadow(.glow)
    }
}

/// Restore purchase and the legal links, quiet at the very bottom.
struct PaywallLegalRow: View {
    var onRestore: () -> Void = {}
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onRestore) {
                Text("Restore purchase")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.forestInk.opacity(0.45))
            }
            divider
            legal("Privacy Policy", url: "https://benandbill.app/privacy")
            divider
            legal("T&Cs", url: "https://benandbill.app/terms")
        }
    }

    private var divider: some View {
        Text("|").foregroundStyle(Color.forestInk.opacity(0.25)).font(.benMeta)
    }

    private func legal(_ label: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                openURL(link)
            }
        } label: {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.forestInk.opacity(0.45))
        }
    }
}
