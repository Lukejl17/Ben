import SwiftUI

/// Create or sign in to a Ben account — unlocks sync, backup, and the
/// email-in address. Real Firebase providers; Apple lights up once the
/// Developer membership is approved (HUMAN).
struct AccountSheet: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(PendingEmailMonitor.self) private var pendingMonitor
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: ((BenAccount) -> Void)?

    @State private var isWorking = false
    @State private var errorLine: String?
    @State private var showEmailForm = false
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = true

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

                AccountSignInControls(
                    isWorking: $isWorking,
                    errorLine: $errorLine,
                    showEmailForm: $showEmailForm,
                    email: $email,
                    password: $password,
                    isCreatingAccount: $isCreatingAccount,
                    onSignedIn: { account in
                        LocalAccountSession.bindAccount(
                            account,
                            modelContext: modelContext,
                            scheduler: services.scheduler,
                            pendingEmails: pendingMonitor
                        )
                        onSignedIn?(account)
                        dismiss()
                    }
                )
                .padding(.top, 8)

                Text("One account, no spam. Your bills stay yours.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .benKeyboardDoneToolbar()
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
}

/// Shared Apple / Google / email controls — used by the account sheet and
/// the required S8 gate before paywall.
struct AccountSignInControls: View {
    @Environment(\.services) private var services
    @Binding var isWorking: Bool
    @Binding var errorLine: String?
    @Binding var showEmailForm: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var isCreatingAccount: Bool
    var onSignedIn: (BenAccount) -> Void

    var body: some View {
        VStack(spacing: 10) {
            BenProviderButton(provider: .apple) { signIn(with: .apple) }
            BenProviderButton(provider: .google) { signIn(with: .google) }

            orDivider

            Button {
                withAnimation(.spring(duration: 0.3)) { showEmailForm.toggle() }
            } label: {
                Text("Use email instead")
                    .font(.benLabel)
                    .foregroundStyle(Color.forestInk.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(BenPressable())
            .accessibilityIdentifier("Use email instead")

            if showEmailForm {
                emailForm
            }
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.forestInk.opacity(0.15))
                .frame(height: 1)
            Text("Or")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.45))
            Rectangle()
                .fill(Color.forestInk.opacity(0.15))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .environment(\.colorScheme, .light)
                .accessibilityIdentifier("account-email")
            SecureField("Password (8+ characters)", text: $password)
                .textContentType(isCreatingAccount ? .newPassword : .password)
                .padding(14)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .environment(\.colorScheme, .light)
                .accessibilityIdentifier("account-password")

            BenPrimaryButton(title: isCreatingAccount ? "Create account" : "Sign in") {
                submitEmailForm()
            }
            .disabled(email.isEmpty || password.count < 8)

            Button {
                withAnimation(.spring(duration: 0.3)) { isCreatingAccount.toggle() }
            } label: {
                Text(isCreatingAccount ? "Already have an account? Sign in"
                                        : "New here? Create an account")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    private func signIn(with provider: BenAccount.Provider) {
        guard !isWorking else { return }
        isWorking = true
        errorLine = nil
        let accounts = services.accounts
        let analytics = services.analytics
        Task {
            do {
                let account = try await accounts.signIn(with: provider)
                analytics.track(.accountCreated)
                onSignedIn(account)
            } catch {
                errorLine = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func submitEmailForm() {
        guard !isWorking else { return }
        isWorking = true
        errorLine = nil
        let accounts = services.accounts
        let analytics = services.analytics
        let creating = isCreatingAccount
        let formEmail = email
        let formPassword = password
        Task {
            do {
                let account = try await accounts.signIn(
                    email: formEmail, password: formPassword, creating: creating
                )
                analytics.track(.accountCreated)
                onSignedIn(account)
            } catch {
                errorLine = error.localizedDescription
            }
            isWorking = false
        }
    }
}
