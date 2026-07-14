import SwiftUI

/// Static category mapping: what people tracking X usually also track,
/// flavoured by the S2 intent.
enum BillCategories {
    static func category(forIssuer issuer: String) -> String {
        let lower = issuer.lowercased()
        let map: [(keywords: [String], category: String)] = [
            (["agl", "origin", "energyaustralia", "red energy", "alinta", "ausgrid", "jemena",
              "electric", "energy", "power"], "electricity"),
            (["telstra", "optus", "vodafone", "tpg", "aussie broadband", "iinet",
              "internet", "broadband", "nbn", "mobile"], "internet"),
            (["water", "urban utilities"], "water"),
            (["nrma", "aami", "allianz", "bupa", "medibank", "hcf", "nib", "insurance"], "insurance"),
            (["council", "rates"], "council rates"),
            (["foxtel", "netflix", "stan", "spotify", "streaming"], "streaming")
        ]
        for entry in map where entry.keywords.contains(where: lower.contains) {
            return entry.category
        }
        return "other"
    }

    static func suggestions(afterCategory category: String, intent: IntentContext?) -> [String] {
        var suggested: [String] = switch category {
        case "electricity": ["internet", "water", "insurance"]
        case "internet": ["electricity", "insurance", "streaming"]
        case "water": ["electricity", "internet", "council rates"]
        case "insurance": ["electricity", "internet", "water"]
        case "council rates": ["water", "electricity", "insurance"]
        case "streaming": ["internet", "electricity", "insurance"]
        default: ["electricity", "internet", "insurance"]
        }
        // Intent flavour: home owners get rates/insurance nudged up the list.
        if intent == .justBoughtHome && !suggested.contains("council rates") {
            suggested[suggested.count - 1] = "council rates"
        }
        return suggested
    }
}

/// S10 — the second-bill bridge. Decline is first-class.
struct SecondBillView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var firstCategory: String {
        BillCategories.category(forIssuer: coordinator.confirmedBill?.issuer ?? "")
    }

    private var suggestions: [String] {
        BillCategories.suggestions(afterCategory: firstCategory, intent: coordinator.intent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BenAvatar()
                BenVoiceText(
                    text: "One bill down. Got internet or insurance floating around an inbox somewhere? "
                        + "Add it now, forward it later, or leave it with me."
                )
            }
            .padding(.top, 48)

            VStack(alignment: .leading, spacing: 8) {
                Text("People tracking \(firstCategory) usually also track")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkMuted)
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { category in
                        Button {
                            addSecondBill()
                        } label: {
                            Text(category)
                                .font(.benLabel)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.benCard, in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.benHairline, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.benInk)
                    }
                }
            }

            // HUMAN: email forwarding ingestion backend — this card is display-only.
            BenCard {
                VStack(alignment: .leading, spacing: 6) {
                    Label("bills@ben.app", systemImage: "envelope")
                        .font(.benLabel)
                        .foregroundStyle(Color.benInk)
                    Text("Forward any bill email and I'll do the rest. Available once your account backend is live.")
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkSecondary)
                }
            }

            Spacer()

            BenPrimaryButton(title: "Add another bill now") { addSecondBill() }

            BenSecondaryButton(title: "Later's fine") {
                // The single promised nudge — cancelled if a second bill lands first.
                let scheduler = services.scheduler
                Task { await scheduler.scheduleDayFourNudge() }
                finish()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .onAppear {
            services.analytics.track(.secondBillPromptShown)
        }
    }

    private func addSecondBill() {
        hasCompletedOnboarding = true
        coordinator.isAddingSubsequentBill = true
        coordinator.resetForSecondBill()
    }

    private func finish() {
        hasCompletedOnboarding = true
        coordinator.advance(to: .done)
    }
}
