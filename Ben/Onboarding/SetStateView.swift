import SwiftUI

/// S8 — you're set. Calm text, no celebration.
struct SetStateView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var accountSaved = false

    private var bill: Bill? { coordinator.confirmedBill }

    var body: some View {
        BenScreen {
            VStack(alignment: .leading, spacing: 0) {
                Text("Done.")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Color.benInk)
                    .padding(.top, 36)
                    .padding(.bottom, 10)

                BenVoiceText(text: benLine, quiet: true)
                    .foregroundStyle(Color.benInkSecondary)
                    .padding(.bottom, 22)
            }

            if let bill {
                BenCard {
                    HStack(alignment: .center, spacing: 14) {
                        BenIconCircle(
                            systemName: BillCategories.symbol(forIssuer: bill.issuer),
                            wash: BillCategories.wash(forIssuer: bill.issuer)
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bill.issuer)
                                .font(.benCardTitle)
                                .foregroundStyle(Color.benInk)
                            Text("Due \(bill.dueDate.formatted(.dateTime.day().month(.wide)))")
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkMuted)
                            if bill.hasNotification, let next = nextReminder {
                                Label(
                                    "Mention on \(next.formatted(.dateTime.day().month(.abbreviated)))",
                                    systemImage: "bell.fill"
                                )
                                .font(.benMeta)
                                .lineLimit(1)
                                .foregroundStyle(Color.washAmberFg)
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
                .padding(.bottom, 12)
            }

            Text("Nothing else needs your attention.")
                .font(.benBody)
                .foregroundStyle(Color.benInkSecondary)

            Text("1 bill tracked. Most people add 2–3 to stop thinking about bills entirely.")
                .font(.benMeta)
                .foregroundStyle(Color.benInkMuted)
        } cta: {
            // HUMAN: Sign in with Apple capability + entitlement, then replace
            // this stub with SignInWithAppleButton.
            if !accountSaved {
                BenSecondaryButton(title: "Save my setup with Apple", systemImage: "applelogo") {
                    services.analytics.track(.accountCreated)
                    accountSaved = true
                }
            } else {
                Text("Setup saved to this device.")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkSecondary)
                    .frame(maxWidth: .infinity)
            }

            BenPrimaryButton(title: "Continue") {
                coordinator.advance(to: .paywall)
            }
        }
    }

    private var benLine: String {
        guard let bill else { return "Nothing else needs your attention." }
        let due = bill.dueDate.formatted(.dateTime.day().month(.wide))
        let amount = bill.amount.formatted(.currency(code: "AUD"))
        return "\(bill.issuer), \(amount), due \(due) is my problem now."
    }

    private var nextReminder: Date? {
        guard let bill else { return nil }
        return ReminderScheduler.triggerDates(style: coordinator.reminderStyle, dueDate: bill.dueDate).first
    }
}
