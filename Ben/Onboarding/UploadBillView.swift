import SwiftUI

/// S4 — the ask, preceded by the trust block. Honest exit to B1.
struct UploadBillView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var showNoBillSheet = false
    @State private var tonightNudgeScheduled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(coordinator.isAddingSubsequentBill ? "Add a bill" : "Your first bill")
                .font(.benTitle)
                .foregroundStyle(Color.benInk)
                .padding(.top, 48)

            BenCard {
                VStack(alignment: .leading, spacing: 10) {
                    trustRow(symbol: "doc.text.viewfinder", text: "I read the issuer, amount and due date — nothing else.")
                    trustRow(symbol: "checkmark.circle", text: "You confirm everything before it's saved.")
                    trustRow(symbol: "trash", text: "Delete any bill, any time.")
                    trustRow(symbol: "lock", text: "You pay for Ben, so your data is never the product.")
                }
            }

            VStack(spacing: 10) {
                methodButton(symbol: "camera", label: "Photo", method: .photo)
                methodButton(symbol: "doc", label: "PDF or file", method: .pdf)
                emailMethodRow
            }

            if tonightNudgeScheduled {
                BenVoiceText(text: "Done — I'll give you a nudge tonight. No rush.")
                    .font(.benMeta)
            }

            Spacer()

            if !coordinator.isAddingSubsequentBill {
                BenSecondaryButton(title: "I don't have a bill handy") {
                    showNoBillSheet = true
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showNoBillSheet) {
            NoBillSheet(tonightNudgeScheduled: $tonightNudgeScheduled)
                .presentationDetents([.medium])
        }
    }

    private func trustRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Color.benAccent)
                .frame(width: 22)
            Text(text)
                .font(.benBody)
                .foregroundStyle(Color.benInkSecondary)
        }
    }

    private func methodButton(symbol: String, label: String, method: UploadMethod) -> some View {
        Button {
            coordinator.uploadMethod = method
            services.analytics.track(.billUploadStarted(uploadMethod: method.rawValue))
            coordinator.advance(to: .capture)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                Text(label)
                    .font(.benLabel)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Color.benInkMuted)
            }
            .padding(16)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.benHairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.benInk)
    }

    private var emailMethodRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope")
            VStack(alignment: .leading, spacing: 2) {
                Text("Forward an email")
                    .font(.benLabel)
                Text("Available after setup")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.benCard.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.benHairline, lineWidth: 0.5))
        .foregroundStyle(Color.benInkMuted)
    }
}

/// B1 — no bill handy. Two honest paths; never a demo home screen.
private struct NoBillSheet: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @Binding var tonightNudgeScheduled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BenVoiceText(text: "No worries — bills have a way of turning up. Two options:")
                .padding(.top, 28)

            BenPrimaryButton(title: "Remind me tonight") {
                services.analytics.track(.activationDeferred)
                let scheduler = services.scheduler
                Task {
                    _ = await scheduler.requestPermission()
                    await scheduler.scheduleTonightNudge()
                }
                tonightNudgeScheduled = true
                dismiss()
            }

            BenSecondaryButton(title: "Show me how it works with a sample bill") {
                services.analytics.track(.activationDeferred)
                dismiss()
                coordinator.startSampleWalkthrough()
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationBackground(Color.benCanvas)
    }
}
