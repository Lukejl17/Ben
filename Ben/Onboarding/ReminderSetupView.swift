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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BenAvatar()
                BenVoiceText(text: benLine)
            }
            .padding(.top, 48)

            if !denied {
                VStack(spacing: 10) {
                    ForEach(ReminderStyle.allCases, id: \.self) { option in
                        SelectablePill(label: option.label, detail: option.detail, isSelected: style == option) {
                            style = option
                        }
                    }
                }

                if !plannedDates.isEmpty {
                    BenCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(plannedDates, id: \.self) { date in
                                HStack(spacing: 10) {
                                    Image(systemName: "bell")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.benAccent)
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.benBody)
                                        .foregroundStyle(Color.benInk)
                                }
                            }
                        }
                    }
                } else {
                    Text("That due date is close — reminders would already have passed, so I'll just keep it visible in here.")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkSecondary)
                }
            }

            Spacer()

            BenPrimaryButton(title: denied ? "Continue" : "Sounds right — set it up") {
                if denied || permissionResolved {
                    coordinator.advance(to: nextStep)
                } else {
                    showPrePermissionSheet = true
                }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .onAppear { style = coordinator.reminderStyle }
        .sheet(isPresented: $showPrePermissionSheet) {
            PrePermissionSheet(
                onAllow: { requestPermission() },
                onNotNow: {
                    showPrePermissionSheet = false
                    handleDenied(osLevel: false)
                }
            )
            .presentationDetents([.medium])
        }
    }

    private var nextStep: OnboardingCoordinator.Step {
        coordinator.isAddingSubsequentBill ? .done : .setState
    }

    private var benLine: String {
        guard let bill else { return "Let's set your reminder." }
        if denied {
            return "No worries — I'll keep everything ready in here instead."
        }
        let due = bill.dueDate.formatted(.dateTime.day().month(.wide))
        if let first = plannedDates.first, plannedDates.count > 0 {
            let mention = first.formatted(.dateTime.day().month(.wide))
            return "Your \(bill.issuer) bill is due \(due). I'll mention it on \(mention) — sound right? After that, silence until it matters."
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
        services.analytics.track(.notificationSet)
        coordinator.advance(to: nextStep)
    }
}

/// The soft ask that precedes the OS prompt — context first, prompt second.
private struct PrePermissionSheet: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BenVoiceText(
                text: "iOS will ask if I'm allowed to notify you. It's only ever about a bill needing you — nothing else, I promise."
            )
            .padding(.top, 28)

            BenPrimaryButton(title: "Allow notifications", action: onAllow)
            BenSecondaryButton(title: "Not now", action: onNotNow)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationBackground(Color.benCanvas)
    }
}
