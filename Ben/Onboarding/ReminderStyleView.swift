import SwiftUI

/// Screen 11 — the contract question, kept late so it reads as tailoring
/// rather than setup. Echoed like every other answer.
struct ReminderStyleView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var selected: ReminderStyle?

    var body: some View {
        BenScreen {
            CenteredQuestion(
                title: "When should I speak up?",
                intro: "I only talk when a bill needs you. No streaks, no check-ins, no noise."
            ) {
                VStack(spacing: 12) {
                    ForEach(ReminderStyle.allCases, id: \.self) { style in
                        SelectablePill(
                            label: style.label, detail: style.detail,
                            isSelected: selected == style
                        ) { selected = style }
                    }
                }
                EchoSlot(
                    text: selected.map(OnboardingCopy.reminderEcho),
                    emotion: selected == nil ? nil : "🔔"
                )
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.reminderStyle = selected
                coordinator.saveAttributes()
                services.analytics.track(.reminderStyleSelected(style: selected.rawValue))
                coordinator.advance(to: .plan)
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.45 : 1)
        }
    }
}
