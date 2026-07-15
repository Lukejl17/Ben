import SwiftUI

/// S3 — reminder style, with the anti-noise promise said out loud.
struct ReminderStyleView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var selected: ReminderStyle = .fewDaysEarly

    var body: some View {
        BenScreen(title: "When should I speak up?") {
            HStack(alignment: .top, spacing: 12) {
                BenVoiceText(
                    text: "I only speak up when a bill actually needs you. No streaks, no check-ins, no noise.",
                    quiet: true
                )
                .foregroundStyle(Color.forestInk.opacity(0.65))
            }
            .padding(.bottom, 10)

            VStack(spacing: 12) {
                ForEach(ReminderStyle.allCases, id: \.self) { style in
                    SelectablePill(label: style.label, detail: style.detail, isSelected: selected == style) {
                        selected = style
                    }
                }
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                coordinator.reminderStyle = selected
                services.analytics.track(.reminderStyleSelected(style: selected.rawValue))
                coordinator.advance(to: .upload)
            }
        }
    }
}
