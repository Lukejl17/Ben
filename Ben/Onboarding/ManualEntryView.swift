import SwiftUI

/// B2 — parse failed. Three fields max, pre-filled with whatever we did get.
struct ManualEntryView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services

    @State private var issuer = ""
    @State private var amountText = ""
    @State private var dueDate = Date.now

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BenAvatar()
                BenVoiceText(text: "That one's hard to read — happens a lot. Type the basics and I've got it from here.")
            }
            .padding(.top, 48)

            BenCard {
                VStack(spacing: 14) {
                    LabeledContent("Who's it from") {
                        TextField("AGL, Telstra…", text: $issuer)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                    LabeledContent("Amount") {
                        TextField("$0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    Divider()
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                }
                .font(.benBody)
            }

            Spacer()

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
            .disabled(issuer.trimmingCharacters(in: .whitespaces).isEmpty || amount == nil)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
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
}
