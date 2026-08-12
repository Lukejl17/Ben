import SwiftUI

/// Thumb-reach add-bill entry: chartreuse dial expanding into upload options.
struct AddBillDial: View {
    @Binding var expanded: Bool
    let onPick: (UploadMethod) -> Void
    var onEmailIn: (() -> Void)?

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if expanded {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    option(symbol: "camera.fill", fill: .amber, iconColor: .onAmber, label: "Take a photo") {
                        onPick(.camera)
                    }
                }
                option(symbol: "photo.on.rectangle.angled", fill: .amber, iconColor: .onAmber,
                       label: "Upload a photo") {
                    onPick(.photo)
                }
                option(symbol: "doc.fill", fill: .sky, iconColor: .onSky, label: "Upload a PDF or file") {
                    onPick(.pdf)
                }
                option(symbol: "envelope.fill", fill: .clay, iconColor: .onClay, label: "Email it in") {
                    onEmailIn?()
                }
            }

            Button {
                withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.onChartreuse)
                    .rotationEffect(.degrees(expanded ? 45 : 0))
                    .frame(width: 60, height: 60)
                    .background(Color.chartreuse, in: Circle())
            }
            .buttonStyle(BenPressable())
            .benShadow(.glow)
            .accessibilityLabel(expanded ? "Close" : "Add a bill")
            .accessibilityIdentifier("Add a bill")
        }
    }

    private func option(
        symbol: String, fill: Color, iconColor: Color, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.benLabel)
                    .foregroundStyle(Color.onCream)
                BenIconCircle(systemName: symbol, fill: fill, iconColor: iconColor, size: 36)
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 9)
            .background(Color.cream, in: Capsule())
        }
        .buttonStyle(BenPressable())
        .benShadow(.floating)
        .accessibilityIdentifier(label)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

}
