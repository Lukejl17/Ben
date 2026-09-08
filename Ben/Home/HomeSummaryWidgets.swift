import SwiftUI

/// The summary block at the top of home: cream hero + the two mini widgets.
struct HomeSummaryWidgets: View {
    let nextUp: Bill?
    let thisMonth: (total: Decimal, count: Int)
    let biggestSlice: CategorySlice?
    let onTapBill: (Bill) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let nextUp {
                heroWidget(for: nextUp)
            }
            miniRow
        }
    }

    /// The cream hero: the one bill that needs you next.
    private func heroWidget(for bill: Bill) -> some View {
        Button {
            onTapBill(bill)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    BenEyebrow(text: "Next up")
                    Spacer()
                    StatusChipOnCream(status: bill.status)
                }
                Text("\(bill.issuer) · \(BillCategory.label(for: bill.resolvedCategory))")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.onCream)
                    .padding(.top, 4)
                // Baloo's line box is tall at 46pt — pull the neighbours in.
                Text(bill.amount.formatted(.currency(code: "AUD")))
                    .font(.benHeroAmount)
                    .monospacedDigit()
                    .foregroundStyle(Color.onCreamStrong)
                    .padding(.vertical, -6)
                Text(heroDueLine(for: bill))
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cream, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(BenPressable(haptic: .light))
        .benShadow(.cream)
    }

    private func heroDueLine(for bill: Bill) -> String {
        let due = "Due \(bill.dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
        return bill.hasNotification ? due + " · reminder set" : due
    }

    /// Two supporting widgets: month total + biggest category.
    private var miniRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                BenEyebrow(text: "This month", color: Color.forestInk.opacity(0.55))
                Text(thisMonth.total.formatted(.currency(code: "AUD").precision(.fractionLength(0))))
                    .font(.baloo("Baloo2-ExtraBold", 28, relativeTo: .title))
                    .monospacedDigit()
                    .foregroundStyle(Color.chartreuse)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 6)
                Text(thisMonth.count == 1 ? "1 bill" : "\(thisMonth.count) bills")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .benRowSurface(radius: 26)

            VStack(alignment: .leading, spacing: 2) {
                BenEyebrow(text: "Biggest", color: Color.forestInk.opacity(0.55))
                if let slice = biggestSlice {
                    HStack(spacing: 10) {
                        miniDonut(share: slice.share)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int((slice.share * 100).rounded()))%")
                                .font(.baloo("Baloo2-ExtraBold", 22, relativeTo: .title2))
                                .foregroundStyle(Color.forestInk)
                            Text(BillCategory.label(for: slice.category))
                                .font(.benMeta)
                                .foregroundStyle(Color.forestInk.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .benRowSurface(radius: 26)
        }
    }

    private func miniDonut(share: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.rowStroke, lineWidth: 7)
            Circle()
                .trim(from: 0, to: share)
                .stroke(Color.chartreuse, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 44, height: 44)
    }
}
