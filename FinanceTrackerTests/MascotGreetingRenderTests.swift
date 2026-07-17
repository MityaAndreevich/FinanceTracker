//
//  MascotGreetingRenderTests.swift
//  FinanceTrackerTests
//
//  Emits PNGs of the first-run greeting so a human can eyeball the mascot polish:
//  transparent crab on the full-bleed bcPage surface, no sticker edge, in Light
//  and Dark, at the smallest supported width, and at the largest Dynamic Type
//  (clip check). Not an assertion test — it exists to produce artifacts.
//
//  ImageRenderer reports blank through a live ScrollView, so each case is pinned to
//  a fixed device frame; with the content shorter than the frame the ScrollView
//  lays out inert and renders. Writes to NSTemporaryDirectory() for the run script.
//

import XCTest
import SwiftUI
@testable import FinanceTracker

@MainActor
final class MascotGreetingRenderTests: XCTestCase {

    func test_render_light_iphone16() throws {
        try render(name: "light_std", scheme: .light, size: CGSize(width: 393, height: 852))
    }

    func test_render_dark_iphone16() throws {
        try render(name: "dark_std", scheme: .dark, size: CGSize(width: 393, height: 852))
    }

    func test_render_dark_smallest() throws {
        // iPhone SE (1st/2nd gen) — smallest supported width & height.
        try render(name: "dark_se", scheme: .dark, size: CGSize(width: 320, height: 568))
    }

    func test_render_dark_ax5_smallest() throws {
        // Largest Dynamic Type at the smallest width. Height is the tall canvas the
        // ScrollView proposes (content scrolls in-app), so this shows the real wrap
        // rather than a fixed-frame squeeze — the horizontal clip check.
        try render(name: "dark_ax5_se", scheme: .dark,
                   size: CGSize(width: 320, height: 1400), typeSize: .accessibility5)
    }

    private func render(name: String,
                        scheme: ColorScheme,
                        size: CGSize,
                        typeSize: DynamicTypeSize = .large) throws {
        // Render the ScrollView-free content directly (ImageRenderer reports blank
        // through a live ScrollView) on the same full-bleed bcPage surface the real
        // view uses. colorScheme is injected via environment — ImageRenderer ignores
        // .preferredColorScheme.
        let view = ZStack {
            Color.bcPage
            MascotGreetingContent(containerSize: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.dynamicTypeSize, typeSize)
        .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = .init(size)

        let image = try XCTUnwrap(renderer.uiImage, "no image for \(name)")
        let attachment = XCTAttachment(image: image)
        attachment.name = "mascot_greeting_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
