//
//  PaywallClarityRenderTests.swift
//  FinanceTrackerTests
//
//  Emits a PNG of the free-vs-Premium clarity block for eyeballing with real
//  localized strings — the live paywall only appears inside a StoreKit-backed cover
//  that won't load under `simctl`, so this is the only way to see it before ship.
//
//  OPT-IN, NOT IN THE DEFAULT SUITE. This block exists because RU labels were
//  CLIPPING, and that specific defect is NOT cheaply assertable in this rig:
//    - an isolated `Text` given a narrow width WRAPS rather than truncates, so the
//      clip only reproduces under the vertical compression the real paywall applies
//      and this harness does not;
//    - a "RU renders at least as tall as EN" check was tried and PROVEN toothless —
//      forcing every label to `.lineLimit(1)` (the truncation regression) still left
//      RU ≥ EN, so the assertion passed through the exact bug it claimed to catch;
//    - `.thinMaterial` / `.secondary` don't composite under ImageRenderer at all.
//  Rather than carry a guard that can't fail for its own reason, this runs only when
//  RENDER_ARTIFACTS=1, and asserts only what genuinely has teeth here (the render is
//  non-blank, correctly sized, opaque). RU clipping stays a device-QA check.
//

import XCTest
import SwiftUI
@testable import FinanceTracker

@MainActor
final class PaywallClarityRenderTests: XCTestCase {

    private let mint = (r: 61, g: 220, b: 151)   // Color.brand (checkmarks / lock)

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RENDER_ARTIFACTS"] == "1",
            "Opt-in artifact render — its reason (RU label clipping) is not cheaply "
            + "assertable here (see file header). Run with RENDER_ARTIFACTS=1."
        )
    }

    func test_render_clarity_en() throws { try assertRenders(locale: "en") }
    func test_render_clarity_ru() throws { try assertRenders(locale: "ru") }

    private func assertRenders(locale: String) throws {
        let image = try render(locale: locale)
        attach(image, "paywall_clarity_\(locale)")

        // Correctly sized at the fixed iPhone content width (scale 3), non-empty.
        XCTAssertEqual(image.size.width * image.scale, 393 * 3, accuracy: 1)
        XCTAssertGreaterThan(image.size.height, 0)

        let bmp = RenderBitmap(image)
        // The block actually drew — brand-mint check/lock glyphs are present.
        XCTAssertTrue(bmp.containsColor(r: mint.r, g: mint.g, b: mint.b, tolerance: 28),
                      "\(locale): brand-mint glyphs absent — render is blank/broken")
        // Opaque black backdrop (the paywall is always dark).
        for p in bmp.corners {
            XCTAssertEqual(p.a, 255, "\(locale): backdrop not opaque")
        }
    }

    private func render(locale: String) throws -> UIImage {
        let view = PaywallClarityView()
            .environment(\.locale, Locale(identifier: locale))
            .frame(width: 361)                 // iPhone content width (393 − 2×16)
            .padding(.horizontal, 16)
            .background(Color.black)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = .init(width: 393, height: nil)
        return try XCTUnwrap(renderer.uiImage, "no image for \(locale)")
    }

    private func attach(_ image: UIImage, _ name: String) {
        let a = XCTAttachment(image: image)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
