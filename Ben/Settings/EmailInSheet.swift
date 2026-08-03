import SwiftUI

/// Email bills in: your forwarding address and how it works.
/// Waiting bills live on Bills home — this sheet is just the address.
struct EmailInSheet: View {
    @Environment(\.services) private var services
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(NotificationRouter.self) private var notificationRouter
    @Environment(PendingEmailMonitor.self) private var pendingMonitor
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var account: BenAccount?
    @State private var showAccountSheet = false
    @State private var copied = false
    @State private var openingKey: String?
    @State private var openError: String?

    private var pendingCount: Int { pendingMonitor.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Email bills in")
                    .font(.benTitle)
                    .foregroundStyle(Color.chartreuse)
                    .padding(.top, 28)

                if let account {
                    addressCard(for: account)
                    waitingHint
                    if pendingCount > 0 {
                        arrivedBanner
                    }
                    if let openError {
                        Text(openError)
                            .font(.benMeta)
                            .foregroundStyle(Color.forestInk.opacity(0.6))
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
            pendingMonitor.startPolling(
                accounts: services.accounts,
                emailIn: services.emailIn,
                parser: services.parser,
                every: .seconds(3)
            )
        }
        .onDisappear {
            pendingMonitor.stopPolling()
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet { newAccount in
                account = newAccount
                Task {
                    await pendingMonitor.refresh(
                        accounts: services.accounts,
                        emailIn: services.emailIn,
                        parser: services.parser
                    )
                }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        }
        .benSheetClose()
    }

    /// Calm status while the user is off in Mail forwarding something.
    private var waitingHint: some View {
        Group {
            if pendingCount == 0 {
                HStack(spacing: 10) {
                    if pendingMonitor.isLoading || copied {
                        ProgressView().tint(.chartreuse)
                    } else {
                        Image(systemName: "envelope.open")
                            .foregroundStyle(Color.chartreuse)
                    }
                    Text(
                        copied
                            ? "Address copied. Forward a bill — it'll show on Bills home when it lands."
                            : "Forward a bill to your address. Waiting bills show on Bills home."
                    )
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .benRowSurface(radius: 20)
            }
        }
    }

    /// One calm prompt when mail arrives while this sheet is open (esp. S10).
    private var arrivedBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pendingCount == 1 ? "A bill landed" : "\(pendingCount) bills landed")
                .font(.benCardTitle)
                .foregroundStyle(Color.forestInk)
            Text(
                hasCompletedOnboarding
                    ? "They're waiting on Bills home. You can review or remove them there."
                    : "Give the first one a once-over now, or remove it if it isn't a bill."
            )
            .font(.benMeta)
            .foregroundStyle(Color.forestInk.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)

            if let first = pendingMonitor.previews.first {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.title)
                            .font(.benCardTitle)
                            .foregroundStyle(Color.forestInk)
                            .lineLimit(1)
                        Text(first.subtitle)
                            .font(.benMeta)
                            .foregroundStyle(Color.forestInk.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer()
                    if openingKey == first.id {
                        ProgressView().tint(.chartreuse)
                    }
                }
            }

            HStack(spacing: 12) {
                BenPrimaryButton(title: "Review") {
                    if let first = pendingMonitor.items.first {
                        open(first)
                    }
                }
                .disabled(openingKey != nil)
                BenTextButton(title: "Remove") {
                    if let key = pendingMonitor.items.first?.key {
                        Task {
                            await pendingMonitor.dismiss(
                                key: key,
                                accounts: services.accounts,
                                emailIn: services.emailIn
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .benRowSurface(radius: 24)
    }

    private func open(_ item: PendingEmailBill) {
        guard openingKey == nil else { return }
        openingKey = item.key
        openError = nil
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
                if hasCompletedOnboarding {
                    notificationRouter.confirmEmailBillRequested = true
                }
                dismiss()
            } catch {
                openError = "That one wouldn't open. Give it another go in a tick."
            }
        }
    }

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
            stepRow(number: "1", title: "Copy and forward",
                    detail: "Send any bill email to your Ben address (PDF attached is best).")
            stepRow(number: "2", title: "It lands on Bills",
                    detail: "Waiting bills show on your Bills home — named once Ben's had a read.")
            stepRow(number: "3", title: "You confirm",
                    detail: "Nothing is saved until you give the details a once-over.")
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
