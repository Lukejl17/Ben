import SwiftUI
import UIKit

/// Thumbnail of a bill attachment — tap opens a zoomable lightbox.
struct BillDocumentPreview: View {
    let data: Data
    var maxHeight: CGFloat = 260
    @State private var showLightbox = false

    var body: some View {
        if let image = BillDocumentImage.uiImage(from: data) {
            Button {
                showLightbox = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .benShadow(.floating)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.onCreamStrong)
                            .padding(8)
                            .background(Color.cream.opacity(0.92), in: Circle())
                            .padding(10)
                    }
            }
            .buttonStyle(BenPressable(haptic: .light))
            .accessibilityLabel("Bill attachment, tap to enlarge")
            .fullScreenCover(isPresented: $showLightbox) {
                BillDocumentLightbox(image: image)
            }
        }
    }
}

/// Full-screen zoomable look at the bill — pinch and pan, then close.
struct BillDocumentLightbox: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ZoomableImageView(image: image)
                .ignoresSafeArea()

            BenCircleButton(systemName: "xmark", accessibilityLabel: "Close") {
                dismiss()
            }
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .statusBarHidden(true)
    }
}

/// UIScrollView-backed pinch-zoom so the bill stays sharp when confirming details.
private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .black
        scroll.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.tag = 100
        scroll.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scroll
        context.coordinator.imageView = imageView
        DispatchQueue.main.async { context.coordinator.layoutImageIfNeeded() }
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.layoutImageIfNeeded()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var lastBounds: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        func layoutImageIfNeeded() {
            guard let scrollView else { return }
            let bounds = scrollView.bounds.size
            guard bounds.width > 0, bounds != lastBounds else { return }
            lastBounds = bounds
            layoutImage()
        }

        func layoutImage() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds.size
            guard bounds.width > 0, bounds.height > 0 else { return }

            let imageSize = image.size
            let widthRatio = bounds.width / imageSize.width
            let heightRatio = bounds.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

            imageView.frame = CGRect(origin: .zero, size: fitted)
            scrollView.contentSize = fitted
            scrollView.zoomScale = 1
            centerImage()
        }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            let bounds = scrollView.bounds.size
            let frame = imageView.frame
            let insetX = max((bounds.width - frame.width) * 0.5, 0)
            let insetY = max((bounds.height - frame.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(
                top: insetY, left: insetX, bottom: insetY, right: insetX
            )
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let zoom: CGFloat = 2.5
                let size = scrollView.bounds.size
                let width = size.width / zoom
                let height = size.height / zoom
                let rect = CGRect(
                    x: point.x - width / 2,
                    y: point.y - height / 2,
                    width: width,
                    height: height
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
