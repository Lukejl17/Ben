import Charts
import SwiftData
import SwiftUI

/// Home — the system of record, widget-first: a cream hero for the next bill,
/// a summary mini-row, then the timeline sections.
struct HomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(\.services) private var services
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @State private var showAddBill = false
    @State private var detailBill: Bill?
    @State private var fabExpanded = false

    // MARK: Derived

    /// The soonest bill that still needs paying — the hero widget's subject.
    private var nextUp: Bill? {
        bills.filter { $0.paidAt == nil }.min { $0.dueDate < $1.dueDate }
    }

    private var thisMonth: (total: Decimal, count: Int) {
        let calendar = Calendar.current
        let due = bills.filter { calendar.isDate($0.dueDate, equalTo: .now, toGranularity: .month) }
        return (due.reduce(Decimal.zero) { $0 + $1.amount }, due.count)
    }

    private var biggestSlice: CategorySlice? {
        InsightsMath.breakdown(
            bills: bills.map {
                BillEntry(category: $0.resolvedCategory, amount: $0.amount, paidAt: $0.paidAt)
            },
            period: .threeMonths,
            includeUnpaid: true
        ).slices.first
    }

    /// Home reads as a timeline: what's slipped, then this week, then this month.
    private var sections: [(title: String, bills: [Bill])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var overdue: [Bill] = [], next7: [Bill] = [], next30: [Bill] = []
        var later: [Bill] = [], paid: [Bill] = []
        for bill in bills.sorted(by: { $0.dueDate < $1.dueDate }) {
            if bill.status == .paid {
                paid.append(bill)
                continue
            }
            if bill.status == .overdue {
                overdue.append(bill)
                continue
            }
            let days = calendar.dateComponents(
                [.day], from: today, to: calendar.startOfDay(for: bill.dueDate)
            ).day ?? 0
            if days <= 7 {
                next7.append(bill)
            } else if days <= 30 {
                next30.append(bill)
            } else {
                later.append(bill)
            }
        }
        return [
            ("Overdue", overdue), ("Next 7 days", next7), ("Next 30 days", next30),
            ("Later", later), ("Paid", paid)
        ].filter { !$0.1.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BenCanvas()
                if bills.isEmpty {
                    emptyState
                } else {
                    billList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                // Scrim behind the expanded dial — tap anywhere to collapse.
                if fabExpanded {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) { fabExpanded = false }
                        }
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                AddBillDial(expanded: $fabExpanded) { method in
                    startAddBill(method: method)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .tint(.chartreuse)
        .sheet(
            isPresented: $showAddBill,
            onDismiss: { coordinator.isAddingSubsequentBill = false },
            content: {
            ZStack(alignment: .topTrailing) {
                OnboardingFlow()
                BenCircleButton(systemName: "xmark", accessibilityLabel: "Close") {
                    showAddBill = false
                }
                .padding(.top, 16)
                .padding(.trailing, 20)
            }
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        })
        .onChange(of: coordinator.step) { _, step in
            if step == .done {
                showAddBill = false
                coordinator.isAddingSubsequentBill = false
            }
        }
        .onAppear {
            // Arriving from the S10 category chip: the add flow is already staged.
            if coordinator.isAddingSubsequentBill && coordinator.step == .upload {
                showAddBill = true
            }
            handleDeepLinks()
        }
        .sheet(item: $detailBill) { bill in
            BillDetailView(bill: bill)
                .presentationCornerRadius(28)
                .presentationBackground(Color.forestBottom)
        }
        .onChange(of: notificationRouter.openBillID) { _, _ in handleDeepLinks() }
        .onChange(of: notificationRouter.addBillRequested) { _, _ in handleDeepLinks() }
    }

    /// A tapped reminder opens the relevant bill; a nudge opens the add flow.
    private func handleDeepLinks() {
        if let billID = notificationRouter.openBillID {
            notificationRouter.openBillID = nil
            if let bill = bills.first(where: { $0.uuid == billID }) {
                detailBill = bill
            }
        }
        if notificationRouter.addBillRequested {
            notificationRouter.addBillRequested = false
            startAddBill()
        }
    }

    private var billList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bills")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 18)
                    .accessibilityAddTraits(.isHeader)

                HomeSummaryWidgets(
                    nextUp: nextUp,
                    thisMonth: thisMonth,
                    biggestSlice: biggestSlice,
                    onTapBill: { detailBill = $0 }
                )

                if case .lapsed = services.subscriptions.state() {
                    Text("Your trial has ended — bills stay visible here, reminders are off.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.65))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .benRowSurface(radius: 20)
                }

                ForEach(sections, id: \.title) { section in
                    sectionHeader(title: section.title, bills: section.bills)
                        .padding(.top, 12)
                    ForEach(section.bills) { bill in
                        BillRow(bill: bill) {
                            detailBill = bill
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }

    /// Section header: title left, factual total right. No drama, even for overdue.
    private func sectionHeader(title: String, bills sectionBills: [Bill]) -> some View {
        let total = sectionBills.reduce(Decimal.zero) { $0 + $1.amount }
        return HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.benCardTitle)
                .foregroundStyle(title == "Overdue" ? Color.statusLateFg : Color.chartreuse)
            Spacer()
            Text(total.formatted(.currency(code: "AUD")))
                .font(.benMeta)
                .monospacedDigit()
                .foregroundStyle(Color.forestInk.opacity(0.5))
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            BenCharacter(size: 150)
            BenVoiceText(text: "No bills yet. Hand one over and it becomes my problem.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            BenPrimaryButton(title: "Add a bill") { startAddBill() }
                .padding(.horizontal, 60)
            Spacer()
        }
    }

    /// Photo/PDF from the dial skip the method screen and land on capture.
    /// The empty-state button passes nil and starts at the trust block instead.
    private func startAddBill(method: UploadMethod? = nil) {
        withAnimation(.spring(duration: 0.3)) { fabExpanded = false }
        coordinator.isAddingSubsequentBill = true
        coordinator.resetForSecondBill()
        if let method {
            coordinator.uploadMethod = method
            services.analytics.track(.billUploadStarted(uploadMethod: method.rawValue))
            coordinator.advance(to: .capture)
        }
        showAddBill = true
    }
}

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
        .buttonStyle(BenPressable())
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
