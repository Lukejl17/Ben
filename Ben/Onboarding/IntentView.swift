import SwiftUI

/// Screen 3 — the persona seed. Every option maps to its own echo and
/// playback flavour downstream.
struct IntentView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var selected: IntentContext?

    var body: some View {
        BenScreen {
            CenteredQuestion(
                title: "What's changed lately?",
                intro: "Bills apps get downloaded on a day something shifted. What was yours?"
            ) {
                VStack(spacing: 12) {
                    ForEach(IntentContext.allCases, id: \.self) { intent in
                        SelectablePill(
                            label: intent.label, emoji: intent.emoji,
                            isSelected: selected == intent
                        ) { selected = intent }
                    }
                }
                EchoSlot(
                    text: selected.map(OnboardingCopy.momentMirror),
                    emotion: selected.map(OnboardingCopy.momentEmotion)
                )
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.intent = selected
                coordinator.saveAttributes()
                services.analytics.track(.intentSelected(intent: selected.rawValue))
                coordinator.advance(to: .sources)
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.45 : 1)
        }
        .onAppear { selected = coordinator.intent }
    }
}
