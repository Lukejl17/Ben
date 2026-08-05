import SwiftData
import SwiftUI

/// Per-bill reminder override: change this bill's style without touching the rest.
struct ReminderOverrideSheet: View {
    let bill: Bill

    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ReminderStyle = .fewDaysEarly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reminders for \(bill.issuer)")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                VStack(spacing: 12) {
                    ForEach(ReminderStyle.allCases, id: \.self) { style in
                        SelectablePill(
                            label: style.label, detail: style.detail, isSelected: selected == style
                        ) {
                            selected = style
                        }
                    }
                }

                Text("Just this bill. Everything else keeps your usual setup. "
                     + "Delivered at your chosen time from Settings.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            BenPrimaryButton(title: "Update reminders") {
                save()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .onAppear {
            selected = ReminderStyle(rawValue: bill.reminderStyleRaw) ?? .fewDaysEarly
        }
        .benSheetClose()
    }

    private func save() {
        let scheduler = services.scheduler
        let billID = bill.uuid
        let issuer = bill.issuer
        let amount = bill.amount
        let dueDate = bill.dueDate
        let style = selected
        let oldIDs = bill.notificationIDs.filter { $0.hasPrefix("bill-") }

        bill.reminderStyleRaw = style.rawValue
        Task {
            scheduler.cancel(identifiers: oldIDs)
            await LiveActivityManager.end(billID: billID)
            let newIDs = await scheduler.scheduleReminders(
                billID: billID, issuer: issuer, amount: amount, dueDate: dueDate, style: style
            )
            bill.notificationIDs.removeAll { oldIDs.contains($0) }
            bill.notificationIDs.append(contentsOf: newIDs)
            bill.hasNotification = !newIDs.isEmpty || bill.hasNotification
            try? modelContext.save()
            if BillDueLiveActivityPolicy.shouldPresent(
                style: style, dueDate: dueDate, paidAt: bill.paidAt
            ) {
                _ = await LiveActivityManager.start(
                    billID: billID, issuer: issuer, amount: amount, dueDate: dueDate
                )
            }
        }
        dismiss()
    }
}
