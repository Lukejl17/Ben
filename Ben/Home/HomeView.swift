import SwiftData
import SwiftUI

/// Home — the system of record. Status-sorted bills, one designed empty state.
struct HomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(\.services) private var services
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @State private var showAddBill = false
    @State private var detailBill: Bill?

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

    private var needsAttention: Bool {
        bills.contains { $0.status == .dueSoon || $0.status == .overdue }
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
            .navigationTitle("Bills")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    BenCircleButton(systemName: "plus", accessibilityLabel: "Add a bill") {
                        startAddBill()
                    }
                }
            }
        }
        .tint(.benAccent)
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
            .presentationBackground(Color.benCanvas)
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
                .presentationBackground(Color.benCanvas)
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
                if !needsAttention {
                    HStack(spacing: 12) {
                        BenAvatar(size: 40)
                        BenVoiceText(text: "Nothing needs your attention.", quiet: true)
                            .foregroundStyle(Color.benInkSecondary)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                if case .lapsed = services.subscriptions.state() {
                    BenCard(padding: 14) {
                        Text("Your trial has ended — bills stay visible here, reminders are off.")
                            .font(.benMeta)
                            .foregroundStyle(Color.benInkSecondary)
                    }
                }
                ForEach(sections, id: \.title) { section in
                    sectionHeader(title: section.title, bills: section.bills)
                        .padding(.top, section.title == sections.first?.title ? 0 : 14)
                    ForEach(section.bills) { bill in
                        BillRow(bill: bill) {
                            detailBill = bill
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    /// Section header: title left, factual total right. No drama, even for overdue.
    private func sectionHeader(title: String, bills sectionBills: [Bill]) -> some View {
        let total = sectionBills.reduce(Decimal.zero) { $0 + $1.amount }
        return HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.benCardTitle)
                .foregroundStyle(title == "Overdue" ? Color.statusOverdueFg : Color.benInk)
            Spacer()
            Text(total.formatted(.currency(code: "AUD")))
                .font(.benMeta)
                .monospacedDigit()
                .foregroundStyle(Color.benInkMuted)
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            BenAvatar(size: 44)
            BenVoiceText(text: "No bills yet. Hand one over and it becomes my problem.")
                .foregroundStyle(Color.benInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            BenPrimaryButton(title: "Add a bill") { startAddBill() }
                .padding(.horizontal, 60)
            Spacer()
        }
    }

    private func startAddBill() {
        coordinator.isAddingSubsequentBill = true
        coordinator.resetForSecondBill()
        showAddBill = true
    }
}

struct BillRow: View {
    let bill: Bill
    var onTap: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                BenIconCircle(
                    systemName: BillCategories.symbol(forIssuer: bill.issuer),
                    wash: BillCategories.wash(forIssuer: bill.issuer)
                )
                .opacity(bill.status == .paid ? 0.55 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(bill.issuer)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.benInk)
                    Text("Due \(bill.dueDate.formatted(.dateTime.day().month(.wide)))")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkMuted)
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
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(BenPressable())
        .benShadow(.card)
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
