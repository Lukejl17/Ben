import SwiftUI

/// S2 — life-stage intent. Single select, no branching.
struct IntentView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var selected: IntentContext?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What brings you in?")
                .font(.benTitle)
                .foregroundStyle(Color.benInk)
                .padding(.top, 48)
            VStack(spacing: 10) {
                ForEach(IntentContext.allCases, id: \.self) { intent in
                    SelectablePill(label: intent.label, isSelected: selected == intent) {
                        selected = intent
                    }
                }
            }
            Spacer()
            BenPrimaryButton(title: "Continue") {
                guard let selected else { return }
                coordinator.intent = selected
                services.analytics.track(.intentSelected(intent: selected.rawValue))
                coordinator.advance(to: .reminderStyle)
            }
            .disabled(selected == nil)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }
}
