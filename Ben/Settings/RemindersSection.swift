import SwiftData
import SwiftUI

/// Settings · Reminders: delivery time + quiet weekends. Changing either
/// reschedules every live reminder to match — no stale 9am ghosts.
struct RemindersSection: View {
    @Environment(\.services) private var services
    @Query private var bills: [Bill]

    @AppStorage(ReminderPrefs.hourKey) private var deliveryHour = 9
    @AppStorage(ReminderPrefs.quietWeekendsKey) private var quietWeekends = false

    private let slots: [(label: String, hour: Int)] = [
        ("Morning · 9am", 9), ("Lunch · 12pm", 12), ("Evening · 6pm", 18)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                BenEyebrow(text: "Delivery time", color: Color.forestInk.opacity(0.55))
                Text("When Ben speaks, this is when he knocks.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.6))
                    .padding(.top, 2)
                HStack(spacing: 8) {
                    ForEach(slots, id: \.hour) { slot in
                        chip(slot.label, isSelected: deliveryHour == slot.hour) {
                            deliveryHour = slot.hour
                            rescheduleEverything()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .benRowSurface(radius: 24)

            Toggle(isOn: $quietWeekends) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quiet weekends")
                        .font(.benCardTitle)
                        .foregroundStyle(Color.forestInk)
                    Text("Weekend reminders wait until Monday.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.55))
                }
            }
            .tint(.chartreuse)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .benRowSurface(radius: 24)
            .onChange(of: quietWeekends) { _, _ in
                rescheduleEverything()
            }
        }
    }

    private func chip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.benLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color.onChartreuse : Color.forestInk)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(isSelected ? Color.chartreuse : Color.rowFill, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.rowStroke, lineWidth: 1.5))
        }
        .buttonStyle(BenPressable())
    }

    /// Cancel + re-issue every live bill reminder under the new preferences.
    private func rescheduleEverything() {
        let scheduler = services.scheduler
        let live = bills.filter { $0.paidAt == nil && $0.hasNotification }
        for bill in live {
            let oldIDs = bill.notificationIDs.filter { $0.hasPrefix("bill-") && !$0.contains("-overdue-") }
            let style = ReminderStyle(rawValue: bill.reminderStyleRaw) ?? .fewDaysEarly
            let billID = bill.uuid
            let issuer = bill.issuer
            let amount = bill.amount
            let dueDate = bill.dueDate
            Task {
                scheduler.cancel(identifiers: oldIDs)
                let newIDs = await scheduler.scheduleReminders(
                    billID: billID, issuer: issuer, amount: amount, dueDate: dueDate, style: style
                )
                bill.notificationIDs.removeAll { oldIDs.contains($0) }
                bill.notificationIDs.append(contentsOf: newIDs)
            }
        }
    }
}
