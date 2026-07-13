import SwiftUI

/// S3 — reminder style, with the anti-noise promise said out loud.
struct ReminderStyleView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var selected: ReminderStyle = .fewDaysEarly

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BenAvatar()
                BenVoiceText(
                    text: "I only speak up when a bill actually needs you. No streaks, no check-ins, no noise. When suits you?"
                )
            }
            .padding(.top, 48)
            VStack(spacing: 10) {
                ForEach(ReminderStyle.allCases, id: \.self) { style in
                    SelectablePill(label: style.label, detail: style.detail, isSelected: selected == style) {
                        selected = style
                    }
                }
            }
            Spacer()
            BenPrimaryButton(title: "Continue") {
                coordinator.reminderStyle = selected
                services.analytics.track(.reminderStyleSelected(style: selected.rawValue))
                coordinator.advance(to: .upload)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }
}
