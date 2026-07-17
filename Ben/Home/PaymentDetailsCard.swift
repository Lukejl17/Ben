import SwiftUI
import UIKit

/// The copy-to-pay card: every detail the bank app asks for, one tap each.
/// Ben never moves money — he just ends the squint-and-retype ritual.
struct PaymentDetailsCard: View {
    let bill: Bill

    var body: some View {
        BenCard {
            VStack(alignment: .leading, spacing: 10) {
                BenEyebrow(text: "Pay this one")
                Text("Tap a detail to copy it, then paste it straight into your banking app.")
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
                if !bill.bpayBillerCode.isEmpty {
                    CopyRow(label: "BPAY biller code", display: bill.bpayBillerCode,
                            copyValue: bill.bpayBillerCode)
                }
                if !bill.bpayReference.isEmpty {
                    CopyRow(label: "BPAY reference",
                            display: PaymentDetails.displayReference(bill.bpayReference),
                            copyValue: bill.bpayReference)
                }
                if !bill.bankBSB.isEmpty {
                    CopyRow(label: "BSB", display: PaymentDetails.displayBSB(bill.bankBSB),
                            copyValue: bill.bankBSB)
                }
                if !bill.bankAccount.isEmpty {
                    CopyRow(label: "Account", display: bill.bankAccount,
                            copyValue: bill.bankAccount)
                }
                if !bill.eftReference.isEmpty {
                    CopyRow(label: "Reference",
                            display: PaymentDetails.displayReference(bill.eftReference),
                            copyValue: bill.eftReference)
                }
            }
        }
    }
}

/// One copyable line: label, monospaced value, and a tick that confirms the
/// copy before settling back to the copy icon.
private struct CopyRow: View {
    let label: String
    let display: String
    let copyValue: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = copyValue
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(duration: 0.25)) { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.3)) { copied = false }
            }
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
                    .frame(width: 118, alignment: .leading)
                Text(display)
                    .font(.benLabel)
                    .monospacedDigit()
                    .foregroundStyle(Color.onCream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 6)
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(copied ? Color.onCreamStrong : Color.onCreamMuted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("copy-\(label)")
    }
}
