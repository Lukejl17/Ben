import SwiftUI

/// Editable payment block — used at confirm and when editing a saved bill.
/// Values stay as typed digits; empty clears the field.
struct PaymentApprovalFields: View {
    @Binding var payment: PaymentDetails
    /// When true, always show BPAY + EFT rows so the user can add details later.
    var alwaysShow = false

    private var showBpay: Bool {
        alwaysShow || payment.bpayBillerCode != nil || payment.bpayReference != nil
    }

    private var showEft: Bool {
        alwaysShow || payment.bsb != nil || payment.accountNumber != nil || payment.eftReference != nil
    }

    var body: some View {
        BenCard {
            VStack(alignment: .leading, spacing: 10) {
                BenEyebrow(text: alwaysShow ? "Payment details" : "Payment details · check these")
                Text(
                    alwaysShow
                        ? "Optional. Handy when you're ready to pay."
                        : "Found on the bill. I'll keep them handy for when you pay."
                )
                .font(.benMeta)
                .foregroundStyle(Color.onCreamMuted)
                if showBpay {
                    approvalField("BPAY biller code", binding(\.bpayBillerCode))
                    approvalField("BPAY reference", binding(\.bpayReference))
                }
                if showEft {
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
            TextField(alwaysShow ? "Optional" : "Not on the bill", text: text)
                .font(.benLabel)
                .monospacedDigit()
                .keyboardType(.numberPad)
                .foregroundStyle(Color.onCream)
                .accessibilityIdentifier("payment-\(label)")
        }
        .padding(.vertical, 2)
    }
}
