import SwiftUI
import SwiftData

/// Translucent forest row — one bill.
struct BillRow: View {
    let bill: Bill
    var onTap: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                BenIconCircle(
                    systemName: BillCategories.symbol(forIssuer: bill.issuer),
                    fill: BillCategories.wash(forIssuer: bill.issuer).bg,
                    iconColor: BillCategories.wash(forIssuer: bill.issuer).fg
                )
                .opacity(bill.status == .paid ? 0.5 : 1)
                VStack(alignment: .leading, spacing: 0) {
                    Text(bill.issuer)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.forestInk)
                    Text("\(BillCategory.label(for: bill.resolvedCategory)) · due "
                         + bill.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(bill.amount.formatted(.currency(code: "AUD")))
                        .font(.benAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.forestInk)
                    StatusPill(status: bill.status)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(BenPressable())
        .benRowSurface(radius: 26)
        .contextMenu {
            if bill.status != .paid {
                Button("Mark as paid", systemImage: "checkmark.circle") {
                    bill.paidAt = .now
                    services.scheduler.cancel(identifiers: bill.notificationIDs)
                    bill.notificationIDs = []
                    bill.hasNotification = false
                    try? modelContext.save()
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                services.scheduler.cancel(identifiers: bill.notificationIDs)
                modelContext.delete(bill)
                try? modelContext.save()
            }
        }
    }
}
