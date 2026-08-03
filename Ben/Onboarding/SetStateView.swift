import SwiftUI

/// S8 — you're set, then a required account before paywall.
/// No skip: the trial and purchase need an account to hang off.
struct SetStateView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(PendingEmailMonitor.self) private var pendingMonitor

    @State private var isWorking = false
    @State private var errorLine: String?
    @State private var showEmailForm = false
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = true

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
                .padding(.bottom, 16)
            }

            Text("Save this setup")
                .font(.benCardTitle)
                .foregroundStyle(Color.chartreuse)
                .padding(.bottom, 4)

            Text("So your bills and your plan stay with you — even if you change phones. Takes a moment, then we can set up your trial.")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            if let errorLine {
                Text(errorLine)
                    .font(.benMeta)
                    .foregroundStyle(Color.statusLateFg)
            }
        } cta: {
            AccountSignInControls(
                isWorking: $isWorking,
                errorLine: $errorLine,
                showEmailForm: $showEmailForm,
                email: $email,
                password: $password,
                isCreatingAccount: $isCreatingAccount,
                onSignedIn: { account in
                    // Bind this Firebase user to the bills created during onboarding.
                    // Won't wipe when lastAccountId is empty (fresh after sign-out).
                    LocalAccountSession.bindAccount(
                        account,
                        modelContext: modelContext,
                        scheduler: services.scheduler,
                        pendingEmails: pendingMonitor
                    )
                    coordinator.advance(to: .commit)
                }
            )
            .overlay {
                if isWorking {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.chartreuse)
                }
            }
        }
        .onAppear {
            // Already signed in (e.g. returning) — no need to ask again.
            if let account = services.accounts.account {
                LocalAccountSession.remember(account)
                coordinator.advance(to: .commit)
            }
        }
    }

    private var benLine: String {
        guard let bill else { return "Nothing else needs your attention." }
        let due = bill.dueDate.formatted(.dateTime.day().month(.wide))
        let amount = bill.amount.formatted(.currency(code: "AUD"))
        let parts = coordinator.confirmedBills.count
        if parts > 1 {
            return "\(bill.issuer), \(parts) instalments — first \(amount) due \(due) is my problem now."
        }
        return "\(bill.issuer), \(amount), due \(due) is my problem now."
    }

    private var nextReminder: Date? {
        guard let bill else { return nil }
        return ReminderScheduler.triggerDates(style: coordinator.reminderStyle, dueDate: bill.dueDate).first
    }
}
