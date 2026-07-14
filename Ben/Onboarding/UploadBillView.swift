import SwiftUI

/// S4 — the ask, preceded by the trust block. Honest exit to B1.
struct UploadBillView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @State private var showNoBillSheet = false
    @State private var tonightNudgeScheduled = false

    var body: some View {
        BenScreen(title: coordinator.isAddingSubsequentBill ? "Add a bill" : "Your first bill") {
            BenCard {
                VStack(alignment: .leading, spacing: 16) {
                    trustRow(symbol: "doc.text.viewfinder", wash: (.washSkyBg, .washSkyFg),
                             text: "I read the issuer, amount and due date — nothing else.")
                    trustRow(symbol: "checkmark.seal", wash: (.washEucalyptusBg, .washEucalyptusFg),
                             text: "You confirm everything before it's saved.")
                    trustRow(symbol: "trash", wash: (.washAmberBg, .washAmberFg),
                             text: "Delete any bill, any time.")
                    trustRow(symbol: "lock", wash: (.washClayBg, .washClayFg),
                             text: "You pay for Ben, so your data is never the product.")
                }
            }
            .padding(.bottom, 12)

            Text("How do you want to hand it over?")
                .font(.benCardTitle)
                .foregroundStyle(Color.benInk)

            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    methodCard(symbol: "camera.fill", wash: (.washEucalyptusBg, .washEucalyptusFg),
                               label: "Take a photo", detail: "Point it at the bill — I'll do the reading", method: .camera)
                }
                methodCard(symbol: "photo.on.rectangle.angled", wash: (.washEucalyptusBg, .washEucalyptusFg),
                           label: "Choose a photo", detail: "From your photo library", method: .photo)
                methodCard(symbol: "doc.fill", wash: (.washSkyBg, .washSkyFg),
                           label: "PDF or file", detail: "Straight from an email attachment", method: .pdf)
                emailMethodRow
            }

            if tonightNudgeScheduled {
                HStack(spacing: 10) {
                    BenIconCircle(systemName: "moon.fill", wash: (.washAmberBg, .washAmberFg), size: 36)
                    BenVoiceText(text: "Done — I'll give you a nudge tonight. No rush.", quiet: true)
                }
                .padding(.top, 4)
            }
        } cta: {
            if !coordinator.isAddingSubsequentBill && !tonightNudgeScheduled {
                BenTextButton(title: "I don't have a bill handy") {
                    showNoBillSheet = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showNoBillSheet) {
            NoBillSheet(tonightNudgeScheduled: $tonightNudgeScheduled)
                .presentationDetents([.height(320)])
                .presentationCornerRadius(28)
                .presentationBackground(Color.benCanvas)
        }
    }

    private func trustRow(symbol: String, wash: (Color, Color), text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            BenIconCircle(systemName: symbol, wash: wash, size: 38)
            Text(text)
                .font(.benBody)
                .foregroundStyle(Color.benInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func methodCard(
        symbol: String, wash: (Color, Color), label: String, detail: String, method: UploadMethod
    ) -> some View {
        Button {
            coordinator.uploadMethod = method
            services.analytics.track(.billUploadStarted(uploadMethod: method.rawValue))
            coordinator.advance(to: .capture)
        } label: {
            HStack(spacing: 14) {
                BenIconCircle(systemName: symbol, wash: wash)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.benInk)
                    Text(detail)
                        .font(.benMeta)
                        .foregroundStyle(Color.benInkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.benInkMuted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.benCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(BenPressable())
        .benShadow(.card)
        .accessibilityIdentifier(label)
    }

    private var emailMethodRow: some View {
        HStack(spacing: 14) {
            BenIconCircle(systemName: "envelope.fill", wash: (.washClayBg, .washClayFg))
                .opacity(0.55)
            VStack(alignment: .leading, spacing: 2) {
                Text("Forward an email")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.benInkMuted)
                Text("Available after setup")
                    .font(.benMeta)
                    .foregroundStyle(Color.benInkMuted)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.benCard.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// B1 — no bill handy. Two honest paths; never a demo home screen.
private struct NoBillSheet: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @Binding var tonightNudgeScheduled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            BenVoiceText(text: "No worries — bills have a way of turning up. Two options:", quiet: true)
                .padding(.top, 30)

            BenPrimaryButton(title: "Remind me tonight", systemImage: "moon.fill") {
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

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
