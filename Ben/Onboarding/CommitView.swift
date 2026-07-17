import SwiftUI
import UIKit

/// Screen 14 — the pact. Three beats: the promise with the bill front and
/// centre, a thumbprint on a bottom sheet, a sealing moment, then the payoff.
struct CommitView: View {
    private enum Stage { case pact, sealing, done }

    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var stage: Stage = .pact

    var body: some View {
        ZStack {
            BenCanvas()
            switch stage {
            case .pact: pact
            case .sealing: sealing
            case .done: done
            }
        }
        .animation(.spring(duration: 0.4), value: stage == .pact)
    }

    // MARK: Beat 1 — the promise, with the thumb on a bottom sheet

    private var pact: some View {
        VStack(spacing: 16) {
            Spacer()
            billSnippet
            Text("This bill gets\npaid on time.")
                .font(.baloo("Baloo2-ExtraBold", 31, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
            BenVoiceText(text: "I do the remembering.\nYou do the paying. That's the pact.")
                .multilineTextAlignment(.center)
            Spacer()
            commitSheet
        }
        .padding(.top, 30)
    }

    private var billSnippet: some View {
        let bill = coordinator.confirmedBill
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(bill?.issuer ?? "AGL Electricity")
                    .font(.baloo("Baloo2-Bold", 14.5, relativeTo: .footnote))
                    .foregroundStyle(Color.onCream)
                Text("Due \((bill?.dueDate ?? .now).formatted(.dateTime.day().month(.wide)))")
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
            }
            Spacer()
            Text((bill?.amount ?? 243).formatted(.currency(code: "AUD")))
                .font(.baloo("Baloo2-ExtraBold", 20, relativeTo: .headline))
                .monospacedDigit()
                .foregroundStyle(Color.onCreamStrong)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.colorScheme, .light)
        .benShadow(.cream)
        .padding(.horizontal, 20)
    }

    private var commitSheet: some View {
        VStack(spacing: 4) {
            Text("Press to commit")
                .font(.baloo("Baloo2-Bold", 14.5, relativeTo: .footnote))
                .foregroundStyle(Color.onCreamStrong)
            Text("A promise made physical. It works, oddly.")
                .font(.benMeta)
                .foregroundStyle(Color.onCreamMuted)
            Button(action: seal) {
                thumbprint(tint: Color.onCreamStrong)
            }
            .buttonStyle(BenPressable())
            .accessibilityIdentifier("Press to commit")
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 44)
        .background(
            Color.cream,
            in: UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34)
        )
        .environment(\.colorScheme, .light)
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
    }

    // MARK: Beat 2 — sealing

    private var sealing: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Sealing the pact…")
                .font(.baloo("Baloo2-ExtraBold", 29, relativeTo: .title))
                .foregroundStyle(Color.chartreuse)
            BenVoiceText(text: "Filing it under things that are now my problem.")
                .multilineTextAlignment(.center)
            Spacer()
            thumbprint(tint: Color.forestInk.opacity(0.5))
                .overlay { SealingRing() }
                .padding(.bottom, 60)
        }
    }

    // MARK: Beat 3 — done

    private var done: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(Color.onChartreuse)
                .frame(width: 112, height: 112)
                .background(Color.chartreuse, in: Circle())
                .shadow(color: .chartreuse.opacity(0.5), radius: 24)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            Text("Commitment done.")
                .font(.baloo("Baloo2-ExtraBold", 31, relativeTo: .largeTitle))
                .foregroundStyle(Color.chartreuse)
                .padding(.top, 8)
            BenVoiceText(text: "This one gets paid on time.\nBoth of us on the hook now.")
                .multilineTextAlignment(.center)
            Spacer()
            BenPrimaryButton(title: "Keep it that way") {
                coordinator.advance(to: .paywall)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // MARK: Pieces

    private func thumbprint(tint: Color) -> some View {
        Image(systemName: "touchid")
            .font(.system(size: 56, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: 112, height: 112)
            .overlay {
                Circle()
                    .strokeBorder(tint.opacity(0.5), style: StrokeStyle(lineWidth: 2.5, dash: [6, 7]))
            }
    }

    private func seal() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(duration: 0.4)) { stage = .sealing }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            guard stage == .sealing else { return }
            coordinator.committed = true
            coordinator.saveAttributes()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(duration: 0.45)) { stage = .done }
        }
    }
}

/// The chartreuse arc spinning around the print while the pact seals.
private struct SealingRing: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(Color.chartreuse, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 130, height: 130)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}
