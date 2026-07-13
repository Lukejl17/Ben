import SwiftData
import SwiftUI

/// S6 — confirm. Nothing saves without the user's explicit once-over.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    BenAvatar()
                    BenVoiceText(text: "Give this a once-over so everything stays accurate. I'd rather be checked than wrong.")
                }
                .padding(.top, 48)

                BenCard {
                    VStack(spacing: 14) {
                        LabeledContent("From") {
                            TextField("Issuer", text: $issuer)
                                .multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("confirm-issuer")
                        }
                        Divider()
                        LabeledContent("Amount") {
                            TextField("$0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.benAmount)
                                .monospacedDigit()
                                .accessibilityIdentifier("confirm-amount")
                        }
                        Divider()
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    }
                    .font(.benBody)
                }

                if let data = coordinator.pendingImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.benHairline, lineWidth: 0.5))
                }

                if coordinator.isSampleWalkthrough {
                    Text("This is a sample bill — nothing is saved.")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkMuted)
                }

                BenPrimaryButton(
                    title: coordinator.isSampleWalkthrough ? "Got it — back to my own bills" : "Looks right — track it"
                ) {
                    coordinator.isSampleWalkthrough ? coordinator.endSampleWalkthrough() : confirm()
                }
                .disabled(!coordinator.isSampleWalkthrough && (issuer.isEmpty || amount == nil))
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
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
