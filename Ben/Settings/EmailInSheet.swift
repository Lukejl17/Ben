import SwiftUI

/// Email bills in: the user's personal forwarding address, how it works, and
/// the bills waiting to be confirmed. Requires an account (the address
/// belongs to it).
struct EmailInSheet: View {
    @Environment(\.services) private var services
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(\.dismiss) private var dismiss
    @State private var account: BenAccount?
    @State private var showAccountSheet = false
    @State private var copied = false
    @State private var pending: [PendingEmailBill] = []
    @State private var isLoadingPending = false
    @State private var openingKey: String?
    @State private var pendingError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Email bills in")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                if let account {
                    addressCard(for: account)
                    if !pending.isEmpty || isLoadingPending || pendingError != nil {
                        pendingCard
                    }
                    stepsCard
                } else {
                    signedOutState
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            account = services.accounts.account
            refreshPending()
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet { newAccount in
                account = newAccount
                refreshPending()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        }
        .benSheetClose()
    }

    // MARK: Pending bills (the mailroom's waiting shelf)

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BenEyebrow(text: "Waiting for you", color: Color.forestInk.opacity(0.55))
            if isLoadingPending && pending.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(.chartreuse)
                    Text("Checking the mailroom…")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.6))
                }
            }
            if let pendingError {
                Text(pendingError)
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.6))
            }
            ForEach(pending) { item in
                Button {
                    open(item)
                } label: {
                    HStack(spacing: 12) {
                        BenIconCircle(
                            systemName: "envelope.badge.fill", fill: .sky,
                            iconColor: .onSky, size: 38
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.subject.isEmpty ? "Forwarded bill" : item.subject)
                                .font(.benCardTitle)
                                .foregroundStyle(Color.forestInk)
                                .lineLimit(1)
                            Text(item.from.isEmpty ? "Tap to read and confirm" : item.from)
                                .font(.benMeta)
                                .foregroundStyle(Color.forestInk.opacity(0.6))
                                .lineLimit(1)
                        }
                        Spacer()
                        if openingKey == item.key {
                            ProgressView().tint(.chartreuse)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.forestInk.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .benRowSurface(radius: 22)
                }
                .buttonStyle(BenPressable())
                .disabled(openingKey != nil)
            }
        }
    }

    private func refreshPending() {
        guard account != nil else { return }
        isLoadingPending = true
        pendingError = nil
        let accounts = services.accounts
        let emailIn = services.emailIn
        Task {
            do {
                guard let token = try await accounts.idToken() else {
                    isLoadingPending = false
                    return
                }
                pending = try await emailIn.pending(idToken: token)
            } catch {
                pendingError = "Couldn't check for new bills just now. Pull the sheet down and try again."
            }
            isLoadingPending = false
        }
    }

    /// Download the attachment, run the same on-device reader as a photo,
    /// and hand over to the S6 confirm screen. Nothing saves until then.
    private func open(_ item: PendingEmailBill) {
        guard openingKey == nil else { return }
        openingKey = item.key
        let accounts = services.accounts
        let emailIn = services.emailIn
        let parser = services.parser
        let analytics = services.analytics
        Task {
            defer { openingKey = nil }
            do {
                guard let token = try await accounts.idToken() else { return }
                let data = try await emailIn.blob(key: item.key, idToken: token)
                analytics.track(.billUploadStarted(uploadMethod: UploadMethod.email.rawValue))
                let parsed = try? await parser.parse(data)

                coordinator.isAddingSubsequentBill = true
                coordinator.uploadMethod = .email
                coordinator.pendingImageData = data
                coordinator.parsed = parsed
                coordinator.pendingEmailKey = item.key
                coordinator.advance(to: parsed == nil ? .manualEntry : .confirm)
                notificationRouter.confirmEmailBillRequested = true
                dismiss()
            } catch {
                pendingError = "That one wouldn't open. Give it another go in a tick."
            }
        }
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
                    detail: "Send any bill that lands in your inbox to your address.")
            stepRow(number: "2", title: "It waits here",
                    detail: "Forwarded bills appear in this sheet, ready when you are.")
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
                text: "Your email-in address belongs to your account. One tap and it's yours.",
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
