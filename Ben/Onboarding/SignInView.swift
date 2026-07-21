import SwiftUI

/// Returning-user sign in. Layout mirrors the standard login pattern:
/// brand → greeting → side-by-side providers → email/password → CTA.
/// Success lands straight on home — no onboarding rerun.
struct SignInView: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    /// Called with the signed-in account; the presenter decides where to go.
    var onSignedIn: (BenAccount) -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isCreating = false
    @State private var isWorking = false
    @State private var errorLine: String?
    @State private var infoLine: String?

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= (isCreating ? 8 : 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandMark
                    .padding(.top, 36)

                Text(isCreating ? "Let's get you set up." : "Welcome back.")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)

                Text(isCreating
                     ? "One account keeps your bills and plan with you."
                     : "Enter your details to pick up where you left off.")
                    .font(.benBody)
                    .foregroundStyle(Color.forestInk.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.bottom, 22)

                HStack(spacing: 12) {
                    BenProviderButton(provider: .google, style: .compact) {
                        signIn(with: .google)
                    }
                    BenProviderButton(provider: .apple, style: .compact) {
                        signIn(with: .apple)
                    }
                }

                orDivider
                    .padding(.vertical, 18)

                field("Email address", text: $email, secure: false)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("signin-email")
                    .padding(.bottom, 12)

                field("Password", text: $password, secure: true)
                    .textContentType(isCreating ? .newPassword : .password)
                    .accessibilityIdentifier("signin-password")

                if !isCreating {
                    HStack {
                        Spacer()
                        Button("Forgot password?") { sendReset() }
                            .font(.benMeta)
                            .foregroundStyle(Color.forestInk.opacity(0.7))
                            .disabled(email.isEmpty || isWorking)
                    }
                    .padding(.top, 8)
                }

                if let errorLine {
                    Text(errorLine)
                        .font(.benMeta)
                        .foregroundStyle(Color.statusLateFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
                if let infoLine {
                    Text(infoLine)
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }

                BenPrimaryButton(title: isCreating ? "Create account" : "Log in") {
                    submitEmail()
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
                .padding(.top, 18)

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        isCreating.toggle()
                        errorLine = nil
                        infoLine = nil
                    }
                } label: {
                    (
                        Text(isCreating ? "Already have an account? " : "Create an account? ")
                            .foregroundStyle(Color.forestInk.opacity(0.55))
                        + Text(isCreating ? "Log in" : "Sign up")
                            .foregroundStyle(Color.forestInk)
                    )
                    .font(.benMeta)
                }
                .padding(.top, 16)
                .accessibilityIdentifier(isCreating ? "Log in" : "Sign up")

                legalRow
                    .padding(.top, 22)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
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

    // MARK: Pieces

    private var brandMark: some View {
        Text("Ben")
            .font(.baloo("Baloo2-ExtraBold", 22, relativeTo: .title3))
            .foregroundStyle(Color.chartreuse)
            .accessibilityAddTraits(.isHeader)
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
    }

    private func field(
        _ placeholder: String, text: Binding<String>, secure: Bool
    ) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .font(.benBody)
        .foregroundStyle(Color.onCreamStrong)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, .light)
    }

    private var legalRow: some View {
        HStack(spacing: 8) {
            legalLink("Terms of Service", url: "https://benandbill.app/terms")
            Text("|")
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.25))
            legalLink("Privacy Policy", url: "https://benandbill.app/privacy")
        }
    }

    private func legalLink(_ label: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text(label)
                .font(.system(size: 11.5))
                .underline()
                .foregroundStyle(Color.forestInk.opacity(0.45))
        }
    }

    // MARK: Actions

    private func signIn(with provider: BenAccount.Provider) {
        guard !isWorking else { return }
        isWorking = true
        errorLine = nil
        infoLine = nil
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

    private func submitEmail() {
        guard !isWorking, canSubmit else { return }
        isWorking = true
        errorLine = nil
        infoLine = nil
        let accounts = services.accounts
        let formEmail = email
        let formPassword = password
        let creating = isCreating
        Task {
            do {
                let account = try await accounts.signIn(
                    email: formEmail, password: formPassword, creating: creating
                )
                onSignedIn(account)
                dismiss()
            } catch {
                errorLine = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func sendReset() {
        guard !isWorking else { return }
        isWorking = true
        errorLine = nil
        infoLine = nil
        let accounts = services.accounts
        let formEmail = email
        Task {
            do {
                try await accounts.sendPasswordReset(to: formEmail)
                infoLine = "If that email has a Ben account, a reset link is on its way."
            } catch {
                errorLine = error.localizedDescription
            }
            isWorking = false
        }
    }
}
