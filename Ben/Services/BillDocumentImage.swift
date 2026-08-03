import PDFKit
import UIKit

/// Renders bill source bytes (JPEG/PNG/HEIC or PDF) for confirm + detail previews.
/// PDF is stored as PDF; Vision OCR and this preview both rasterise page 0.
enum BillDocumentImage {
    static func uiImage(from data: Data, maxPixelWidth: CGFloat = 1200) -> UIImage? {
        if data.starts(with: Data("%PDF".utf8)) {
            return renderFirstPDFPage(data, maxPixelWidth: maxPixelWidth)
        }
        return UIImage(data: data)
    }

    static func renderFirstPDFPage(_ data: Data, maxPixelWidth: CGFloat = 1200) -> UIImage? {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(2.0, maxPixelWidth / bounds.width)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}
