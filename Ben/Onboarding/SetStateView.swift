import SwiftUI

/// S8 — you're set. Calm text, no celebration.
struct SetStateView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var accountSaved = false

    private var bill: Bill? { coordinator.confirmedBill }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BenAvatar()
                BenVoiceText(text: benLine)
            }
            .padding(.top, 48)

            if let bill {
                BenCard {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bill.issuer)
                                .font(.benLabel)
                                .foregroundStyle(Color.benInk)
                            Text("Due \(bill.dueDate.formatted(.dateTime.day().month(.wide)))")
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkMuted)
                            if bill.hasNotification, let next = nextReminder {
                                Label(
                                    "Reminder \(next.formatted(.dateTime.day().month(.abbreviated)))",
                                    systemImage: "bell"
                                )
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkSecondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(bill.amount.formatted(.currency(code: "AUD")))
                                .font(.benAmount)
                                .monospacedDigit()
                                .foregroundStyle(Color.benInk)
                            StatusPill(status: bill.status)
                        }
                    }
                }
            }

            Text("Nothing else needs your attention.")
                .font(.benBody)
                .foregroundStyle(Color.benInkSecondary)

            Text("1 bill tracked. Most people add 2–3 to stop thinking about bills entirely.")
                .font(.benMeta)
                .foregroundStyle(Color.benInkMuted)

            Spacer()

            // HUMAN: Sign in with Apple capability + entitlement, then replace
            // this stub with SignInWithAppleButton.
            if !accountSaved {
                Button {
                    services.analytics.track(.accountCreated)
                    accountSaved = true
                } label: {
                    Label("Save my setup with Apple", systemImage: "applelogo")
                        .font(.benLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Setup saved to this device.")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkSecondary)
                    .frame(maxWidth: .infinity)
            }

            BenPrimaryButton(title: "Continue") {
                coordinator.advance(to: .paywall)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    private var benLine: String {
        guard let bill else { return "Done. Nothing else needs your attention." }
        let due = bill.dueDate.formatted(.dateTime.day().month(.wide))
        let amount = bill.amount.formatted(.currency(code: "AUD"))
        return "Done. \(bill.issuer), \(amount), due \(due) is my problem now."
    }

    private var nextReminder: Date? {
        guard let bill else { return nil }
        return ReminderScheduler.triggerDates(style: coordinator.reminderStyle, dueDate: bill.dueDate).first
    }
}
