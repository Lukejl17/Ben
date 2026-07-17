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

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        BenScreen {
            // Hero: the number you're about to trust Ben with.
            VStack(alignment: .center, spacing: 6) {
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
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 12) {
                BenVoiceText(
                    text: "Give this a once-over so everything stays accurate. I'd rather be checked than wrong.",
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
        let bill = Bill(
            issuer: issuer.trimmingCharacters(in: .whitespaces),
            amount: amount,
            dueDate: dueDate,
            sourceImageData: coordinator.pendingImageData,
            uploadMethod: coordinator.uploadMethod.rawValue
        )
        bill.category = BillCategories.category(forIssuer: bill.issuer)
        bill.bpayBillerCode = digitsOnly(payment.bpayBillerCode)
        bill.bpayReference = digitsOnly(payment.bpayReference)
        bill.bankBSB = digitsOnly(payment.bsb)
        bill.bankAccount = digitsOnly(payment.accountNumber)
        bill.eftReference = digitsOnly(payment.eftReference)
        modelContext.insert(bill)
        try? modelContext.save()

        let allBills = (try? modelContext.fetch(FetchDescriptor<Bill>())) ?? []
        // A second bill arriving cancels the promised day-4 nudge.
        if allBills.count >= 2 {
            services.scheduler.cancel(identifiers: ["second-bill-day4"])
        }
        services.analytics.track(
            .billUploadCompleted(
                billCountAfterUpload: allBills.count,
                isFirstBill: allBills.count == 1,
                isSecondBill: allBills.count == 2,
                uploadMethod: coordinator.uploadMethod.rawValue,
                hasNotification: false  // set in S7; tracked before scheduling by design
            )
        )

        coordinator.confirmedBill = bill
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
