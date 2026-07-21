import SwiftUI

/// Returning-user sign in. Standard layout: providers up top, then email +
/// password. Success lands straight on home — no onboarding rerun.
struct SignInView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    /// Called with the signed-in account; the presenter decides where to go.
    var onSignedIn: (BenAccount) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorLine: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Welcome back.")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                BenVoiceText(
                    text: "Sign in and your bills are right where you left them.",
                    quiet: true
                )
                .padding(.bottom, 6)

                BenProviderButton(provider: .apple) { signIn(with: .apple) }
                BenProviderButton(provider: .google) { signIn(with: .google) }

                orDivider

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .environment(\.colorScheme, .light)
                    .accessibilityIdentifier("signin-email")

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .environment(\.colorScheme, .light)
                    .accessibilityIdentifier("signin-password")

                if let errorLine {
                    Text(errorLine)
                        .font(.benMeta)
                        .foregroundStyle(Color.statusLateFg)
                }

                BenPrimaryButton(title: "Sign in") {
                    signInWithEmail()
                }
                .disabled(email.isEmpty || password.isEmpty)
                .opacity(email.isEmpty || password.isEmpty ? 0.45 : 1)

                Text("New here? Close this and Ben will walk you through your first bill.")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
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

    private func signIn(with provider: BenAccount.Provider) {
        guard !isWorking else { return }
        isWorking = true
        errorLine = nil
        let accounts = services.accounts
        Task {
            do {
                let account = try await accounts.signIn(with: provider)
                onSignedIn(account)
                dismiss()
            } catch {
                errorLine = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func signInWithEmail() {
        guard !isWorking else { return }
        isWorking = true
        errorLine = nil
        let accounts = services.accounts
        let formEmail = email
        let formPassword = password
        Task {
            do {
                let account = try await accounts.signIn(
                    email: formEmail, password: formPassword, creating: false
                )
                onSignedIn(account)
                dismiss()
            } catch {
                errorLine = error.localizedDescription
            }
            isWorking = false
        }
    }
}
