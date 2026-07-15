import SwiftData
import SwiftUI

/// Where a tapped reminder lands: the bill, plainly. Amount is the hero.
struct BillDetailView: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var showCategoryPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .center, spacing: 10) {
                    BenIconCircle(
                        systemName: BillCategories.symbol(forIssuer: bill.issuer),
                        fill: BillCategories.wash(forIssuer: bill.issuer).bg,
                        iconColor: BillCategories.wash(forIssuer: bill.issuer).fg,
                        size: 56
                    )
                    Text(bill.amount.formatted(.currency(code: "AUD")))
                        .font(.benHeroAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.forestInk)
                    Text(bill.issuer)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.forestInk.opacity(0.65))
                    StatusPill(status: bill.status)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
                .padding(.bottom, 8)

                BenCard {
                    HStack(spacing: 14) {
                        BenIconCircle(systemName: "calendar", fill: .amber, iconColor: .onAmber, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Due \(bill.dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))")
                                .font(.benCardTitle)
                                .foregroundStyle(Color.onCream)
                            Text(bill.hasNotification
                                 ? "Reminder set — I'll mention it when it matters."
                                 : "No reminder for this one — it stays visible here.")
                                .font(.benMeta)
                                .foregroundStyle(Color.onCreamMuted)
                        }
                    }
                }

                Button {
                    showCategoryPicker = true
                } label: {
                    HStack(spacing: 14) {
                        BenIconCircle(
                            systemName: BillCategory.symbol(for: bill.resolvedCategory),
                            fill: BillCategory.wash(for: bill.resolvedCategory).bg,
                            iconColor: BillCategory.wash(for: bill.resolvedCategory).fg,
                            size: 40
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(BillCategory.label(for: bill.resolvedCategory))
                                .font(.benCardTitle)
                                .foregroundStyle(Color.onCream)
                            Text("Category — used in Insights")
                                .font(.benMeta)
                                .foregroundStyle(Color.onCreamMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.onCreamMuted)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(BenPressable())
                .benShadow(.floating)

                if let data = bill.sourceImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .benShadow(.floating)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(bill: bill)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .presentationBackground(Color.forestBottom)
        }
        .safeAreaInset(edge: .bottom) {
            if bill.status != .paid {
                BenPrimaryButton(title: "Mark as paid", systemImage: "checkmark") {
                    bill.paidAt = .now
                    services.scheduler.cancel(identifiers: bill.notificationIDs)
                    bill.notificationIDs = []
                    bill.hasNotification = false
                    try? modelContext.save()
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }
}
