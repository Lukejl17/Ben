import SwiftData
import SwiftUI

/// Export bills as CSV: standard periods or a custom range, then share.
struct ExportSheet: View {
    @Query private var bills: [Bill]

    private enum Selection: String, CaseIterable {
        case week, month, year, upcoming, custom

        var label: String {
            switch self {
            case .week: "7 days"
            case .month: "30 days"
            case .year: "12 mo"
            case .upcoming: "Upcoming"
            case .custom: "Custom"
            }
        }
    }

    @State private var selection: Selection = .month
    @State private var customFrom = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customTo = Date.now

    private var period: ExportPeriod {
        switch selection {
        case .week: .last7Days
        case .month: .last30Days
        case .year: .last12Months
        case .upcoming: .upcoming
        case .custom: .custom(from: customFrom, to: customTo)
        }
    }

    private var exportRows: [BillExporter.Row] {
        BillExporter.rows(
            in: period,
            from: bills.map { bill in
                BillExporter.Row(
                    issuer: bill.issuer,
                    category: bill.resolvedCategory,
                    amount: bill.amount,
                    dueDate: bill.dueDate,
                    paidAt: bill.paidAt,
                    status: bill.status.label,
                    uploadMethod: bill.uploadMethod,
                    createdAt: bill.createdAt
                )
            }
        )
    }

    private var exportURL: URL? {
        let rows = exportRows
        guard !rows.isEmpty else { return nil }
        return try? BillExporter.writeTempFile(csv: BillExporter.csv(for: rows))
    }

    private var totalLine: String {
        let total = exportRows.reduce(Decimal.zero) { $0 + $1.amount }
        let count = exportRows.count
        let bills = count == 1 ? "1 bill" : "\(count) bills"
        return "\(bills) · \(total.formatted(.currency(code: "AUD")))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Export bills")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                Text("A tidy CSV — opens in Numbers, Excel, or lands straight in an email to your accountant.")
                    .font(.benBody)
                    .foregroundStyle(Color.forestInk.opacity(0.65))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Selection.allCases, id: \.self) { option in
                            chip(option)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
                .padding(.top, 4)

                if selection == .custom {
                    HStack(spacing: 10) {
                        BenField("From") {
                            DatePicker("", selection: $customFrom, displayedComponents: .date)
                                .labelsHidden()
                        }
                        BenField("To") {
                            DatePicker("", selection: $customTo, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }

                // Preview widget: what the file will hold.
                VStack(alignment: .leading, spacing: 2) {
                    BenEyebrow(text: "In this export", color: Color.forestInk.opacity(0.55))
                    Text(totalLine)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.forestInk)
                        .padding(.top, 4)
                    Text("Issuer, category, amount, due date, status, paid date.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.55))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .benRowSurface(radius: 24)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if let url = exportURL {
                    ShareLink(item: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share CSV")
                        }
                        .font(.benLabel)
                        .foregroundStyle(Color.onChartreuse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.chartreuse, in: Capsule())
                    }
                    .benShadow(.glow)
                } else {
                    Text("No bills in this window — widen the range and they'll appear here.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .benSheetClose()
    }

    private func chip(_ option: Selection) -> some View {
        let isSelected = selection == option
        return Button {
            withAnimation(.spring(duration: 0.3)) { selection = option }
        } label: {
            Text(option.label)
                .font(.benLabel)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.onChartreuse : Color.forestInk)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isSelected ? Color.chartreuse : Color.rowFill, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.rowStroke, lineWidth: 1.5))
        }
        .buttonStyle(BenPressable())
        .accessibilityLabel(option.label)
    }
}
