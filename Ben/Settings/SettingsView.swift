import SwiftUI

/// Settings — the account hub. Widget-first: account card, subscription
/// widget, tool rows, quiet app info.
struct SettingsView: View {
    @Environment(\.services) private var services

    private enum Sheet: String, Identifiable {
        case account, export, emailIn
        var id: String { rawValue }
    }

    @State private var account: BenAccount?
    @State private var activeSheet: Sheet?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            BenCanvas()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.benTitle)
                        .foregroundStyle(Color.chartreuse)
                        .padding(.top, 18)
                        .accessibilityAddTraits(.isHeader)

                    accountWidget
                    subscriptionWidget

                    sectionLabel("Reminders")
                    RemindersSection()

                    sectionLabel("Tools")
                    toolRow(symbol: "envelope.fill", chip: (.sky, .onSky),
                            title: "Email bills in",
                            detail: account == nil ? "Needs your account" : "Your forwarding address") {
                        activeSheet = .emailIn
                    }
                    toolRow(symbol: "square.and.arrow.up", chip: (.amber, .onAmber),
                            title: "Export bills",
                            detail: "CSV for any period") {
                        activeSheet = .export
                    }
                    toolRow(symbol: "bell.badge.fill", chip: (.chartreuse, .onChartreuse),
                            title: "Notification settings",
                            detail: "Managed in iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                    sectionLabel("About")
                    infoRow(title: "Version", value: appVersion)
                    infoRow(title: "Your data", value: "On this device")
                    Text("You pay for Ben, so your data is never the product.")
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.5))
                        .padding(.horizontal, 4)

                    if account != nil {
                        Button {
                            services.accounts.signOut()
                            withAnimation(.spring(duration: 0.3)) { account = nil }
                        } label: {
                            Text("Sign out")
                                .font(.benLabel)
                                .foregroundStyle(Color.statusLateFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(BenPressable())
                        .benRowSurface(radius: 24)
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { account = services.accounts.account }
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .account:
                    AccountSheet { newAccount in
                        account = newAccount
                    }
                case .export:
                    ExportSheet()
                case .emailIn:
                    EmailInSheet()
                }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            .presentationBackground(Color.forestBottom)
        }
    }

    // MARK: Widgets

    /// Cream hero: who you are (or the invitation to be someone).
    private var accountWidget: some View {
        Group {
            if let account {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        BenEyebrow(text: "Account")
                        Spacer()
                        Text(account.provider.label)
                            .font(.benLabel)
                            .foregroundStyle(Color.onLavender)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.lavender, in: Capsule())
                    }
                    Text(account.name)
                        .font(.baloo("Baloo2-ExtraBold", 26, relativeTo: .title))
                        .foregroundStyle(Color.onCreamStrong)
                        .padding(.top, 6)
                    Text(account.email)
                        .font(.benMeta)
                        .foregroundStyle(Color.onCreamMuted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.colorScheme, .light)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .benShadow(.cream)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    BenEyebrow(text: "Account")
                    Text("Not signed in")
                        .font(.baloo("Baloo2-ExtraBold", 24, relativeTo: .title))
                        .foregroundStyle(Color.onCreamStrong)
                        .padding(.top, 6)
                    Text("Sync, backup, and email-in live behind one tap.")
                        .font(.benMeta)
                        .foregroundStyle(Color.onCreamMuted)
                    Button {
                        activeSheet = .account
                    } label: {
                        Text("Create my account")
                            .font(.benLabel)
                            .foregroundStyle(Color.onChartreuse)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.chartreuse, in: Capsule())
                    }
                    .buttonStyle(BenPressable())
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.colorScheme, .light)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .benShadow(.cream)
            }
        }
    }

    /// Subscription state, factually.
    private var subscriptionWidget: some View {
        let line: (String, String) = switch services.subscriptions.state() {
        case .notStarted: ("Trial not started", "The paywall must have been kind to you.")
        case .active(let days): (
            days == 1 ? "Trial: last day" : "Trial: \(days) days left",
            "Full access. Cancel anytime in one tap."
        )
        case .lapsed: ("Trial ended", "Bills stay visible; reminders are off.")
        }
        // HUMAN: RevenueCat — replace with live entitlement + manage link.
        return VStack(alignment: .leading, spacing: 2) {
            BenEyebrow(text: "Subscription", color: Color.forestInk.opacity(0.55))
            Text(line.0)
                .font(.benCardTitle)
                .foregroundStyle(Color.forestInk)
                .padding(.top, 4)
            Text(line.1)
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .benRowSurface(radius: 24)
    }

    // MARK: Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.benCardTitle)
            .foregroundStyle(Color.chartreuse)
            .padding(.top, 12)
            .padding(.horizontal, 4)
    }

    private func toolRow(
        symbol: String, chip: (fill: Color, icon: Color),
        title: String, detail: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                BenIconCircle(systemName: symbol, fill: chip.fill, iconColor: chip.icon)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.forestInk)
                    Text(detail)
                        .font(.benMeta)
                        .foregroundStyle(Color.forestInk.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.forestInk.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(BenPressable())
        .benRowSurface(radius: 26)
        .accessibilityIdentifier(title)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.benBody)
                .foregroundStyle(Color.forestInk)
            Spacer()
            Text(value)
                .font(.benMeta)
                .foregroundStyle(Color.forestInk.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .benRowSurface(radius: 20)
    }
}
