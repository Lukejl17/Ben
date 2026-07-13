import SwiftData
import SwiftUI

/// Home — the system of record. Status-sorted bills, one designed empty state.
struct HomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @State private var showAddBill = false

    private var sortedBills: [Bill] {
        let rank: [BillStatus: Int] = [.overdue: 0, .dueSoon: 1, .upcoming: 2, .paid: 3]
        return bills.sorted {
            let left = rank[$0.status, default: 2]
            let right = rank[$1.status, default: 2]
            return left == right ? $0.dueDate < $1.dueDate : left < right
        }
    }

    private var needsAttention: Bool {
        bills.contains { $0.status == .dueSoon || $0.status == .overdue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bills.isEmpty {
                    emptyState
                } else {
                    billList
                }
            }
            .background(Color.benCanvas)
            .navigationTitle("Bills")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startAddBill()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a bill")
                }
            }
        }
        .sheet(isPresented: $showAddBill) {
            OnboardingFlow()
                .presentationBackground(Color.benCanvas)
        }
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
        }
    }

    private var billList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !needsAttention {
                    BenVoiceText(text: "Nothing needs your attention.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                if case .lapsed = services.subscriptions.state() {
                    Text("Your trial has ended — bills stay visible here, reminders are off.")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(sortedBills) { bill in
                    BillRow(bill: bill)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            BenAvatar()
            BenVoiceText(text: "No bills yet. Hand one over and it becomes my problem.")
                .multilineTextAlignment(.center)
            BenPrimaryButton(title: "Add a bill") { startAddBill() }
                .padding(.horizontal, 48)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func startAddBill() {
        coordinator.isAddingSubsequentBill = true
        coordinator.resetForSecondBill()
        showAddBill = true
    }
}

struct BillRow: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services

    var body: some View {
        BenCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.issuer)
                        .font(.benLabel)
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
        }
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
