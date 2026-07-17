import SwiftUI

/// Screen 2 — prove the magic before asking anything. A sample bill scans,
/// fields extract one by one, then the exact notification they'd get.
struct DemoScanView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var revealed = 0

    var body: some View {
        BenScreen {
            VStack(spacing: 12) {
                Text("A sample bill. Watch.")
                    .font(.baloo("Baloo2-ExtraBold", 24, relativeTo: .title2))
                    .foregroundStyle(Color.chartreuse)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                sampleBill

                foundRow("Issuer", "AGL", visible: revealed >= 1)
                foundRow("Amount", "$243.00", visible: revealed >= 2)
                foundRow("Due date", "24 July", visible: revealed >= 3)

                notification
                    .opacity(revealed >= 4 ? 1 : 0)
                    .offset(y: revealed >= 4 ? 0 : 12)
            }
        } cta: {
            BenPrimaryButton(title: "That, but for my bills") {
                coordinator.advance(to: .intent)
            }
        }
        .task {
            for step in 1...4 {
                try? await Task.sleep(for: .seconds(step == 4 ? 0.6 : 0.45))
                withAnimation(.spring(duration: 0.4)) { revealed = step }
            }
        }
    }

    private var sampleBill: some View {
        BenCard(padding: 16, radius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AGL Electricity")
                    .font(.baloo("Baloo2-Bold", 16, relativeTo: .headline))
                    .foregroundStyle(Color.onCream)
                Text("Tax Invoice · Account 3344 5566")
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
                    .padding(.bottom, 4)
                billLine("Usage this quarter", "$198.40")
                billLine("Supply charge", "$44.60")
                billLine("Amount due", "$243.00", bold: true)
                billLine("Due date", "24 July")
            }
        }
        .overlay {
            ScanlineOverlay()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func billLine(_ label: String, _ value: String, bold: Bool = false) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(label)
                Spacer()
                Text(value).monospacedDigit()
            }
            .font(bold ? .benLabel : .benMeta)
            .foregroundStyle(bold ? Color.onCream : Color.onCreamMuted)
            Line()
                .stroke(Color.onCreamMuted.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(height: 1)
        }
    }

    private func foundRow(_ label: String, _ value: String, visible: Bool) -> some View {
        HStack {
            Text(label)
                .font(.benLabel)
                .foregroundStyle(Color.forestInk)
            Spacer()
            Text("\(value) ✓")
                .font(.benLabel)
                .monospacedDigit()
                .foregroundStyle(Color.chartreuse)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .benRowSurface(radius: 16)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
    }

    private var notification: some View {
        HStack(alignment: .top, spacing: 10) {
            BenCharacter(size: 30)
                .frame(width: 34, height: 34)
                .background(Color.chartreuse, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ben")
                    .font(.baloo("Baloo2-Bold", 13, relativeTo: .footnote))
                    .foregroundStyle(Color.onCream)
                Text("Ben here. AGL is due Friday. That's all.")
                    .font(.benMeta)
                    .foregroundStyle(Color.onCreamMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.cream.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .light)
        .benShadow(.cream)
    }
}

/// The chartreuse scan bar sweeping down the sample bill.
private struct ScanlineOverlay: View {
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.chartreuse.opacity(0), .chartreuse.opacity(0.4), .chartreuse.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)
            .offset(y: sweep ? geo.size.height : -44)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: false),
                value: sweep
            )
        }
        .allowsHitTesting(false)
        .onAppear { sweep = true }
    }
}

/// A simple horizontal line shape for dashed rules.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}
