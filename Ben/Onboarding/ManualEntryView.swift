import SwiftUI

/// B2 — parse failed. Three fields max, pre-filled with whatever we did get.
struct ManualEntryView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(PendingEmailMonitor.self) private var pendingMonitor
    @Environment(\.services) private var services
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var issuer = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var showRemoveConfirm = false
    @State private var isRemoving = false

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var isValid: Bool {
        !issuer.trimmingCharacters(in: .whitespaces).isEmpty && amount != nil
    }

    private var canRemovePendingEmail: Bool {
        coordinator.pendingEmailKey != nil
    }

    var body: some View {
        BenScreen {
            HStack(alignment: .top, spacing: 14) {
                BenCharacter(size: 64)
                BenVoiceText(
                    text: "That one's hard to read, happens a lot. Type the basics and I've got it from here.",
                    quiet: true
                )
            }
            .padding(.top, 28)
            .padding(.bottom, 12)

            VStack(spacing: 12) {
                BenField("Who's it from") {
                    TextField("AGL, Telstra…", text: $issuer)
                }
                BenField("Amount") {
                    TextField("$0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                }
                BenField("Due date") {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
        } cta: {
            BenPrimaryButton(title: "Continue") {
                coordinator.parsed = ParsedBill(
                    issuer: issuer.trimmingCharacters(in: .whitespaces),
                    amount: amount,
                    dueDate: dueDate,
                    confidence: 1.0
                )
                coordinator.uploadMethod = .manual
                services.analytics.track(.manualEntryCompleted)
                coordinator.advance(to: .confirm)
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.45)

            if canRemovePendingEmail {
                BenTextButton(title: isRemoving ? "Removing…" : "Remove") {
                    showRemoveConfirm = true
                }
                .disabled(isRemoving)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Remove this bill?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) { discardPendingEmail() }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text("It won't be tracked, and it'll leave your waiting list.")
        }
        .onAppear {
            services.analytics.track(.manualEntryStarted)
            if let parsed = coordinator.parsed {
                issuer = parsed.issuer ?? ""
                if let parsedAmount = parsed.amount {
                    amountText = "\(parsedAmount)"
                }
                if let parsedDue = parsed.dueDate {
                    dueDate = parsedDue
                }
            }
        }
    }

    private func discardPendingEmail() {
        guard let key = coordinator.pendingEmailKey, !isRemoving else { return }
        isRemoving = true
        let accounts = services.accounts
        let emailIn = services.emailIn
        Task {
            await pendingMonitor.dismiss(key: key, accounts: accounts, emailIn: emailIn)
            coordinator.pendingEmailKey = nil
            coordinator.pendingImageData = nil
            coordinator.parsed = nil
            isRemoving = false
            if hasCompletedOnboarding {
                coordinator.advance(to: .done)
            } else {
                coordinator.isAddingSubsequentBill = false
                coordinator.advance(to: .secondBill)
            }
        }
    }
}
