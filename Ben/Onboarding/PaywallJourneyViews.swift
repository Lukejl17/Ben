import SwiftUI
import UIKit

/// Paywall page 2 — the gift and the bell. The trial framed as a gift, then
/// the promise that Ben nudges before it ends. One-shot swing with a soft
/// haptic when the badge lands.
struct GiftBellView: View {
    let onContinue: () -> Void
    @State private var swing: Double = 0
    @State private var badgeShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Your first 7 days\nare on Ben.")
                .font(.baloo("Baloo2-ExtraBold", 30, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
            bell
                .padding(.vertical, 10)
            Text("I'll nudge you before it ends.")
                .font(.baloo("Baloo2-Bold", 15.5, relativeTo: .body))
                .foregroundStyle(Color.forestInk)
            Spacer()
            PaywallDots(current: 1)
            BenPrimaryButton(title: "Sounds fair", action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .task { await ring() }
    }

    private var bell: some View {
        ZStack {
            Circle()
                .fill(Color.rowFill)
                .overlay(Circle().strokeBorder(Color.rowStroke, lineWidth: 1.5))
                .frame(width: 130, height: 130)
            Image(systemName: "bell.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.forestInk)
                .rotationEffect(.degrees(swing), anchor: .top)
            Text("1")
                .font(.baloo("Baloo2-ExtraBold", 14, relativeTo: .footnote))
                .foregroundStyle(Color.onClay)
                .frame(width: 26, height: 26)
                .background(Color.clay, in: Circle())
                .offset(x: 30, y: -34)
                .scaleEffect(badgeShown ? 1 : 0.01)
        }
    }

    private func ring() async {
        guard !reduceMotion else { badgeShown = true; return }
        for (angle, pause) in [(13.0, 0.12), (-10, 0.12), (6, 0.12), (-3, 0.12), (0, 0.2)] {
            withAnimation(.spring(duration: 0.14)) { swing = angle }
            try? await Task.sleep(for: .seconds(pause))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { badgeShown = true }
    }
}

/// Paywall page 3 — the trial rail: three nodes, gradient connectors,
/// concrete dates. Day 5 is the promise that makes it feel safe.
struct TrialRailView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("How your 7 free\ndays work")
                .font(.baloo("Baloo2-ExtraBold", 30, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                railRow(symbol: "lock.open.fill", title: "Today",
                        detail: "Everything unlocked. No card charged.",
                        connector: [.chartreuse, .amber])
                railRow(symbol: "bell.fill", title: "Day 5",
                        detail: "A heads up from me that the trial is ending. Before any charge, always.",
                        connector: [.amber, .clay])
                railRow(symbol: "crown.fill", title: "Day 7",
                        detail: "Charged on \(chargeDate) unless you cancel first. One tap, no hoops.",
                        connector: nil)
            }
            .padding(.horizontal, 26)
            Spacer()
            PaywallDots(current: 2)
            BenPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private var chargeDate: String {
        let date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return date.formatted(.dateTime.day().month(.wide))
    }

    private func railRow(
        symbol: String, title: String, detail: String, connector: [Color]?
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.onCreamStrong)
                    .frame(width: 46, height: 46)
                    .background(Color.cream, in: Circle())
                    .benShadow(.floating)
                if let connector {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: connector, startPoint: .top, endPoint: .bottom))
                        .frame(width: 6)
                        .frame(minHeight: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.baloo("Baloo2-ExtraBold", 19, relativeTo: .title3))
                    .foregroundStyle(Color.forestInk)
                Text(detail)
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Paywall page 4 — late fees vs Ben, drawn to scale so no big number ever
/// sits next to the CTA looking like a price.
/// HUMAN: source the per-bill late-fee figures properly before ads go live.
struct FeeCompareView: View {
    let onContinue: () -> Void
    @State private var grown = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("One late fee buys\nmonths of Ben.")
                .font(.baloo("Baloo2-ExtraBold", 30, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
            BenCard {
                VStack(alignment: .leading, spacing: 4) {
                    BenEyebrow(text: "The going rate for being late")
                        .padding(.bottom, 6)
                    barRow(label: "Credit card", fraction: 1.0, amount: "~$30", delay: 0)
                    barRow(label: "Electricity", fraction: 0.5, amount: "~$15", delay: 0.12)
                    barRow(label: "Phone or internet", fraction: 0.5, amount: "~$15", delay: 0.24)
                    Rectangle()
                        .fill(Color.onCreamMuted.opacity(0.3))
                        .frame(height: 1)
                        .padding(.vertical, 6)
                    barRow(label: "Ben, per month", fraction: 0.14, amount: "$4.17",
                           delay: 0.4, isBen: true)
                }
            }
            Text("The average Aussie copped $119 in overdue fees last year (Finder).")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
            PaywallDots(current: 3)
            BenPrimaryButton(title: "Fair enough", action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .onAppear { withAnimation { grown = true } }
    }

    private func barRow(
        label: String, fraction: CGFloat, amount: String, delay: Double, isBen: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(isBen ? .baloo("Baloo2-ExtraBold", 13, relativeTo: .footnote) : .benMeta)
                .foregroundStyle(isBen ? Color.onCreamStrong : Color.onCreamMuted)
                .frame(width: 112, alignment: .leading)
            GeometryReader { geo in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isBen ? Color.onCreamStrong : Color.clay)
                        .frame(width: grown ? max(10, geo.size.width * fraction * 0.72) : 0)
                        .animation(.spring(duration: 0.7).delay(delay), value: grown)
                    Text(amount)
                        .font(.baloo("Baloo2-ExtraBold", 13.5, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundStyle(Color.onCream)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 26)
            .background(Color.onCreamStrong.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }
}
