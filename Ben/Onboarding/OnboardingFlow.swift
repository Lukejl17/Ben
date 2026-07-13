import SwiftUI

/// Container switching between onboarding steps. Fades only — no theatrics.
struct OnboardingFlow: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.benCanvas.ignoresSafeArea()
            switch coordinator.step {
            case .welcome: WelcomeView()
            case .intent: IntentView()
            case .reminderStyle: ReminderStyleView()
            case .upload: UploadBillView()
            case .capture: CaptureExtractView()
            case .manualEntry: ManualEntryView()
            case .confirm: ConfirmBillView()
            case .reminderSetup: ReminderSetupView()
            case .setState: SetStateView()
            case .paywall: PaywallView()
            case .secondBill: SecondBillView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.step)
    }
}

// MARK: - Shared onboarding atoms

/// Ben's placeholder avatar. HUMAN: replace with the final illustration
/// (clay + ink palette, one calm expression). Never above 44pt, never floating.
struct BenAvatar: View {
    var body: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 40))
            .foregroundStyle(Color.benClay)
            .accessibilityHidden(true)
    }
}

/// The single filled CTA. Eucalyptus is the only interactive colour.
struct BenPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.benLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }
}

/// Quiet secondary action — a plain text button in the accent colour.
struct BenSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.benLabel)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.benAccent)
    }
}

/// Single-select pill used by S2/S3.
struct SelectablePill: View {
    let label: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.benLabel)
                        .foregroundStyle(Color.benInk)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.benAccent)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.benAccent : Color.benHairline, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
