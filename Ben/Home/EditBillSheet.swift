import SwiftData
import SwiftUI

/// Edit every field on a tracked bill. Category / recurrence / reminders stay
/// on their own sheets from detail; this covers the bill itself.
struct EditBillSheet: View {
    let bill: Bill

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var issuer = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now
    @State private var notes = ""
    @State private var payment = PaymentDetails()

    private var amount: Decimal? {
        CurrencyAmountField.decimal(from: amountText)
    }

    private var canSave: Bool {
        !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit bill")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                BenVoiceText(
                    text: "Change anything that needs a tidy-up. Reminders follow the due date.",
                    quiet: true
                )
                .foregroundStyle(Color.forestInk.opacity(0.65))

                VStack(spacing: 12) {
                    BenField("From") {
                        TextField("Issuer", text: $issuer)
                            .accessibilityIdentifier("edit-issuer")
                    }
                    BenField("Amount") {
                        CurrencyAmountField(
                            text: $amountText,
                            accessibilityIdentifier: "edit-amount"
                        )
                    }
                    BenField("Due date") {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    BenField("Notes") {
                        TextField("Optional", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .accessibilityIdentifier("edit-notes")
                    }
                }

                PaymentApprovalFields(payment: $payment, alwaysShow: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .benKeyboardDoneToolbar()
        .safeAreaInset(edge: .bottom) {
            BenPrimaryButton(title: "Save changes") { save() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .onAppear(perform: prefill)
        .benSheetClose()
    }

    private func prefill() {
        issuer = bill.issuer
        amountText = "\(bill.amount)"
        dueDate = bill.dueDate
        notes = bill.notes
        payment = PaymentDetails(
            bpayBillerCode: bill.bpayBillerCode.isEmpty ? nil : bill.bpayBillerCode,
            bpayReference: bill.bpayReference.isEmpty ? nil : bill.bpayReference,
            bsb: bill.bankBSB.isEmpty ? nil : bill.bankBSB,
            accountNumber: bill.bankAccount.isEmpty ? nil : bill.bankAccount,
            eftReference: bill.eftReference.isEmpty ? nil : bill.eftReference
        )
    }

    private func save() {
        guard let amount else { return }
        let trimmed = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousIssuer = bill.issuer
        let dueChanged = !Calendar.current.isDate(bill.dueDate, inSameDayAs: dueDate)
        let issuerChanged = previousIssuer != trimmed

        bill.issuer = trimmed
        bill.amount = amount
        bill.dueDate = dueDate
        bill.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        bill.bpayBillerCode = digitsOnly(payment.bpayBillerCode)
        bill.bpayReference = digitsOnly(payment.bpayReference)
        bill.bankBSB = digitsOnly(payment.bsb)
        bill.bankAccount = digitsOnly(payment.accountNumber)
        bill.eftReference = digitsOnly(payment.eftReference)
        if issuerChanged {
            let wasInferred = bill.category.isEmpty
                || bill.category == BillCategories.category(forIssuer: previousIssuer)
            if wasInferred {
                bill.category = BillCategories.category(forIssuer: trimmed)
            }
        }

        try? modelContext.save()

        if bill.hasNotification, dueChanged || issuerChanged {
            rescheduleReminders()
        }
        dismiss()
    }

    private func rescheduleReminders() {
        let style = ReminderStyle(rawValue: bill.reminderStyleRaw) ?? .fewDaysEarly
        let oldIDs = bill.notificationIDs.filter { $0.hasPrefix("bill-") }
        let billID = bill.uuid
        let issuer = bill.issuer
        let due = bill.dueDate
        let scheduler = services.scheduler
        Task {
            scheduler.cancel(identifiers: oldIDs)
            let newIDs = await scheduler.scheduleReminders(
                billID: billID, issuer: issuer, dueDate: due, style: style
            )
            bill.notificationIDs.removeAll { oldIDs.contains($0) }
            bill.notificationIDs.append(contentsOf: newIDs)
            bill.hasNotification = !bill.notificationIDs.isEmpty
            try? modelContext.save()
        }
    }

    private func digitsOnly(_ value: String?) -> String {
        (value ?? "").filter(\.isNumber)
    }
}
