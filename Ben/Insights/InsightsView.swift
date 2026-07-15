import Charts
import SwiftData
import SwiftUI

/// Insights — where the money goes. A donut of the period's bills by category,
/// a ranked list behind it. Factual, never judgmental.
struct InsightsView: View {
    @Query private var bills: [Bill]
    @State private var period: InsightsPeriod = .threeMonths
    @State private var includeUnpaid = true
    @State private var drillCategory: DrillTarget?

    struct DrillTarget: Identifiable {
        let category: String
        var id: String { category }
    }

    /// Slice colours: ranked position → earthy palette (distinct, no reds).
    static let palette: [Color] = [
        .benAccent, .washAmberFg, .washSkyFg, .washClayFg,
        .benAccentDeep, .washEucalyptusFg, .benInkMuted
    ]

    private var breakdown: (slices: [CategorySlice], total: Decimal) {
        InsightsMath.breakdown(
            bills: bills.map {
                BillEntry(category: $0.resolvedCategory, amount: $0.amount, paidAt: $0.paidAt)
            },
            period: period,
            includeUnpaid: includeUnpaid
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BenCanvas()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        periodChips

                        // Above the fold — toggling it visibly changes the chart.
                        HStack {
                            Text("Include unpaid bills")
                                .font(.benLabel)
                                .foregroundStyle(Color.benInkSecondary)
                            Spacer()
                            Toggle("Include unpaid bills", isOn: $includeUnpaid)
                                .labelsHidden()
                                .tint(.benAccent)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, -4)

                        let result = breakdown
                        if result.slices.isEmpty {
                            emptyState
                        } else {
                            donut(result: result)
                            if let line = InsightsMath.headline(slices: result.slices, period: period) {
                                HStack(alignment: .top, spacing: 12) {
                                    BenAvatar(size: 40)
                                    BenVoiceText(text: line, quiet: true)
                                        .foregroundStyle(Color.benInkSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                            categoryRows(slices: result.slices)
                        }

                        Text(includeUnpaid
                             ? "Showing money paid in the window plus everything still owing."
                             : "Showing only money already paid.")
                            .font(.benMeta)
                            .foregroundStyle(Color.benInkMuted)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Insights")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .tint(.benAccent)
        .sheet(item: $drillCategory) { target in
            CategoryBillsSheet(
                category: target.category,
                period: period,
                includeUnpaid: includeUnpaid
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.benCanvas)
        }
    }

    // MARK: Pieces

    private var periodChips: some View {
        HStack(spacing: 8) {
            ForEach(InsightsPeriod.allCases, id: \.self) { option in
                let isSelected = period == option
                Button {
                    withAnimation(.spring(duration: 0.3)) { period = option }
                } label: {
                    Text(option.chipLabel)
                        .font(.benLabel)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isSelected ? .white : Color.benInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isSelected ? Color.benAccent : Color.benCard, in: Capsule())
                }
                .buttonStyle(BenPressable())
                .benShadow(.card)
                .accessibilityLabel(option.label)
            }
        }
    }

    private func donut(result: (slices: [CategorySlice], total: Decimal)) -> some View {
        Chart(Array(result.slices.enumerated()), id: \.element.category) { index, slice in
            SectorMark(
                angle: .value("Amount", (slice.total as NSDecimalNumber).doubleValue),
                innerRadius: .ratio(0.64),
                angularInset: 2
            )
            .cornerRadius(6)
            .foregroundStyle(Self.palette[index % Self.palette.count])
        }
        .frame(height: 240)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(result.total.formatted(.currency(code: "AUD")))
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.benInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(period == .all ? "all time" : "last \(period.label.lowercased())")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkMuted)
            }
            .padding(.horizontal, 60)
        }
        .padding(.vertical, 8)
    }

    private func categoryRows(slices: [CategorySlice]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(slices.enumerated()), id: \.element.category) { index, slice in
                Button {
                    drillCategory = DrillTarget(category: slice.category)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Self.palette[index % Self.palette.count])
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(BillCategory.label(for: slice.category))
                                .font(.benLabel)
                                .foregroundStyle(Color.benInk)
                            Text(slice.billCount == 1 ? "1 bill" : "\(slice.billCount) bills")
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(slice.total.formatted(.currency(code: "AUD")))
                                .font(.benLabel)
                                .monospacedDigit()
                                .foregroundStyle(Color.benInk)
                            Text("\(Int((slice.share * 100).rounded()))%")
                                .font(.benMeta)
                                .foregroundStyle(Color.benInkMuted)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.benInkMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.benCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(BenPressable())
                .benShadow(.card)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            BenAvatar(size: 44)
            BenVoiceText(
                text: "Nothing due in this window yet. Once a few bills land, I'll show you where the money goes.",
                quiet: true
            )
            .foregroundStyle(Color.benInkSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }
}

/// Drill-down: the bills behind one slice, in the same period window.
struct CategoryBillsSheet: View {
    let category: String
    let period: InsightsPeriod
    let includeUnpaid: Bool
    @Query private var bills: [Bill]

    private var matching: [Bill] {
        bills.filter { bill in
            bill.resolvedCategory == category
                && InsightsMath.isEligible(paidAt: bill.paidAt, period: period, includeUnpaid: includeUnpaid)
        }
        .sorted { $0.dueDate > $1.dueDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    BenIconCircle(
                        systemName: BillCategory.symbol(for: category),
                        wash: BillCategory.wash(for: category)
                    )
                    Text(BillCategory.label(for: category))
                        .font(.benTitle)
                        .foregroundStyle(Color.benInk)
                }
                .padding(.top, 28)

                ForEach(matching) { bill in
                    BillRow(bill: bill)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}
