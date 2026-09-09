import SwiftUI

/// Create or sign in to a Ben account — unlocks sync, backup, and the
/// email-in address. Stub providers today; real SDKs are HUMAN-gated.
struct AccountSheet: View {
    var onSignedIn: ((BenAccount) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Save your setup")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                BenVoiceText(
                    text: "One account, three jobs: your bills backed up, synced to a new phone, and your own email-in address.",
                    quiet: true
                )
                .padding(.bottom, 6)

                benefitRow(symbol: "arrow.triangle.2.circlepath", fill: .chartreuse, iconColor: .onChartreuse,
                           title: "Sync & backup", detail: "Your bills follow you to any device.")
                benefitRow(symbol: "envelope.fill", fill: .sky, iconColor: .onSky,
                           title: "Email bills in", detail: "Forward any bill — Ben does the typing.")
                benefitRow(symbol: "lock.fill", fill: .amber, iconColor: .onAmber,
                           title: "Still yours", detail: "You pay for Ben, so your data is never the product.")

                VStack(spacing: 10) {
                    Text("Account sign-in isn't on this build. Sign in with Apple isn't entitled yet, so there's nothing to tap.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)

                Text("No passwords, no spam. Sign-in lands when Apple entitles it.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .benSheetClose()
    }

    private func benefitRow(
        symbol: String, fill: Color, iconColor: Color, title: String, detail: String
    ) -> some View {
        HStack(spacing: 12) {
            BenIconCircle(systemName: symbol, fill: fill, iconColor: iconColor, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.benCardTitle)
                    .foregroundStyle(Color.forestInk)
                Text(detail)
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .benRowSurface(radius: 22)
    }

    // HUMAN: Sign in with Apple entitlement + Google Sign-In SDK are still
    // gated. Do not show Continue with Apple / Google until then, and do not
    // fake an account.
}
