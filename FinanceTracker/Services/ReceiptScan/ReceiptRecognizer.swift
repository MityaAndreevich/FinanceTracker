//
//  ReceiptRecognizer.swift
//  FinanceTracker
//
//  The only impure step of scanning: a `CGImage` in, recognised lines out,
//  through Vision's on-device text recogniser. No network — `Vision` runs
//  locally, the image never leaves the process, and `NoNetworkInScanModuleTests`
//  fails the suite if a networking symbol ever appears in this directory.
//
//  Languages: the app language first, then the other four, so a Russian user
//  photographing an English receipt still gets English keywords recognised.
//  Whether Vision on the deployment target supports Ukrainian is NOT assumed —
//  `supportedLanguages()` is asked in code, `VisionLanguageSupportTests` records
//  the answer, and the corpus measurement decides (DESIGN_RECEIPT_SCAN.md §4.1,
//  founder's decision 4).
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

enum ReceiptRecognizer {

    /// Longest side after downscale. Vision's accurate model gains nothing
    /// above this, and a 48 MP capture is not a phone's problem to hold twice.
    static let maxLongSide = 2200

    /// Vision language codes for the five shipped locales, app language first.
    /// Vision's Spanish is `es-ES` (there is no `es-MX` model — measured
    /// 2026-09-21 via `supportedRecognitionLanguages()`); the recogniser is
    /// language-level, and MX vs ES spelling does not change digits or
    /// "TOTAL A PAGAR".
    static func preferredLanguages(appLanguageCode: String?) -> [String] {
        let all = ["en-US", "ru-RU", "es-ES", "pt-BR", "uk-UA"]
        let first: String
        switch appLanguageCode {
        case "ru": first = "ru-RU"
        case "es": first = "es-ES"
        case "pt", "pt-BR": first = "pt-BR"
        case "uk": first = "uk-UA"
        default: first = "en-US"
        }
        return [first] + all.filter { $0 != first }
    }

    /// What Vision on THIS device and OS will accept. Asked, not assumed.
    static func supportedLanguages() throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return try request.supportedRecognitionLanguages()
    }

    /// The intersection of what we want and what Vision supports, in our order.
    /// `uk-UA` missing on the deployment target means Ukrainian receipts are
    /// recognised with ru + en — and measured as such (§7), never assumed fine.
    static func usableLanguages(appLanguageCode: String?) throws -> [String] {
        let supported = Set(try supportedLanguages())
        return preferredLanguages(appLanguageCode: appLanguageCode).filter { code in
            supported.contains(code) || supported.contains(String(code.prefix(2)))
        }
    }

    struct Result: Sendable {
        let lines: [RecognizedLine]
        let languagesUsed: [String]
    }

    /// Runs off the calling thread. Lines come back in reading order (top to
    /// bottom by their box's top edge), which is the order the parser ranks by.
    static func recognize(_ image: CGImage, appLanguageCode: String?) async throws -> Result {
        let languages = try usableLanguages(appLanguageCode: appLanguageCode)
        let scaled = downscaled(image)
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations
                    .compactMap { obs -> RecognizedLine? in
                        guard let top = obs.topCandidates(1).first else { return nil }
                        return RecognizedLine(text: top.string, box: obs.boundingBox, confidence: top.confidence)
                    }
                    // Vision's box origin is bottom-left; higher maxY = higher on the page.
                    .sorted { a, b in
                        if abs(a.box.maxY - b.box.maxY) > 0.008 { return a.box.maxY > b.box.maxY }
                        return a.box.minX < b.box.minX
                    }
                continuation.resume(returning: Result(lines: lines, languagesUsed: languages))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages
            let handler = VNImageRequestHandler(cgImage: scaled, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func downscaled(_ image: CGImage) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxLongSide else { return image }
        let scale = CGFloat(maxLongSide) / CGFloat(longest)
        let w = Int(CGFloat(image.width) * scale), h = Int(CGFloat(image.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}
