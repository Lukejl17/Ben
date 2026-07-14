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
                        wash: BillCategories.wash(forIssuer: bill.issuer),
                        size: 56
                    )
                    Text(bill.amount.formatted(.currency(code: "AUD")))
                        .font(.benHeroAmount)
                        .monospacedDigit()
                        .foregroundStyle(Color.benInk)
                    Text(bill.issuer)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.benInkSecondary)
                    StatusPill(status: bill.status)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
                .padding(.bottom, 8)

                BenCard {
                    HStack(spacing: 14) {
                        BenIconCircle(systemName: "calendar", wash: (.washAmberBg, .washAmberFg), size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Due \(bill.dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))")
                                .font(.benCardTitle)
                                .foregroundStyle(Color.benInk)
                            Text(bill.hasNotification
                                 ? "Reminder set — I'll mention it when it matters."
                                 : "No reminder for this one — it stays visible here.")
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkMuted)
                        }
                    }
                }

                Button {
                    showCategoryPicker = true
                } label: {
                    HStack(spacing: 14) {
                        BenIconCircle(
                            systemName: BillCategory.symbol(for: bill.resolvedCategory),
                            wash: BillCategory.wash(for: bill.resolvedCategory),
                            size: 40
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(BillCategory.label(for: bill.resolvedCategory))
                                .font(.benCardTitle)
                                .foregroundStyle(Color.benInk)
                            Text("Category — used in Insights")
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.benInkMuted)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.benCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(BenPressable())
                .benShadow(.card)

                if let data = bill.sourceImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .benShadow(.card)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(bill: bill)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .presentationBackground(Color.benCanvas)
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
