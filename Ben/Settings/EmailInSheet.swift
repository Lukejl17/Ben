import SwiftUI

/// Email bills in: the user's personal forwarding address and how it works.
/// Requires an account (the address belongs to it). Ingestion backend is
/// HUMAN-gated; the flow and address are real and stable now.
struct EmailInSheet: View {
    @Environment(\.services) private var services
    @State private var account: BenAccount?
    @State private var showAccountSheet = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Email bills in")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                if let account {
                    addressCard(for: account)
                    stepsCard
                    Text("Forwarding goes live with your account backend — your address won't change.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.5))
                } else {
                    signedOutState
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { account = services.accounts.account }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet { newAccount in
                account = newAccount
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        }
        .benSheetClose()
    }

    /// The star widget: your address, one tap to copy.
    private func addressCard(for account: BenAccount) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            BenEyebrow(text: "Your address")
            Text(account.forwardingAddress)
                .font(.baloo("Baloo2-Bold", 22, relativeTo: .title2))
                .foregroundStyle(Color.onCreamStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 4)
            Button {
                UIPasteboard.general.string = account.forwardingAddress
                services.analytics.track(.forwardingSetup)
                withAnimation(.spring(duration: 0.3)) { copied = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied" : "Copy address")
                }
                .font(.benLabel)
                .foregroundStyle(Color.onChartreuse)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.chartreuse, in: Capsule())
            }
            .buttonStyle(BenPressable())
            .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, .light)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .benShadow(.cream)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepRow(number: "1", title: "Forward the email",
                    detail: "Any bill that lands in your inbox — send it to your address.")
            stepRow(number: "2", title: "Ben reads it",
                    detail: "Issuer, amount, due date — same as a photo, no typing.")
            stepRow(number: "3", title: "You confirm",
                    detail: "Nothing is saved until you give it a once-over in here.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .benRowSurface(radius: 24)
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.benLabel)
                .foregroundStyle(Color.onChartreuse)
                .frame(width: 26, height: 26)
                .background(Color.chartreuse, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.benCardTitle)
                    .foregroundStyle(Color.forestInk)
                Text(detail)
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signedOutState: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenVoiceText(
                text: "Your email-in address belongs to your account — one tap and it's yours.",
                quiet: true
            )
            stepsCard
            BenPrimaryButton(title: "Set up my address") {
                showAccountSheet = true
            }
            .padding(.top, 6)
        }
    }
}
