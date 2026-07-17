import SwiftUI

/// Screen 4 — where bills live. Multi-select: one pick gets a source-specific
/// echo, two or more switch to the catch-all so it never fixates on one tap.
struct SourcesView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var picked: Set<BillSource> = []

    var body: some View {
        BenScreen {
            CenteredQuestion(
                title: "Where do your\nbills end up?",
                intro: "Pick all that's true. No judgement."
            ) {
                VStack(spacing: 12) {
                    ForEach(BillSource.allCases, id: \.self) { source in
                        SelectablePill(
                            label: source.label, emoji: source.emoji,
                            isSelected: picked.contains(source)
                        ) {
                            if picked.contains(source) { picked.remove(source) } else { picked.insert(source) }
                        }
                    }
                }
                EchoSlot(
                    text: OnboardingCopy.sourcesEcho(picked),
                    emotion: OnboardingCopy.sourcesEmotion(picked)
                )
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                coordinator.sources = picked
                coordinator.saveAttributes()
                coordinator.advance(to: .volume)
            }
            .disabled(picked.isEmpty)
            .opacity(picked.isEmpty ? 0.45 : 1)
        }
    }
}

/// Screen 5 — how many bills land each month. Time-boxed so the yearly maths
/// on the next screen is defensible. Subscriptions count too.
struct VolumeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var selected: BillVolume?

    var body: some View {
        BenScreen {
            CenteredQuestion(
                title: "How many bills land\nat your place each month?",
                intro: "Count the sneaky ones too. Netflix, Kayo, the gym you swear you'll use. If it leaves your account, it's a bill."
            ) {
                VStack(spacing: 12) {
                    ForEach(BillVolume.allCases, id: \.self) { volume in
                        SelectablePill(
                            label: volume.label, detail: volume.detail,
                            isSelected: selected == volume
                        ) { selected = volume }
                    }
                }
                EchoSlot(
                    text: selected.map(OnboardingCopy.volumeEcho),
                    emotion: selected.map(OnboardingCopy.volumeEmotion)
                )
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.volume = selected
                coordinator.saveAttributes()
                coordinator.advance(to: .statMaths)
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.45 : 1)
        }
    }
}

/// Screen 7 — the money question. Shame-free by design.
struct LateFeesView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var selected: LateFeeHistory?

    var body: some View {
        BenScreen {
            CenteredQuestion(
                title: "Copped a late fee\nin the last year?",
                intro: "Be honest, this is exactly the thing I'm for."
            ) {
                VStack(spacing: 12) {
                    ForEach(LateFeeHistory.allCases, id: \.self) { fees in
                        SelectablePill(
                            label: fees.label, detail: fees.detail,
                            isSelected: selected == fees
                        ) { selected = fees }
                    }
                }
                EchoSlot(
                    text: selected.map(OnboardingCopy.lateFeesEcho),
                    emotion: selected.map(OnboardingCopy.lateFeesEmotion)
                )
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.lateFees = selected
                coordinator.saveAttributes()
                coordinator.advance(to: .feeling)
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.45 : 1)
        }
    }
}

/// Screen 8 — names the feeling so Ben can answer it in kind. This line is
/// quoted back at the mirror and the paywall.
struct FeelingView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var selected: BillFeeling?

    var body: some View {
        BenScreen {
            CenteredQuestion(title: "What does bill stress\nfeel like for you?") {
                VStack(spacing: 12) {
                    ForEach(BillFeeling.allCases, id: \.self) { feeling in
                        SelectablePill(
                            label: feeling.label, emoji: feeling.emoji,
                            isSelected: selected == feeling
                        ) { selected = feeling }
                    }
                }
                EchoSlot(
                    text: selected.map(OnboardingCopy.feelingEcho),
                    emotion: selected == nil ? nil : "🤗"
                )
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.feeling = selected
                coordinator.saveAttributes()
                coordinator.advance(to: .mirror)
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.45 : 1)
        }
    }
}
