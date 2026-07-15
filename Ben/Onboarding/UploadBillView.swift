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
                    trustRow(symbol: "doc.text.viewfinder", fill: .sky, iconColor: .onSky,
                             text: "I read the issuer, amount and due date — nothing else.")
                    trustRow(symbol: "checkmark.seal", fill: .chartreuse, iconColor: .onChartreuse,
                             text: "You confirm everything before it's saved.")
                    trustRow(symbol: "trash", fill: .amber, iconColor: .onAmber,
                             text: "Delete any bill, any time.")
                    trustRow(symbol: "lock", fill: .clay, iconColor: .onClay,
                             text: "You pay for Ben, so your data is never the product.")
                }
            }
            .padding(.bottom, 12)

            Text("How do you want to hand it over?")
                .font(.benCardTitle)
                .foregroundStyle(Color.forestInk)

            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    methodCard(symbol: "camera.fill", chip: (.chartreuse, .onChartreuse),
                               label: "Take a photo", detail: "Point it at the bill — I'll do the reading", method: .camera)
                }
                methodCard(symbol: "photo.on.rectangle.angled", chip: (.chartreuse, .onChartreuse),
                           label: "Choose a photo", detail: "From your photo library", method: .photo)
                methodCard(symbol: "doc.fill", chip: (.sky, .onSky),
                           label: "PDF or file", detail: "Straight from an email attachment", method: .pdf)
                emailMethodRow
            }

            if tonightNudgeScheduled {
                HStack(spacing: 10) {
                    BenIconCircle(systemName: "moon.fill", fill: .amber, iconColor: .onAmber, size: 36)
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
                .presentationBackground(Color.forestBottom)
        }
    }

    private func trustRow(symbol: String, fill: Color, iconColor: Color, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            BenIconCircle(systemName: symbol, fill: fill, iconColor: iconColor, size: 38)
            Text(text)
                .font(.benBody)
                .foregroundStyle(Color.onCream)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func methodCard(
        symbol: String, chip: (fill: Color, icon: Color), label: String, detail: String, method: UploadMethod
    ) -> some View {
        Button {
            coordinator.uploadMethod = method
            services.analytics.track(.billUploadStarted(uploadMethod: method.rawValue))
            coordinator.advance(to: .capture)
        } label: {
            HStack(spacing: 14) {
                BenIconCircle(systemName: symbol, fill: chip.fill, iconColor: chip.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.benCardTitle)
                        .foregroundStyle(Color.onCream)
                    Text(detail)
                        .font(.benMeta)
                        .foregroundStyle(Color.onCreamMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.onCreamMuted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
        .accessibilityIdentifier(label)
    }

    private var emailMethodRow: some View {
        HStack(spacing: 14) {
            BenIconCircle(systemName: "envelope.fill", fill: .clay, iconColor: .onClay)
                .opacity(0.55)
            VStack(alignment: .leading, spacing: 2) {
                Text("Forward an email")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
                Text("Available after setup")
                    .font(.benMeta)
                    .foregroundStyle(Color.forestInk.opacity(0.5))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cream.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
