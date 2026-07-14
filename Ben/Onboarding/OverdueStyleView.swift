import SwiftUI

/// S7b — the safety net. How often Ben mentions a bill that slipped.
/// Only shown when notifications were granted; every option is capped.
struct OverdueStyleView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @AppStorage(OverdueCadence.storageKey) private var storedCadence = OverdueCadence.everySecondDay.rawValue

    @State private var selected: OverdueCadence = .everySecondDay

    var body: some View {
        BenScreen(title: "If one slips") {
            HStack(alignment: .top, spacing: 12) {
                BenAvatar(size: 40)
                BenVoiceText(
                    text: "Most bills won't get past us. If one does slip overdue, how often should I mention it?",
                    quiet: true
                )
                .foregroundStyle(Color.benInkSecondary)
            }
            .padding(.bottom, 12)

            VStack(spacing: 12) {
                ForEach(OverdueCadence.allCases, id: \.self) { cadence in
                    SelectablePill(label: cadence.label, detail: cadence.detail, isSelected: selected == cadence) {
                        selected = cadence
                    }
                }
            }

            Text("Whatever you pick, it stops the moment you mark the bill paid.")
                .font(.benMeta)
                .foregroundStyle(Color.benInkMuted)
                .padding(.top, 4)
        } cta: {
            BenPrimaryButton(title: "That works") {
                storedCadence = selected.rawValue
                scheduleAndAdvance()
            }
        }
        .onAppear {
            selected = OverdueCadence(rawValue: storedCadence) ?? .everySecondDay
        }
    }

    private func scheduleAndAdvance() {
        if let bill = coordinator.confirmedBill {
            let scheduler = services.scheduler
            let cadence = selected
            let billID = bill.uuid
            let issuer = bill.issuer
            let dueDate = bill.dueDate
            Task {
                let identifiers = await scheduler.scheduleOverdueReminders(
                    billID: billID, issuer: issuer, dueDate: dueDate, cadence: cadence
                )
                bill.notificationIDs.append(contentsOf: identifiers)
            }
        }
        coordinator.advance(to: .setState)
    }
}
