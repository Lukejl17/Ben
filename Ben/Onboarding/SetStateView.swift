import SwiftUI

/// S8 — you're set. Calm text, no celebration.
struct SetStateView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var accountSaved = false
    @State private var showAccountSheet = false

    private var bill: Bill? { coordinator.confirmedBill }

    var body: some View {
        BenScreen {
            VStack(alignment: .leading, spacing: 0) {
                Text("Done.")
                    .font(.baloo("Baloo2-ExtraBold", 44, relativeTo: .largeTitle))
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 36)
                    .padding(.bottom, 10)

                BenVoiceText(text: benLine, quiet: true)
                    .foregroundStyle(Color.forestInk.opacity(0.65))
                    .padding(.bottom, 22)
            }

            if let bill {
                BenCard {
                    HStack(alignment: .center, spacing: 14) {
                        BenIconCircle(
                            systemName: BillCategories.symbol(forIssuer: bill.issuer),
                            fill: BillCategories.wash(forIssuer: bill.issuer).bg,
                            iconColor: BillCategories.wash(forIssuer: bill.issuer).fg
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bill.issuer)
                                .font(.benCardTitle)
                                .foregroundStyle(Color.onCream)
                            Text("Due \(bill.dueDate.formatted(.dateTime.day().month(.wide)))")
                                .font(.benMeta)
                                .foregroundStyle(Color.onCreamMuted)
                            if bill.hasNotification, let next = nextReminder {
                                Label(
                                    "Mention on \(next.formatted(.dateTime.day().month(.abbreviated)))",
                                    systemImage: "bell.fill"
                                )
                                .font(.benMeta)
                                .lineLimit(1)
                                .foregroundStyle(Color.amber)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(bill.amount.formatted(.currency(code: "AUD")))
                                .font(.benAmount)
                                .monospacedDigit()
                                .foregroundStyle(Color.onCream)
                            StatusChipOnCream(status: bill.status)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            Text("Nothing else needs your attention.")
                .font(.benBody)
                .foregroundStyle(Color.forestInk.opacity(0.65))

            Text("1 bill tracked. Most people add 2–3 to stop thinking about bills entirely.")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.5))
        } cta: {
            if !accountSaved {
                BenSecondaryButton(title: "Save my setup", systemImage: "person.crop.circle.badge.plus") {
                    showAccountSheet = true
                }
            } else {
                Text("Setup saved to your account.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }

            BenPrimaryButton(title: "Continue") {
                coordinator.advance(to: .paywall)
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet { _ in
                accountSaved = true
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
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
