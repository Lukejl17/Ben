import SwiftUI

/// Static category mapping: what people tracking X usually also track,
/// flavoured by the S2 intent. Plus icon/wash lookups for bill rows.
enum BillCategories {
    static func category(forIssuer issuer: String) -> String {
        let lower = issuer.lowercased()
        let map: [(keywords: [String], category: String)] = [
            (["agl gas", "gas", "elgas", "kleenheat"], "gas"),
            (["agl", "origin", "energyaustralia", "red energy", "alinta", "ausgrid", "jemena",
              "electric", "energy", "power"], "electricity"),
            (["telstra mobile", "boost", "amaysim", "mobile", "phone"], "phone"),
            (["telstra", "optus", "vodafone", "tpg", "aussie broadband", "iinet",
              "internet", "broadband", "nbn"], "internet"),
            (["water", "urban utilities"], "water"),
            (["nrma", "aami", "allianz", "bupa", "medibank", "hcf", "nib", "insurance"], "insurance"),
            (["council", "rates"], "council rates"),
            (["rent", "real estate", "property management"], "rent"),
            (["foxtel", "netflix", "stan", "binge", "disney", "streaming"], "streaming"),
            (["spotify", "apple", "icloud", "subscription"], "subscriptions")
        ]
        for entry in map where entry.keywords.contains(where: lower.contains) {
            return entry.category
        }
        return "other"
    }

    static func symbol(forIssuer issuer: String) -> String {
        BillCategory.symbol(for: category(forIssuer: issuer))
    }

    static func wash(forIssuer issuer: String) -> (bg: Color, fg: Color) {
        BillCategory.wash(for: category(forIssuer: issuer))
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

    static func symbol(forCategory category: String) -> String {
        BillCategory.symbol(for: category)
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
        BenScreen(title: "One bill down") {
            HStack(alignment: .top, spacing: 12) {
                BenVoiceText(
                    text: "Got internet or insurance floating around an inbox somewhere? "
                        + "Add it now, forward it later, or leave it with me.",
                    quiet: true
                )
                .foregroundStyle(Color.forestInk.opacity(0.65))
            }
            .padding(.bottom, 12)

            Text("People tracking \(firstCategory) usually also track")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.5))

            HStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { category in
                    Button {
                        addSecondBill()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: BillCategories.symbol(forCategory: category))
                                .font(.footnote)
                            Text(category)
                        }
                        .font(.benLabel)
                        .foregroundStyle(Color.forestInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cream, in: Capsule())
                    }
                    .buttonStyle(BenPressable())
                    .benShadow(.floating)
                }
            }
            .padding(.bottom, 12)

            // HUMAN: email forwarding ingestion backend — this card is display-only.
            BenCard {
                HStack(spacing: 14) {
                    BenIconCircle(systemName: "envelope.fill", fill: .sky, iconColor: .onSky)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("bills@ben.app")
                            .font(.benCardTitle)
                            .foregroundStyle(Color.forestInk)
                        Text("Forward any bill email and I'll do the rest. Live once your account backend is up.")
                            .font(.benMeta)
                            .foregroundStyle(Color.forestInk.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } cta: {
            BenPrimaryButton(title: "Add another bill now") { addSecondBill() }
            BenTextButton(title: "Later's fine") {
                // The single promised nudge — cancelled if a second bill lands first.
                let scheduler = services.scheduler
                Task { await scheduler.scheduleDayFourNudge() }
                finish()
            }
            .frame(maxWidth: .infinity)
        }
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
