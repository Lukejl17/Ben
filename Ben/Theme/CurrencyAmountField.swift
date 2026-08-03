import SwiftUI

/// Amount entry with a permanent $ prefix (display only — value is digits).
struct CurrencyAmountField: View {
    @Binding var text: String
    var accessibilityIdentifier: String?

    var body: some View {
        HStack(spacing: 2) {
            Text("$")
                .font(.benBody)
                .foregroundStyle(Color.onCream)
            TextField("0.00", text: amountBinding)
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .accessibilityIdentifier(accessibilityIdentifier ?? "amount")
        }
    }

    private var amountBinding: Binding<String> {
        Binding(
            get: {
                text
                    .replacingOccurrences(of: "$", with: "")
                    .trimmingCharacters(in: .whitespaces)
            },
            set: { newValue in
                text = newValue
                    .replacingOccurrences(of: "$", with: "")
                    .filter { $0.isNumber || $0 == "." || $0 == "," }
            }
        )
    }

    /// Parse the field into a Decimal, ignoring $ and commas.
    static func decimal(from text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }
}
