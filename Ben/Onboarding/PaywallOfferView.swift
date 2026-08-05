import SwiftUI

/// Paywall page 5 — the offer. Countdown up top, Ben and the personal pitch
/// centred, everything transactional gathered at the thumb.
struct PaywallOfferView: View {
    let onStart: () -> Void
    let onOtherPlans: () -> Void
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    var body: some View {
        VStack(spacing: 14) {
            PaywallDots(current: 4)
                .padding(.top, 14)
            WelcomeOfferChip()
                .padding(.top, 6)
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
                tick("$0 due today. 7 days free first")
            }
            .padding(.horizontal, 10)
            Spacer()
            PaywallAssurance(text: "No payment due now. Cancel anytime")
            BenPrimaryButton(title: "Start for $0.00", action: onStart)
            equivalentLines
            BenTextButton(title: "Show me other plans", action: onOtherPlans)
                .frame(maxWidth: .infinity)
            PaywallLegalRow()
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
                + Text("US$4.17").foregroundStyle(Color.chartreuse)
                + Text("/month"))
                .font(.baloo("Baloo2-Bold", 14.5, relativeTo: .footnote))
                .foregroundStyle(Color.forestInk)
            Text("7 days free, then US$49.99/yr")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.55))
        }
    }
}

/// Paywall page 6 — other plans. Annual framed as the standing offer;
/// selection switches the assurance line and the CTA.
struct PaywallPlansView: View {
    let onStart: () -> Void
    let onBack: () -> Void
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
            Text("If the trial lapses, your bills stay visible. Reminders stop, that's all.")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
            PaywallAssurance(
                text: monthlySelected
                    ? "No commitment, cancel anytime"
                    : "No payment due now. Cancel anytime"
            )
            BenPrimaryButton(
                title: monthlySelected ? "Subscribe monthly" : "Start for $0.00"
            ) {
                // HUMAN: monthly maps to the monthly product purchase via
                // RevenueCat; the stub starts the same local trial either way.
                onStart()
            }
            BenTextButton(title: "Back to the offer", action: onBack)
                .frame(maxWidth: .infinity)
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
                    (Text("US$4.17").font(.baloo("Baloo2-ExtraBold", 17, relativeTo: .headline))
                        + Text("/month").font(.baloo("Baloo2-Bold", 12, relativeTo: .caption)))
                        .monospacedDigit()
                }
                (Text("US$69.99").strikethrough().foregroundStyle(planMuted(selected: !monthlySelected))
                    + Text("  US$49.99/year"))
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
                    (Text("US$5.99").font(.baloo("Baloo2-ExtraBold", 17, relativeTo: .headline))
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

/// The welcome-offer countdown. The deadline persists per install so it
/// cannot reset on relaunch.
/// HUMAN: back this with a real time-boxed RevenueCat intro offer, or cut it.
struct WelcomeOfferChip: View {
    static let deadlineKey = "welcomeOfferDeadline"
    @State private var remaining: TimeInterval = 3600

    var body: some View {
        HStack(spacing: 8) {
            Text("Welcome offer ends in")
            Text(formatted)
                .monospacedDigit()
                .tracking(0.5)
        }
        .font(.baloo("Baloo2-Bold", 12.5, relativeTo: .caption))
        .foregroundStyle(Color.onChartreuse)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.chartreuse, in: Capsule())
        .benShadow(.glow)
        .task { await tick() }
    }

    private var formatted: String {
        let total = max(0, Int(remaining))
        return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }

    private func tick() async {
        let defaults = UserDefaults.standard
        let deadline: Date
        if let saved = defaults.object(forKey: Self.deadlineKey) as? Date, saved > .now {
            deadline = saved
        } else {
            deadline = .now.addingTimeInterval(3600)
            defaults.set(deadline, forKey: Self.deadlineKey)
        }
        while !Task.isCancelled {
            remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { break }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

/// Restore purchase and the legal links, quiet at the very bottom.
/// HUMAN: wire the real privacy/terms URLs and the RevenueCat restore call.
struct PaywallLegalRow: View {
    var body: some View {
        HStack(spacing: 8) {
            legal("Restore purchase")
            divider
            legal("Privacy Policy")
            divider
            legal("T&Cs")
        }
    }

    private var divider: some View {
        Text("|").foregroundStyle(Color.forestInk.opacity(0.25)).font(.benMeta)
    }

    private func legal(_ label: String) -> some View {
        Button {
            // HUMAN: no-op until the URLs and restore flow exist.
        } label: {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.forestInk.opacity(0.45))
        }
    }
}
