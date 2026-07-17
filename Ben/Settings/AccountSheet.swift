import SwiftUI

/// Create or sign in to a Ben account — unlocks sync, backup, and the
/// email-in address. Stub providers today; real SDKs are HUMAN-gated.
struct AccountSheet: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: ((BenAccount) -> Void)?

    @State private var isWorking = false
    @State private var errorLine: String?

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
                           title: "Email bills in", detail: "Forward any bill and Ben does the typing.")
                benefitRow(symbol: "lock.fill", fill: .amber, iconColor: .onAmber,
                           title: "Still yours", detail: "You pay for Ben, so your data is never the product.")

                if let errorLine {
                    Text(errorLine)
                        .font(.benMeta)
                        .foregroundStyle(Color.statusLateFg)
                }

                VStack(spacing: 10) {
                    providerButton(
                        title: "Continue with Apple", systemImage: "applelogo", provider: .apple
                    )
                    providerButton(
                        title: "Continue with Google", systemImage: "g.circle.fill", provider: .google
                    )
                }
                .padding(.top, 8)

                Text("No passwords, no spam. Signing in creates your Ben account.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .overlay {
            if isWorking {
                ProgressView()
                    .controlSize(.large)
                    .tint(.chartreuse)
            }
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

    /// HUMAN: swap StubAccountService internals for ASAuthorization (Apple,
    /// needs the Sign in with Apple capability) and GoogleSignIn SDK (needs
    /// an OAuth client ID). These buttons and the flow stay unchanged.
    private func providerButton(
        title: String, systemImage: String, provider: BenAccount.Provider
    ) -> some View {
        BenSecondaryButton(title: title, systemImage: systemImage) {
            guard !isWorking else { return }
            isWorking = true
            errorLine = nil
            let accounts = services.accounts
            let analytics = services.analytics
            Task {
                do {
                    let account = try await accounts.signIn(with: provider)
                    analytics.track(.accountCreated)
                    onSignedIn?(account)
                    dismiss()
                } catch {
                    errorLine = error.localizedDescription
                }
                isWorking = false
            }
        }
        .accessibilityIdentifier(title)
    }
}
