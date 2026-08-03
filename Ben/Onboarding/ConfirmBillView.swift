import SwiftData
import SwiftUI

/// S6 — confirm. The amount is the hero; nothing saves without a once-over.
struct ConfirmBillView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(PendingEmailMonitor.self) private var pendingMonitor
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var issuer = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var payment = PaymentDetails()
    @State private var installments: [InstallmentDraft]?
    @State private var showSplitSheet = false
    @State private var showRemoveConfirm = false
    @State private var isRemoving = false

    private var amount: Decimal? {
        CurrencyAmountField.decimal(from: amountText)
    }

    private var isSplit: Bool { installments != nil }

    /// Forwarded mail still on the shelf — can be dropped without tracking.
    private var canRemovePendingEmail: Bool {
        coordinator.pendingEmailKey != nil && !coordinator.isSampleWalkthrough
    }

    var body: some View {
        BenScreen {
            // Hero: the number you're about to trust Ben with.
            VStack(alignment: .center, spacing: 6) {
                if let installments, let first = installments.first {
                    Text(first.amount.formatted(.currency(code: "AUD")))
                        .font(.benHeroAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.forestInk)
                    Text("First of \(installments.count) instalments")
                        .font(.benBody)
                        .foregroundStyle(Color.forestInk.opacity(0.65))
                } else {
                    Text((amount ?? 0).formatted(.currency(code: "AUD")))
                        .font(.benHeroAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.forestInk)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.3), value: amount)
                    Text(issuer.isEmpty ? "New bill" : issuer)
                        .font(.benBody)
                        .foregroundStyle(Color.forestInk.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 12) {
                BenVoiceText(
                    text: isSplit
                        ? "Each instalment becomes its own reminder. Give the list a once-over."
                        : "Give this a once-over so everything stays accurate. I'd rather be checked than wrong.",
                    quiet: true
                )
                .foregroundStyle(Color.forestInk.opacity(0.65))
            }
            .padding(.bottom, 12)

            VStack(spacing: 12) {
                BenField("From") {
                    TextField("Issuer", text: $issuer)
                        .accessibilityIdentifier("confirm-issuer")
                }

                if let installments {
                    installmentSummary(installments)
                } else {
                    BenField("Amount") {
                        CurrencyAmountField(
                            text: $amountText,
                            accessibilityIdentifier: "confirm-amount"
                        )
                    }
                    BenField("Due date") {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            if !coordinator.isSampleWalkthrough, amount != nil {
                Button {
                    showSplitSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSplit ? "arrow.triangle.branch" : "rectangle.split.3x1")
                            .font(.body.weight(.semibold))
                        Text(isSplit ? "Edit instalments" : "Split into instalments")
                            .font(.benLabel)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.forestInk.opacity(0.45))
                    }
                    .foregroundStyle(Color.forestInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .benRowSurface(radius: 22)
                }
                .buttonStyle(BenPressable())
                .accessibilityIdentifier("Split into instalments")
                .padding(.top, 4)
            }

            PaymentApprovalFields(payment: $payment, alwaysShow: true)
                .padding(.top, 4)

            if let data = coordinator.pendingImageData {
                BillDocumentPreview(data: data)
                    .padding(.top, 8)
            }

            if coordinator.isSampleWalkthrough {
                Text("This is a sample bill. Nothing is saved.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        } cta: {
            BenPrimaryButton(
                title: coordinator.isSampleWalkthrough ? "Got it, back to my own bills" : "Looks right, track it"
            ) {
                coordinator.isSampleWalkthrough ? coordinator.endSampleWalkthrough() : confirm()
            }
            .disabled(!coordinator.isSampleWalkthrough && (issuer.isEmpty || amount == nil))
            .opacity(!coordinator.isSampleWalkthrough && (issuer.isEmpty || amount == nil) ? 0.45 : 1)

            if canRemovePendingEmail {
                BenTextButton(title: isRemoving ? "Removing…" : "Remove") {
                    showRemoveConfirm = true
                }
                .disabled(isRemoving)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("Remove pending email bill")
            }
        }
        .onAppear(perform: prefill)
        .alert("Remove this bill?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) { discardPendingEmail() }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text("It won't be tracked, and it'll leave your waiting list.")
        }
        .sheet(isPresented: $showSplitSheet) {
            if let amount {
                InstallmentSplitSheet(
                    total: amount,
                    initialFirstDue: dueDate,
                    onApply: { installments = $0 },
                    onClear: { installments = nil }
                )
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .presentationBackground(Color.forestBottom)
            }
        }
    }

    private func installmentSummary(_ rows: [InstallmentDraft]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BenEyebrow(text: "\(rows.count) instalments · total \((amount ?? 0).formatted(.currency(code: "AUD")))")
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text("\(index + 1)")
                        .font(.benLabel)
                        .foregroundStyle(Color.onChartreuse)
                        .frame(width: 28, height: 28)
                        .background(Color.chartreuse, in: Circle())
                    Text(row.amount.formatted(.currency(code: "AUD")))
                        .font(.benCardTitle)
                        .foregroundStyle(Color.forestInk)
                    Spacer()
                    Text(row.dueDate.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .benRowSurface(radius: 24)
    }

    private func prefill() {
        guard let parsed = coordinator.parsed else { return }
        issuer = parsed.issuer ?? ""
        if let parsedAmount = parsed.amount {
            amountText = "\(parsedAmount)"
        }
        if let parsedDue = parsed.dueDate {
            dueDate = parsedDue
        }
        payment = parsed.payment
    }

    private func confirm() {
        guard let amount else { return }
        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespaces)
        let draftsToSave: [InstallmentDraft]
        if let installments, installments.count > 1 {
            draftsToSave = installments
        } else {
            draftsToSave = [InstallmentDraft(amount: amount, dueDate: dueDate)]
        }
        let totalCount = draftsToSave.count

        var saved: [Bill] = []
        for (index, draft) in draftsToSave.enumerated() {
            let note: String
            if totalCount > 1 {
                note = "Instalment \(index + 1) of \(totalCount) · of \(amount.formatted(.currency(code: "AUD")))"
            } else {
                note = ""
            }
            let bill = Bill(
                issuer: trimmedIssuer,
                amount: draft.amount,
                dueDate: draft.dueDate,
                sourceImageData: coordinator.pendingImageData,
                notes: note,
                uploadMethod: coordinator.uploadMethod.rawValue
            )
            bill.category = BillCategories.category(forIssuer: bill.issuer)
            bill.bpayBillerCode = digitsOnly(payment.bpayBillerCode)
            bill.bpayReference = digitsOnly(payment.bpayReference)
            bill.bankBSB = digitsOnly(payment.bsb)
            bill.bankAccount = digitsOnly(payment.accountNumber)
            bill.eftReference = digitsOnly(payment.eftReference)
            modelContext.insert(bill)
            saved.append(bill)
        }
        try? modelContext.save()

        let allBills = (try? modelContext.fetch(FetchDescriptor<Bill>())) ?? []
        // A second bill arriving cancels the promised day-4 nudge.
        // Instalment splits of the first upload still count as activation #1's family —
        // only cancel once there's a distinct second upload (count > instalment batch).
        if allBills.count >= 2, saved.count == 1 {
            services.scheduler.cancel(identifiers: ["second-bill-day4"])
        } else if allBills.count > saved.count {
            services.scheduler.cancel(identifiers: ["second-bill-day4"])
        }
        services.analytics.track(
            .billUploadCompleted(
                billCountAfterUpload: allBills.count,
                isFirstBill: allBills.count == saved.count,
                isSecondBill: allBills.count - saved.count == 1 && saved.count == 1,
                uploadMethod: coordinator.uploadMethod.rawValue,
                hasNotification: false  // set in S7; tracked before scheduling by design
            )
        )

        // An emailed bill is confirmed — clear the shelf immediately, then claim.
        if let key = coordinator.pendingEmailKey {
            coordinator.pendingEmailKey = nil
            pendingMonitor.removeLocally(key: key)
            let accounts = services.accounts
            let emailIn = services.emailIn
            Task {
                await pendingMonitor.claimAfterConfirm(
                    key: key, accounts: accounts, emailIn: emailIn
                )
            }
        }

        let soonest = saved.min(by: { $0.dueDate < $1.dueDate }) ?? saved[0]
        coordinator.confirmedBills = saved
        coordinator.confirmedBill = soonest
        coordinator.advance(to: .reminderSetup)
    }

    /// Drop a forwarded attachment without saving — same as × on Home.
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

    private func digitsOnly(_ value: String?) -> String {
        (value ?? "").filter(\.isNumber)
    }
}
