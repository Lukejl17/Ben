import SwiftUI

/// Lets the user turn one OCR total into several instalments before saving.
/// Common for council rates: one yearly notice, four due dates.
struct InstallmentSplitSheet: View {
    let total: Decimal
    let initialFirstDue: Date
    var onApply: ([InstallmentDraft]) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var count = 4
    @State private var monthsApart = 3
    @State private var drafts: [InstallmentDraft] = []

    private var sum: Decimal { InstallmentSplitter.sum(drafts) }
    private var sumsMatch: Bool { sum == total }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Split into instalments")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                BenVoiceText(
                    text: "Some bills arrive as one total but pay in parts. Set each part here — nothing saves until you confirm.",
                    quiet: true
                )
                .padding(.bottom, 4)

                Text("TOTAL")
                    .font(.benEyebrow)
                    .tracking(1.6)
                    .foregroundStyle(Color.forestInk.opacity(0.55))
                Text(total.formatted(.currency(code: "AUD")))
                    .font(.benCardTitle)
                    .foregroundStyle(Color.forestInk)
                    .padding(.bottom, 4)

                Text("HOW MANY")
                    .font(.benEyebrow)
                    .tracking(1.6)
                    .foregroundStyle(Color.forestInk.opacity(0.55))
                HStack(spacing: 8) {
                    ForEach([2, 3, 4], id: \.self) { countOption in
                        countChip(countOption)
                    }
                }

                Text("SPACING")
                    .font(.benEyebrow)
                    .tracking(1.6)
                    .foregroundStyle(Color.forestInk.opacity(0.55))
                    .padding(.top, 4)
                HStack(spacing: 8) {
                    spacingChip(label: "Monthly", months: 1)
                    spacingChip(label: "Every 3 months", months: 3)
                }

                VStack(spacing: 10) {
                    ForEach($drafts) { $draft in
                        installmentRow($draft, index: drafts.firstIndex(where: { $0.id == draft.id }) ?? 0)
                    }
                }
                .padding(.top, 6)

                if !sumsMatch {
                    Text("Parts add up to \(sum.formatted(.currency(code: "AUD"))). Adjust so they match the total.")
                        .font(.benMeta)
                        .foregroundStyle(Color.statusLateFg)
                }

                BenPrimaryButton(title: "Use these instalments") {
                    onApply(drafts)
                    dismiss()
                }
                .disabled(!sumsMatch || drafts.isEmpty)
                .opacity(!sumsMatch || drafts.isEmpty ? 0.45 : 1)
                .padding(.top, 8)

                Button {
                    onClear()
                    dismiss()
                } label: {
                    Text("Keep as one bill")
                        .font(.benLabel)
                        .foregroundStyle(Color.forestInk.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(BenPressable())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .benKeyboardDoneToolbar()
        .benSheetClose()
        .onAppear { rebuildDrafts() }
    }

    private func countChip(_ countOption: Int) -> some View {
        let selected = count == countOption
        return Button {
            count = countOption
            rebuildDrafts()
        } label: {
            Text("\(countOption)")
                .font(.benLabel)
                .foregroundStyle(selected ? Color.onChartreuse : Color.forestInk)
                .frame(width: 52, height: 40)
                .background(selected ? Color.chartreuse : Color.cream.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.cream.opacity(selected ? 0 : 0.22), lineWidth: 1))
        }
        .buttonStyle(BenPressable())
        .accessibilityIdentifier("instalments-\(countOption)")
    }

    private func spacingChip(label: String, months: Int) -> some View {
        let selected = monthsApart == months
        return Button {
            monthsApart = months
            rebuildDrafts()
        } label: {
            Text(label)
                .font(.benLabel)
                .foregroundStyle(selected ? Color.onChartreuse : Color.forestInk)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(selected ? Color.chartreuse : Color.cream.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.cream.opacity(selected ? 0 : 0.22), lineWidth: 1))
        }
        .buttonStyle(BenPressable())
    }

    private func installmentRow(_ draft: Binding<InstallmentDraft>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INSTALMENT \(index + 1)")
                .font(.benEyebrow)
                .tracking(1.6)
                .foregroundStyle(Color.onCreamEyebrow)
            HStack(spacing: 12) {
                TextField("Amount", text: amountBinding(draft))
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .font(.benBody)
                    .foregroundStyle(Color.onCreamStrong)
                    .padding(12)
                    .background(Color.cream.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                DatePicker("", selection: draft.dueDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.chartreuse)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, .light)
    }

    private func amountBinding(_ draft: Binding<InstallmentDraft>) -> Binding<String> {
        Binding(
            get: {
                let value = draft.wrappedValue.amount
                // Trim trailing .00 for easier editing.
                let number = NSDecimalNumber(decimal: value)
                return number.stringValue
            },
            set: { text in
                let cleaned = text.replacingOccurrences(of: ",", with: "")
                if let parsed = Decimal(string: cleaned) {
                    draft.wrappedValue.amount = parsed
                }
            }
        )
    }

    private func rebuildDrafts() {
        drafts = InstallmentSplitter.drafts(
            total: total,
            firstDue: initialFirstDue,
            count: count,
            monthsApart: monthsApart
        )
    }
}
