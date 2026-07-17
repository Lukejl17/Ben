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
    @State private var selectedAngle: Double?
    @State private var calloutSlice: CategorySlice?
    @State private var calloutHideTask: Task<Void, Never>?

    struct DrillTarget: Identifiable {
        let category: String
        var id: String { category }
    }

    /// Slice colours: ranked position → earthy palette (distinct, no reds).
    static let palette: [Color] = [
        .chartreuse, .amber, .lavender, .sky, .clay, .cream,
        Color.forestInk.opacity(0.45)
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
                        Text("Insights")
                            .font(.benTitle)
                            .foregroundStyle(Color.chartreuse)
                            .padding(.top, 18)
                            .accessibilityAddTraits(.isHeader)
                        periodChips

                        // Above the fold — toggling it visibly changes the chart.
                        HStack {
                            Text("Include unpaid bills")
                                .font(.benLabel)
                                .foregroundStyle(Color.forestInk.opacity(0.65))
                            Spacer()
                            Toggle("Include unpaid bills", isOn: $includeUnpaid)
                                .labelsHidden()
                                .tint(.chartreuse)
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
                                    BenVoiceText(text: line, quiet: true)
                                        .foregroundStyle(Color.forestInk.opacity(0.65))
                                }
                                .padding(.vertical, 4)
                            }
                            categoryRows(slices: result.slices)
                        }

                        Text(includeUnpaid
                             ? "Showing money paid in the window plus everything still owing."
                             : "Showing only money already paid.")
                            .font(.benMeta)
                            .foregroundStyle(Color.forestInk.opacity(0.5))
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(.chartreuse)
        .sheet(item: $drillCategory) { target in
            CategoryBillsSheet(
                category: target.category,
                period: period,
                includeUnpaid: includeUnpaid
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
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
                        .foregroundStyle(isSelected ? Color.onChartreuse : Color.forestInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isSelected ? Color.chartreuse : Color.rowFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.rowStroke, lineWidth: 1.5))
                }
                .buttonStyle(BenPressable())
                .benShadow(.floating)
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
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, angle in
            guard let angle else { return }
            showCallout(for: angle, in: result.slices)
        }
        .overlay(alignment: .top) {
            if let slice = calloutSlice,
               let index = result.slices.firstIndex(where: { $0.category == slice.category }) {
                donutCallout(slice: slice, total: result.total,
                             color: Self.palette[index % Self.palette.count])
                    .offset(y: -10)
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: calloutSlice?.category)
        .frame(height: 240)
        .chartBackground { _ in
            // The hole is ~64% of the 240pt chart: keep the number inside it
            // whatever its length ($243 through $12,345.67).
            VStack(spacing: 2) {
                Text(result.total.formatted(.currency(code: "AUD")))
                    .font(.baloo("Baloo2-ExtraBold", 28, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(Color.forestInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(period == .all ? "all time" : "last \(period.label.lowercased())")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
            }
            .frame(maxWidth: 128)
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
                                .foregroundStyle(Color.forestInk)
                            Text(slice.billCount == 1 ? "1 bill" : "\(slice.billCount) bills")
                                .font(.benMeta)
                                .foregroundStyle(Color.forestInk.opacity(0.5))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(slice.total.formatted(.currency(code: "AUD")))
                                .font(.benLabel)
                                .monospacedDigit()
                                .foregroundStyle(Color.forestInk)
                            Text("\(Int((slice.share * 100).rounded()))%")
                                .font(.benMeta)
                                .foregroundStyle(Color.forestInk.opacity(0.5))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.forestInk.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(BenPressable())
                .benRowSurface(radius: 22)
            }
        }
    }

    /// Maps a tapped angle back to its slice and shows the mini callout.
    private func showCallout(for angle: Double, in slices: [CategorySlice]) {
        var running = 0.0
        for slice in slices {
            running += (slice.total as NSDecimalNumber).doubleValue
            if angle <= running {
                calloutSlice = slice
                break
            }
        }
        calloutHideTask?.cancel()
        calloutHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { calloutSlice = nil }
        }
    }

    /// The little widget that pops over the donut when a segment is tapped.
    private func donutCallout(slice: CategorySlice, total: Decimal, color: Color) -> some View {
        let share = (total as NSDecimalNumber).doubleValue > 0
            ? (slice.total as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue
            : 0
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(BillCategory.label(for: slice.category))
                .font(.baloo("Baloo2-Bold", 14, relativeTo: .footnote))
                .foregroundStyle(Color.onCream)
            Text(slice.total.formatted(.currency(code: "AUD")))
                .font(.benLabel)
                .monospacedDigit()
                .foregroundStyle(Color.onCreamStrong)
            Text(share.formatted(.percent.precision(.fractionLength(0))))
                .font(.benMeta)
                .foregroundStyle(Color.onCreamMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.cream, in: Capsule())
        .benShadow(.cream)
        .environment(\.colorScheme, .light)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            BenCharacter(size: 120)
            BenVoiceText(
                text: "Nothing due in this window yet. Once a few bills land, I'll show you where the money goes.",
                quiet: true
            )
            .foregroundStyle(Color.forestInk.opacity(0.65))
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
                        fill: BillCategory.wash(for: category).bg,
                        iconColor: BillCategory.wash(for: category).fg
                    )
                    Text(BillCategory.label(for: category))
                        .font(.benTitle)
                        .foregroundStyle(Color.forestInk)
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
