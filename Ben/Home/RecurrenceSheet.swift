import SwiftData
import SwiftUI

/// Set how often a bill comes around. Asked once after paying (the natural
/// moment), editable any time from the bill detail.
struct RecurrenceSheet: View {
    let bill: Bill
    var context: Context = .edit

    enum Context {
        case afterPaid, edit
    }

    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selected: BillRecurrence = .none

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(context == .afterPaid ? "Nice — that's sorted" : "How often?")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                BenVoiceText(
                    text: context == .afterPaid
                        ? "Does \(bill.issuer) come around regularly? Tell me once and I'll expect the next one for you."
                        : "How often does \(bill.issuer) come around?",
                    quiet: true
                )
                .padding(.bottom, 6)

                VStack(spacing: 12) {
                    ForEach(BillRecurrence.allCases, id: \.self) { option in
                        SelectablePill(
                            label: option.label,
                            detail: option.detail,
                            isSelected: selected == option
                        ) {
                            selected = option
                        }
                    }
                }

                if selected != .none, let next = nextDate {
                    Text("I'll give you a quiet heads-up around \(next.formatted(.dateTime.day().month(.wide))).")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            BenPrimaryButton(title: selected == .none ? "No worries" : "Expect it") {
                save()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .onAppear {
            selected = BillRecurrence(rawValue: bill.recurrence) ?? .none
        }
    }

    private var nextDate: Date? {
        ExpectedBills.nextDate(after: bill.dueDate, recurrence: selected, now: .now)
    }

    private func save() {
        bill.recurrence = selected.rawValue
        try? modelContext.save()

        let scheduler = services.scheduler
        let headsUpID = "expect-\(bill.uuid)"
        scheduler.cancel(identifiers: [headsUpID])
        if selected != .none, let next = nextDate {
            let expectation = ExpectedBill(
                sourceBillUUID: bill.uuid,
                issuer: bill.issuer,
                category: bill.resolvedCategory,
                estimatedAmount: bill.amount,
                expectedDate: next
            )
            Task { await scheduler.scheduleExpectedHeadsUp(expectation: expectation) }
        }
        dismiss()
    }
}
