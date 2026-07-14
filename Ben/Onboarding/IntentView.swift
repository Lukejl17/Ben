import SwiftUI

/// S2 — life-stage intent. Single select, no branching.
struct IntentView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var selected: IntentContext?

    var body: some View {
        BenScreen(title: "What brings you in?") {
            Text("Helps me pitch things right — no wrong answers.")
                .font(.benBody)
                .foregroundStyle(Color.benInkSecondary)
                .padding(.bottom, 10)

            VStack(spacing: 12) {
                ForEach(IntentContext.allCases, id: \.self) { intent in
                    SelectablePill(label: intent.label, isSelected: selected == intent) {
                        selected = intent
                    }
                }
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.intent = selected
                services.analytics.track(.intentSelected(intent: selected.rawValue))
                coordinator.advance(to: .reminderStyle)
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.45 : 1)
        }
    }
}
