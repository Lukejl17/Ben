import Foundation
import PDFKit
import UIKit
import Vision

/// On-device OCR: Vision text recognition feeding the pure heuristics.
struct VisionBillParser: BillParsing {
    func parse(_ data: Data) async throws -> ParsedBill {
        let cgImage = try Self.cgImage(from: data)
        let lines = try await Self.recognizeText(in: cgImage)
        guard !lines.isEmpty else { throw BillParsingError.noTextFound }
        return BillTextHeuristics().extract(from: lines)
    }

    // MARK: Input handling

    private static func cgImage(from data: Data) throws -> CGImage {
        if data.starts(with: Data("%PDF".utf8)) {
            return try renderFirstPDFPage(data)
        }
        guard let image = UIImage(data: data)?.cgImage else {
            throw BillParsingError.unreadableImage
        }
        return image
    }

    private static func renderFirstPDFPage(_ data: Data) throws -> CGImage {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else {
            throw BillParsingError.unreadableImage
        }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        guard let cgImage = image.cgImage else { throw BillParsingError.unreadableImage }
        return cgImage
    }

    // MARK: Vision

    private static func recognizeText(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Top-to-bottom reading order; Vision's Y axis is bottom-up.
                let lines = observations
                    .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-AU", "en-US"]
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Deterministic parser for previews and UI tests: always returns the fixture AGL bill.
struct MockBillParser: BillParsing {
    var result: ParsedBill

    init(result: ParsedBill? = nil) {
        self.result = result ?? Self.aglFixture
    }

    static var aglFixture: ParsedBill {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 24
        components.hour = 12
        return ParsedBill(
            issuer: "AGL",
            amount: Decimal(string: "243.00"),
            dueDate: Calendar.current.date(from: components),
            confidence: 1.0
        )
    }

    func parse(_ data: Data) async throws -> ParsedBill {
        try await Task.sleep(for: .milliseconds(600))  // visible "Reading it now…" state
        return result
    }
}

/// A parser that always fails — drives the B2 manual-entry branch in tests.
struct FailingBillParser: BillParsing {
    func parse(_ data: Data) async throws -> ParsedBill {
        throw BillParsingError.noTextFound
    }
}
