import SwiftUI
import UIKit

/// Top-leading back control for every onboarding step after welcome.
struct OnboardingBackButton: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        Button {
            coordinator.goBack()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text("Back")
                    .font(.benLabel)
            }
            .foregroundStyle(Color.chartreuse)
        }
        .buttonStyle(BenPressable())
        .accessibilityIdentifier("Back")
    }
}

/// Centred question scaffold: title and options float mid-screen with
/// balanced forest above and below, per the onboarding prototype.
struct CenteredQuestion<Content: View>: View {
    let title: String
    var intro: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 12)
            Text(title)
                .font(.baloo("Baloo2-ExtraBold", 29, relativeTo: .title))
                .foregroundStyle(Color.chartreuse)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
            if let intro {
                Text(intro)
                    .font(.benBody)
                    .foregroundStyle(Color.forestInk.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
            content
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 640)
    }
}

/// Ben's instant reaction to an answer. The slot is always reserved so the
/// options never shift when the card appears; the card only animates when
/// its text changes (keyed on the text itself).
struct EchoSlot: View {
    var text: String?
    var emotion: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if let text {
                HStack(alignment: .top, spacing: 10) {
                    BenCharacter(size: 40)
                        .overlay(alignment: .bottomTrailing) {
                            if let emotion {
                                Text(emotion)
                                    .font(.system(size: 12))
                                    .padding(3)
                                    .background(Color.white.opacity(0.95), in: Circle())
                                    .offset(x: 6, y: 3)
                            }
                        }
                    Text(text)
                        .font(.baloo("Baloo2-Medium", 14, relativeTo: .footnote))
                        .foregroundStyle(Color.onCream)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .benShadow(.cream)
                .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
                .id(text)
            }
        }
        .frame(minHeight: 78)
        .animation(.spring(duration: 0.35), value: text)
        .accessibilityIdentifier("echo")
    }
}

/// Solid example chips on the volume screen — utilities through subscriptions on one line.
struct VolumeExampleChips: View {
    private struct Example: Identifiable {
        let id: String
        let label: String
        let fill: Color
        let foreground: Color
    }

    private let examples: [Example] = [
        Example(id: "agl", label: "AGL", fill: .amber, foreground: .onAmber),
        Example(id: "netflix", label: "Netflix", fill: .clay, foreground: .onClay),
        Example(id: "kayo", label: "Kayo", fill: .clay, foreground: .onClay),
        Example(id: "gym", label: "Gym", fill: .lavender, foreground: .onLavender),
        Example(id: "telstra", label: "Telstra", fill: .sky, foreground: .onSky),
        Example(id: "council", label: "Council", fill: .chartreuse, foreground: .onChartreuse)
    ]

    var body: some View {
        VStack(spacing: 8) {
            BenEyebrow(text: "All of these count", color: Color.forestInk.opacity(0.45))
            ViewThatFits(in: .horizontal) {
                chipRow(spacing: 5, fontSize: 11, horizontal: 7, vertical: 5)
                chipRow(spacing: 4, fontSize: 10, horizontal: 5, vertical: 4)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Examples: electricity, streaming, gym, phone, and council rates all count"
            )
        }
        .padding(.bottom, 4)
    }

    private func chipRow(spacing: CGFloat, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(examples) { example in
                Text(example.label)
                    .font(.baloo("Baloo2-Bold", fontSize, relativeTo: .caption2))
                    .foregroundStyle(example.foreground)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, horizontal)
                    .padding(.vertical, vertical)
                    .background(example.fill, in: Capsule())
            }
        }
    }
}

/// The wheel-of-fortune number: races early, then ticks to a stop with a
/// light haptic on the last few steps.
struct SpinNumber: View {
    enum Mode: Equatable {
        case countUp(to: Int, suffix: String)
        case reelDown(from: Int, to: Int, prefix: String)
    }

    let mode: Mode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var value: Int?

    var body: some View {
        Text(display)
            .font(.baloo("Baloo2-ExtraBold", 52, relativeTo: .largeTitle))
            .foregroundStyle(Color.onCreamStrong)
            .monospacedDigit()
            .padding(.vertical, -4)
            .task { await spin() }
    }

    private var display: String {
        switch mode {
        case .countUp(let target, let suffix):
            "\(value ?? min(0, target))\(suffix)"
        case .reelDown(let from, _, let prefix):
            "\(prefix)\(value ?? from)"
        }
    }

    private func spin() async {
        let ticker = UIImpactFeedbackGenerator(style: .light)
        switch mode {
        case .countUp(let target, _):
            if reduceMotion { value = target; return }
            let total = 1.5
            let steps = 26
            var elapsed = 0.0
            for step in 1...steps {
                let progress = Double(step) / Double(steps)
                let at = total * pow(progress, 2.6)
                try? await Task.sleep(for: .seconds(max(0, at - elapsed)))
                elapsed = at
                value = Int((Double(target) * progress).rounded())
                if steps - step < 3 { ticker.impactOccurred() }
            }
        case .reelDown(let from, let target, _):
            if reduceMotion { value = target; return }
            value = from
            var current = from
            var tick = 0
            while current > target {
                try? await Task.sleep(for: .seconds(0.06 + Double(tick * tick) * 0.014))
                current -= 1
                tick += 1
                value = current
                if current - target < 3 { ticker.impactOccurred() }
            }
        }
    }
}
