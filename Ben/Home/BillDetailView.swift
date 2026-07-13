import SwiftData
import SwiftUI

/// Where a tapped reminder lands: the bill, plainly.
struct BillDetailView: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bill.issuer)
                            .font(.benTitle)
                            .foregroundStyle(Color.benInk)
                        Text("Due \(bill.dueDate.formatted(.dateTime.day().month(.wide).year()))")
                            .font(.benBody)
                            .foregroundStyle(Color.benInkSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(bill.amount.formatted(.currency(code: "AUD")))
                            .font(.benAmount)
                            .monospacedDigit()
                            .foregroundStyle(Color.benInk)
                        StatusPill(status: bill.status)
                    }
                }
                .padding(.top, 28)

                if bill.status != .paid {
                    BenPrimaryButton(title: "Mark as paid") {
                        bill.paidAt = .now
                        services.scheduler.cancel(identifiers: bill.notificationIDs)
                        bill.notificationIDs = []
                        bill.hasNotification = false
                        try? modelContext.save()
                        dismiss()
                    }
                }

                if let data = bill.sourceImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.benHairline, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationBackground(Color.benCanvas)
    }
}
