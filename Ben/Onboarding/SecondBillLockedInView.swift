import SwiftUI

/// End of the onboarding funnel after a second bill is confirmed + reminded.
/// Clear completion moment — then home. Event: `onboarding_completed`.
struct SecondBillLockedInView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var bill: Bill? { coordinator.confirmedBill }

    var body: some View {
        BenScreen {
            VStack(alignment: .leading, spacing: 0) {
                Text("Locked in.")
                    .font(.baloo("Baloo2-ExtraBold", 44, relativeTo: .largeTitle))
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 36)
                    .padding(.bottom, 10)

                BenVoiceText(
                    text: "This one's locked in and not going to be missed. "
                        + "Two bills on the board — that's usually enough to stop the background worry.",
                    quiet: true
                )
                .foregroundStyle(Color.forestInk.opacity(0.65))
                .padding(.bottom, 22)
            }

            if let bill {
                BenCard {
                    HStack(alignment: .center, spacing: 14) {
                        BenIconCircle(
                            systemName: BillCategories.symbol(forIssuer: bill.issuer),
                            fill: BillCategories.wash(forIssuer: bill.issuer).bg,
                            iconColor: BillCategories.wash(forIssuer: bill.issuer).fg
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bill.issuer)
                                .font(.benCardTitle)
                                .foregroundStyle(Color.onCream)
                            Text("Due \(bill.dueDate.formatted(.dateTime.day().month(.wide)))")
                                .font(.benMeta)
                                .foregroundStyle(Color.onCreamMuted)
                        }
                        Spacer()
                        Text(bill.amount.formatted(.currency(code: "AUD")))
                            .font(.benAmount)
                            .monospacedDigit()
                            .foregroundStyle(Color.onCreamStrong)
                    }
                }
            }

            Text("2 bills tracked")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.5))
                .padding(.top, 16)
        } cta: {
            BenPrimaryButton(title: "See my bills") {
                finish()
            }
        }
    }

    private func finish() {
        services.analytics.track(.onboardingCompleted(path: "second_bill"))
        hasCompletedOnboarding = true
        coordinator.isAddingSubsequentBill = false
        coordinator.advance(to: .done)
    }
}
