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
                    .foregroundStyle(Color.benInk)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: amount)
                Text(issuer.isEmpty ? "New bill" : issuer)
                    .font(.benBody)
                    .foregroundStyle(Color.benInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 12) {
                BenAvatar(size: 40)
                BenVoiceText(
                    text: "Give this a once-over so everything stays accurate. I'd rather be checked than wrong.",
                    quiet: true
                )
                .foregroundStyle(Color.benInkSecondary)
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

            if let data = coordinator.pendingImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .benShadow(.card)
                    .padding(.top, 8)
            }

            if coordinator.isSampleWalkthrough {
                Text("This is a sample bill — nothing is saved.")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkMuted)
                    .frame(maxWidth: .infinity)
            }
        } cta: {
            BenPrimaryButton(
                title: coordinator.isSampleWalkthrough ? "Got it — back to my own bills" : "Looks right — track it"
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
}
