//
//  PaywallClarityRenderTests.swift
//  FinanceTrackerTests
//
//  Renders the free-vs-Premium table + data-safety callout to a PNG so a human can
//  eyeball the layout with real localized strings. The live paywall only appears
//  inside a StoreKit-backed cover that won't load under `simctl`, so this is the
//  only way to see the actual view before shipping.
//
//  Not an assertion test — it exists to emit an artifact. It uses no ScrollView
//  (ImageRenderer reports blank through one), renders at a fixed iPhone content
//  width, and writes to NSTemporaryDirectory() where the run script can pull it.
//

import XCTest
import SwiftUI
@testable import FinanceTracker

@MainActor
final class PaywallClarityRenderTests: XCTestCase {

    func test_render_clarity_en() throws { try render(locale: "en") }
    func test_render_clarity_ru() throws { try render(locale: "ru") }

    private func render(locale: String) throws {
        let view = PaywallClarityView()
            .environment(\.locale, Locale(identifier: locale))
            .frame(width: 361)                 // iPhone 16 Pro content width (393 − 2×16)
            .padding(.horizontal, 16)
            .background(Color.black)            // the paywall is always dark
            .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = .init(width: 393, height: nil)

        let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer produced no image for \(locale)")
        let png = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("paywall_clarity_\(locale).png")
        try png.write(to: url)
        print("PAYWALL_CLARITY_PNG \(locale) \(url.path)")
    }
}
