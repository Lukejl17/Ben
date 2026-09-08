import SwiftData
import SwiftUI

/// Home — the system of record, widget-first: a cream hero for the next bill,
/// a summary mini-row, then the timeline sections.
struct HomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(PendingEmailMonitor.self) private var pendingMonitor
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @State private var showAddBill = false
    @State private var detailBill: Bill?
    @State private var fabExpanded = false
    @State private var showEmailIn = false
    @State private var openingPendingKey: String?

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

    private var expectations: [ExpectedBill] {
        ExpectedBills.expectations(from: bills.map { bill in
            ExpectedBills.Entry(
                uuid: bill.uuid, issuer: bill.issuer, category: bill.resolvedCategory,
                amount: bill.amount, dueDate: bill.dueDate, isPaid: bill.paidAt != nil,
                recurrence: BillRecurrence(rawValue: bill.recurrence) ?? .none
            )
        })
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
                AddBillDial(
                    expanded: $fabExpanded,
                    onPick: { startAddBill(method: $0) },
                    onEmailIn: {
                        withAnimation(.spring(duration: 0.3)) { fabExpanded = false }
                        showEmailIn = true
                    }
                )
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
            syncLiveActivities()
            Task {
                await pendingMonitor.refresh(
                    accounts: services.accounts,
                    emailIn: services.emailIn,
                    parser: services.parser
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncLiveActivities()
                Task {
                    await pendingMonitor.refresh(
                        accounts: services.accounts,
                        emailIn: services.emailIn,
                        parser: services.parser
                    )
                }
            }
        }
        .sheet(item: $detailBill) { bill in
            BillDetailView(bill: bill)
                .presentationCornerRadius(28)
                .presentationBackground(Color.forestBottom)
        }
        .sheet(isPresented: $showEmailIn) {
            EmailInSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .presentationBackground(Color.forestBottom)
        }
        .onChange(of: notificationRouter.openBillID) { _, _ in handleDeepLinks() }
        .onChange(of: notificationRouter.addBillRequested) { _, _ in handleDeepLinks() }
        .onChange(of: notificationRouter.confirmEmailBillRequested) { _, requested in
            // An emailed bill is already staged on the coordinator — just present.
            guard requested else { return }
            notificationRouter.confirmEmailBillRequested = false
            showEmailIn = false
            showAddBill = true
        }
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

    /// Due-day Live Activities can't be scheduled ahead — sync whenever Home is active.
    private func syncLiveActivities() {
        let snapshot = bills.map {
            BillLiveActivitySnapshot(
                billID: $0.uuid,
                issuer: $0.issuer,
                amount: $0.amount,
                dueDate: $0.dueDate,
                paidAt: $0.paidAt,
                style: ReminderStyle(rawValue: $0.reminderStyleRaw) ?? .fewDaysEarly
            )
        }
        Task { await LiveActivityManager.sync(bills: snapshot) }
    }

    private var billList: some View {
        // List (not ScrollView) so swipe-to-remove works like Mail / Reminders.
        List {
            Text("Bills")
                .font(.benTitle)
                .foregroundStyle(Color.chartreuse)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if pendingMonitor.hasPending {
                Section {
                    ForEach(pendingMonitor.previews) { preview in
                        pendingRow(preview)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    dismissPending(preview.item.key)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Needs a look")
                            .font(.benCardTitle)
                            .foregroundStyle(Color.chartreuse)
                        Spacer()
                        Text(pendingMonitor.count == 1 ? "1 bill" : "\(pendingMonitor.count) bills")
                            .font(.benMeta)
                            .foregroundStyle(Color.forestInk.opacity(0.5))
                    }
                    .padding(.horizontal, 4)
                    .textCase(nil)
                    .accessibilityIdentifier("pending-email-approval")
                }
            }

            HomeSummaryWidgets(
                nextUp: nextUp,
                thisMonth: thisMonth,
                biggestSlice: biggestSlice,
                onTapBill: { detailBill = $0 }
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.bills) { bill in
                        BillRow(bill: bill) {
                            detailBill = bill
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                removeTrackedBill(bill)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    sectionHeader(title: section.title, bills: section.bills)
                        .textCase(nil)
                        .padding(.top, 8)
                }
            }

            ExpectedSection(
                expectations: expectations,
                onArrived: { startAddBill() },
                onStopExpecting: { expectation in
                    if let source = bills.first(where: { $0.uuid == expectation.sourceBillUUID }) {
                        source.recurrence = BillRecurrence.none.rawValue
                        services.scheduler.cancel(identifiers: ["expect-\(source.uuid)"])
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 110, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await pendingMonitor.refresh(
                accounts: services.accounts,
                emailIn: services.emailIn,
                parser: services.parser
            )
        }
    }

    private func removeTrackedBill(_ bill: Bill) {
        services.scheduler.cancel(identifiers: bill.notificationIDs)
        let billID = bill.uuid
        Task { await LiveActivityManager.end(billID: billID) }
        modelContext.delete(bill)
        try? modelContext.save()
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

    /// Named forwarded bills waiting for a once-over — confirm or remove.
    /// Used on the empty state (ScrollView); list path renders rows inline.
    private var pendingApprovalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Needs a look")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.chartreuse)
                Spacer()
                Text(pendingMonitor.count == 1 ? "1 bill" : "\(pendingMonitor.count) bills")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
            }
            .padding(.horizontal, 4)

            ForEach(pendingMonitor.previews) { preview in
                pendingRow(preview)
            }
        }
        .accessibilityIdentifier("pending-email-approval")
    }

    private func dismissPending(_ key: String) {
        Task {
            await pendingMonitor.dismiss(
                key: key,
                accounts: services.accounts,
                emailIn: services.emailIn
            )
        }
    }

    private func pendingRow(_ preview: PendingBillPreview) -> some View {
        HStack(spacing: 0) {
            Button {
                openPending(preview.item)
            } label: {
                HStack(spacing: 12) {
                    BenIconCircle(
                        systemName: preview.item.contentType.lowercased().contains("pdf")
                            ? "doc.richtext.fill" : "envelope.badge.fill",
                        fill: .sky,
                        iconColor: .onSky
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(preview.title)
                            .font(.benCardTitle)
                            .foregroundStyle(Color.forestInk)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if preview.isEnriching {
                                ProgressView().controlSize(.mini).tint(.chartreuse)
                            }
                            Text(preview.subtitle)
                                .font(.benMeta)
                                .foregroundStyle(Color.forestInk.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    if openingPendingKey == preview.id {
                        ProgressView().tint(.chartreuse)
                    }
                }
                .padding(.leading, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(BenPressable(haptic: .light))
            .disabled(openingPendingKey != nil)

            Button {
                dismissPending(preview.item.key)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.forestInk.opacity(0.45))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
            .disabled(openingPendingKey != nil)
            .padding(.trailing, 6)
        }
        .benRowSurface(radius: 26)
        .contextMenu {
            Button("Remove", systemImage: "trash", role: .destructive) {
                dismissPending(preview.item.key)
            }
        }
    }

    private func openPending(_ item: PendingEmailBill) {
        guard openingPendingKey == nil else { return }
        openingPendingKey = item.key
        let accounts = services.accounts
        let emailIn = services.emailIn
        let parser = services.parser
        let analytics = services.analytics
        Task {
            defer { openingPendingKey = nil }
            do {
                guard let token = try await accounts.idToken() else { return }
                let data = try await emailIn.blob(key: item.key, idToken: token)
                analytics.track(.billUploadStarted(uploadMethod: UploadMethod.email.rawValue))
                let parsed = try? await parser.parse(data)
                coordinator.isAddingSubsequentBill = true
                coordinator.uploadMethod = .email
                coordinator.pendingImageData = data
                coordinator.parsed = parsed
                coordinator.pendingEmailKey = item.key
                coordinator.advance(to: parsed == nil ? .manualEntry : .confirm)
                showAddBill = true
            } catch {
                // Soft — pull to refresh and try again.
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 18) {
                if pendingMonitor.hasPending {
                    pendingApprovalSection
                        .padding(.top, 24)
                }
                Spacer(minLength: 40)
                BenCharacter(size: 150)
                BenVoiceText(text: "No bills yet. Hand one over and it becomes my problem.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                BenPrimaryButton(title: "Add a bill") { startAddBill() }
                    .padding(.horizontal, 60)
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await pendingMonitor.refresh(
                accounts: services.accounts,
                emailIn: services.emailIn,
                parser: services.parser
            )
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
