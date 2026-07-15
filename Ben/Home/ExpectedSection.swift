import SwiftData
import SwiftUI

/// Ghost rows for bills Ben is expecting but hasn't seen: derived from
/// recurring history, resolved the moment the real bill arrives.
struct ExpectedSection: View {
    let expectations: [ExpectedBill]
    let onArrived: () -> Void
    let onStopExpecting: (ExpectedBill) -> Void

    @State private var dialogTarget: ExpectedBill?

    var body: some View {
        if !expectations.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text("Expected")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.chartreuse)
                Spacer()
                Text("Ben's watching for these")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
            }
            .padding(.horizontal, 4)
            .padding(.top, 12)

            ForEach(expectations.prefix(3)) { expectation in
                Button {
                    dialogTarget = expectation
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        BenIconCircle(
                            systemName: BillCategory.symbol(for: expectation.category),
                            fill: BillCategory.wash(for: expectation.category).bg,
                            iconColor: BillCategory.wash(for: expectation.category).fg
                        )
                        .opacity(0.55)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(expectation.issuer)
                                .font(.benCardTitle)
                                .foregroundStyle(Color.forestInk.opacity(0.8))
                            Text("Usually lands ~\(expectation.expectedDate.formatted(.dateTime.day().month(.abbreviated)))")
                                .font(.benMeta)
                                .foregroundStyle(Color.forestInk.opacity(0.5))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("~" + expectation.estimatedAmount.formatted(.currency(code: "AUD")))
                                .font(.benAmount)
                                .monospacedDigit()
                                .foregroundStyle(Color.forestInk.opacity(0.65))
                            Text("Expected")
                                .font(.benLabel)
                                .foregroundStyle(Color.forestInk.opacity(0.55))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .overlay(Capsule().strokeBorder(Color.rowStroke, lineWidth: 1.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(BenPressable())
                .background(Color.rowFill.opacity(0.5), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.rowStroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
            }
            .confirmationDialog(
                dialogTarget.map { "\($0.issuer) — expected around \($0.expectedDate.formatted(.dateTime.day().month(.wide)))" } ?? "",
                isPresented: Binding(get: { dialogTarget != nil }, set: { if !$0 { dialogTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button("It's arrived — add it now") {
                    dialogTarget = nil
                    onArrived()
                }
                Button("Stop expecting this", role: .destructive) {
                    if let target = dialogTarget {
                        onStopExpecting(target)
                    }
                    dialogTarget = nil
                }
                Button("Cancel", role: .cancel) {
                    dialogTarget = nil
                }
            }
        }
    }
}
