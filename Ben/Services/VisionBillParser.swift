import Foundation
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
        guard let image = BillDocumentImage.uiImage(from: data),
              let cgImage = image.cgImage else {
            throw BillParsingError.unreadableImage
        }
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
            confidence: 1.0,
            payment: PaymentDetails(
                bpayBillerCode: "93880",
                bpayReference: "204344556677",
                bsb: "062000",
                accountNumber: "13579246",
                eftReference: "204344556677"
            )
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
