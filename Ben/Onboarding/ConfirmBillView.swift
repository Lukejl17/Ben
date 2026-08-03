import SwiftData
import SwiftUI

/// S6 — confirm. The amount is the hero; nothing saves without a once-over.
struct ConfirmBillView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext

    @State private var issuer = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var payment = PaymentDetails()
    @State private var installments: [InstallmentDraft]?
    @State private var showSplitSheet = false

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var isSplit: Bool { installments != nil }

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
                        TextField("$0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .monospacedDigit()
                            .accessibilityIdentifier("confirm-amount")
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

            if !payment.isEmpty {
                PaymentApprovalFields(payment: $payment)
                    .padding(.top, 4)
            }

            if let data = coordinator.pendingImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .benShadow(.floating)
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
        }
        .onAppear(perform: prefill)
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

        // An emailed bill is confirmed — clear it off the mailroom shelf.
        if let key = coordinator.pendingEmailKey {
            coordinator.pendingEmailKey = nil
            let accounts = services.accounts
            let emailIn = services.emailIn
            Task {
                if let token = try? await accounts.idToken() {
                    try? await emailIn.claim(key: key, idToken: token)
                }
            }
        }

        let soonest = saved.min(by: { $0.dueDate < $1.dueDate }) ?? saved[0]
        coordinator.confirmedBills = saved
        coordinator.confirmedBill = soonest
        coordinator.advance(to: .reminderSetup)
    }

    private func digitsOnly(_ value: String?) -> String {
        (value ?? "").filter(\.isNumber)
    }
}

/// The payment block found on the scan, shown for a once-over before it's
/// saved. Anything wrong can be edited or cleared right here.
private struct PaymentApprovalFields: View {
    @Binding var payment: PaymentDetails

    var body: some View {
        BenCard {
            VStack(alignment: .leading, spacing: 10) {
                BenEyebrow(text: "Payment details \u{00b7} check these")
                Text("Found on the bill. I'll keep them handy for when you pay.")
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
                if payment.bpayBillerCode != nil || payment.bpayReference != nil {
                    approvalField("BPAY biller code", binding(\.bpayBillerCode))
                    approvalField("BPAY reference", binding(\.bpayReference))
                }
                if payment.bsb != nil {
                    approvalField("BSB", binding(\.bsb))
                    approvalField("Account number", binding(\.accountNumber))
                    approvalField("Payment reference", binding(\.eftReference))
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<PaymentDetails, String?>) -> Binding<String> {
        Binding(
            get: { payment[keyPath: keyPath] ?? "" },
            set: { payment[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func approvalField(_ label: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.benMeta)
                .foregroundStyle(Color.onCreamMuted)
                .frame(width: 118, alignment: .leading)
            TextField("Not on the bill", text: text)
                .font(.benLabel)
                .monospacedDigit()
                .keyboardType(.numberPad)
                .foregroundStyle(Color.onCream)
                .accessibilityIdentifier("payment-\(label)")
        }
        .padding(.vertical, 2)
    }
}
