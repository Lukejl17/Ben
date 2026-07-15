import SwiftUI

/// S7 — the notification contract. Pre-permission sheet before the OS prompt.
/// ⭐ Activation completes here.
struct ReminderSetupView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @AppStorage("notificationReaskPending") private var reaskPending = false

    @State private var style: ReminderStyle = .fewDaysEarly
    @State private var showPrePermissionSheet = false
    @State private var permissionResolved = false
    @State private var denied = false

    private var bill: Bill? { coordinator.confirmedBill }

    private var plannedDates: [Date] {
        guard let bill else { return [] }
        return ReminderScheduler.triggerDates(style: style, dueDate: bill.dueDate)
    }

    var body: some View {
        BenScreen(title: denied ? "All set" : "The deal on reminders") {
            HStack(alignment: .top, spacing: 12) {
                BenVoiceText(text: benLine, quiet: true)
                    .foregroundStyle(Color.forestInk.opacity(0.65))
            }
            .padding(.bottom, 12)

            if !denied {
                VStack(spacing: 12) {
                    ForEach(ReminderStyle.allCases, id: \.self) { option in
                        SelectablePill(label: option.label, detail: option.detail, isSelected: style == option) {
                            style = option
                        }
                    }
                }
                .padding(.bottom, 12)

                if !plannedDates.isEmpty {
                    BenCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(plannedDates, id: \.self) { date in
                                HStack(spacing: 12) {
                                    BenIconCircle(systemName: "bell.fill", fill: .amber, iconColor: .onAmber, size: 38)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                            .font(.benCardTitle)
                                            .foregroundStyle(Color.onCream)
                                        Text("9:00 am — one mention, that's all")
                                            .font(.benMeta)
                                            .foregroundStyle(Color.onCreamMuted)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("That due date is close — reminders would already have passed, so I'll just keep it visible in here.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.65))
                }
            }
        } cta: {
            BenPrimaryButton(title: denied ? "Continue" : "Sounds right — set it up") {
                if denied {
                    // B3: no permission means no overdue mentions either — skip S7b.
                    coordinator.advance(to: coordinator.isAddingSubsequentBill ? .done : .setState)
                } else if permissionResolved {
                    coordinator.advance(to: nextStep)
                } else {
                    showPrePermissionSheet = true
                }
            }
        }
        .onAppear { style = coordinator.reminderStyle }
        .sheet(isPresented: $showPrePermissionSheet) {
            PrePermissionSheet(
                onAllow: { requestPermission() },
                onNotNow: {
                    showPrePermissionSheet = false
                    handleDenied(osLevel: false)
                }
            )
            .presentationDetents([.height(300)])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        }
    }

    /// First onboarding continues to the overdue-cadence ask; the add-a-bill
    /// flow reuses the stored cadence and finishes.
    private var nextStep: OnboardingCoordinator.Step {
        coordinator.isAddingSubsequentBill ? .done : .overdueStyle
    }

    private var benLine: String {
        guard let bill else { return "Let's set your reminder." }
        if denied {
            return "No worries — I'll keep everything ready in here instead."
        }
        let due = bill.dueDate.formatted(.dateTime.day().month(.wide))
        if let first = plannedDates.first {
            let mention = first.formatted(.dateTime.day().month(.wide))
            return "Your \(bill.issuer) bill is due \(due). I'll mention it on \(mention) — sound right? "
                + "After that, silence until it matters."
        }
        return "Your \(bill.issuer) bill is due \(due)."
    }

    private func requestPermission() {
        showPrePermissionSheet = false
        let scheduler = services.scheduler
        let analytics = services.analytics
        Task {
            let granted = await scheduler.requestPermission()
            if granted {
                analytics.track(.osPermissionGranted)
                coordinator.notificationsGranted = true
                permissionResolved = true
                await scheduleAndAdvance()
            } else {
                analytics.track(.osPermissionDenied)
                handleDenied(osLevel: true)
            }
        }
    }

    /// B3 — denied. Silent mode, no re-prompt, one contextual re-ask flag
    /// stored for when the first due date approaches.
    private func handleDenied(osLevel: Bool) {
        coordinator.notificationsGranted = false
        denied = true
        reaskPending = true
    }

    private func scheduleAndAdvance() async {
        guard let bill else {
            coordinator.advance(to: nextStep)
            return
        }
        coordinator.reminderStyle = style
        let identifiers = await services.scheduler.scheduleReminders(
            billID: bill.uuid,
            issuer: bill.issuer,
            dueDate: bill.dueDate,
            style: style,
            withSecondBillRider: true  // first due-soon reminder carries the one rider
        )
        bill.hasNotification = !identifiers.isEmpty
        bill.notificationIDs = identifiers
        // Subsequent bills reuse the cadence chosen during onboarding (S7b).
        if coordinator.isAddingSubsequentBill {
            let raw = UserDefaults.standard.string(forKey: OverdueCadence.storageKey)
            let cadence = OverdueCadence(rawValue: raw ?? "") ?? .everySecondDay
            let overdueIDs = await services.scheduler.scheduleOverdueReminders(
                billID: bill.uuid, issuer: bill.issuer, dueDate: bill.dueDate, cadence: cadence
            )
            bill.notificationIDs.append(contentsOf: overdueIDs)
        }
        services.analytics.track(.notificationSet)
        coordinator.advance(to: nextStep)
    }
}

/// The soft ask that precedes the OS prompt — context first, prompt second.
private struct PrePermissionSheet: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                BenVoiceText(
                    text: "iOS will ask if I'm allowed to notify you. It's only ever about a bill needing you — nothing else, I promise.",
                    quiet: true
                )
            }
            .padding(.top, 30)

            BenPrimaryButton(title: "Allow notifications", action: onAllow)
            BenTextButton(title: "Not now", action: onNotNow)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
