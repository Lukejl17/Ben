import SwiftUI

/// Shows a photo or the first page of a PDF stored on a bill / pending confirm.
struct BillDocumentPreview: View {
    let data: Data
    var maxHeight: CGFloat = 260

    var body: some View {
        if let image = BillDocumentImage.uiImage(from: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .benShadow(.floating)
                .accessibilityLabel("Bill attachment")
        }
    }
}
