//
//  MascotGreetingRenderTests.swift
//  FinanceTrackerTests
//
//  Asserts the mascot-polish invariants and emits PNGs for eyeballing.
//
//  The original defect: the greeting was a card on a translucent scrim over the
//  live Dashboard, and the "crab" was a square PNG with a baked background — a
//  sticker with a visible edge. So the load-bearing checks are:
//    1. the surface renders FULLY OPAQUE in Light and Dark (no scrim), and the two
//       themes resolve to different colours (both actually apply);
//    2. the crab (brand-mint) actually draws — the render is not blank;
//    3. content scales with Dynamic Type up to AX5 without being capped or clipped.
//
//  ImageRenderer reports blank through a live ScrollView and ignores
//  .preferredColorScheme, so: the surface check renders the real view (its bcPage
//  fill is outside the ScrollView and stays opaque); the content checks render the
//  ScrollView-free MascotGreetingContent; colour scheme is injected via environment.
//

import XCTest
import SwiftUI
@testable import FinanceTracker

@MainActor
final class MascotGreetingRenderTests: XCTestCase {

    // Brand mint (Color.brand / the crab's body) — proves content drew.
    private let mint = (r: 61, g: 220, b: 151)

    // MARK: Surface is opaque and theme-adaptive (the scrim/card defect)

    func test_surface_is_opaque_and_theme_adapts() throws {
        let size = CGSize(width: 393, height: 852)
        let light = try renderRealView(scheme: .light, size: size)
        let dark = try renderRealView(scheme: .dark, size: size)
        attach(light, "greeting_light")
        attach(dark, "greeting_dark")

        // Expected pixel size (scale 2).
        XCTAssertEqual(light.size.width * light.scale, size.width * 2, accuracy: 1)
        XCTAssertEqual(light.size.height * light.scale, size.height * 2, accuracy: 1)

        let bl = RenderBitmap(light)
        let bd = RenderBitmap(dark)

        // The whole surface is opaque — a translucent scrim would render alpha < 255
        // at the corners (nothing but bcPage there).
        for p in bl.corners + [bl.center] {
            XCTAssertEqual(p.a, 255, "Light surface not fully opaque — scrim regressed?")
        }
        for p in bd.corners + [bd.center] {
            XCTAssertEqual(p.a, 255, "Dark surface not fully opaque — scrim regressed?")
        }

        // Light and Dark must resolve to visibly different surfaces (bcPage adapts);
        // if the scheme silently failed to apply, both corners would match.
        XCTAssertGreaterThan(bl.corners[0].rgbDistance(to: bd.corners[0]), 30,
                             "Light and Dark surfaces render identically — theme not applied")
    }

    // MARK: Content draws and scales with Dynamic Type without clipping

    func test_content_scales_with_dynamic_type_without_clipping() throws {
        // Smallest supported width; intrinsic height (what the in-app ScrollView
        // gives the content), so the image height IS the laid-out content height.
        let large = try renderContent(typeSize: .large, width: 320)
        let ax5 = try renderContent(typeSize: .accessibility5, width: 320)
        attach(ax5, "greeting_ax5")

        // The crab actually rendered in both — not a blank surface.
        XCTAssertTrue(RenderBitmap(large).containsColor(r: mint.r, g: mint.g, b: mint.b,
                                                        tolerance: 24),
                      "Crab (brand-mint) absent at default type — render is blank")
        XCTAssertTrue(RenderBitmap(ax5).containsColor(r: mint.r, g: mint.g, b: mint.b,
                                                      tolerance: 24),
                      "Crab (brand-mint) absent at AX5 — render is blank")

        // Content grows substantially with Dynamic Type. If the copy were capped,
        // truncated, or clipped to a fixed box, AX5 would not be markedly taller.
        XCTAssertGreaterThan(ax5.size.height, large.size.height * 1.3,
                             "AX5 content did not grow — type scaling capped or clipped")
    }

    // MARK: Renderers

    /// The real view (owns its bcPage surface); content is inside a ScrollView so it
    /// renders blank, but the surface fill does not — which is exactly what the
    /// opacity/theme assertions inspect.
    private func renderRealView(scheme: ColorScheme, size: CGSize) throws -> UIImage {
        let view = MascotGreetingView(coordinator: OnboardingCoordinator())
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = .init(size)
        return try XCTUnwrap(renderer.uiImage, "no surface image (\(scheme))")
    }

    /// The ScrollView-free content on the real bcPage surface, at an explicit width
    /// and intrinsic height (height == laid-out content height).
    private func renderContent(typeSize: DynamicTypeSize, width: CGFloat) throws -> UIImage {
        let view = ZStack {
            Color.bcPage
            MascotGreetingContent(containerSize: CGSize(width: width, height: 4000))
        }
        .frame(width: width)
        .environment(\.dynamicTypeSize, typeSize)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = .init(width: width, height: nil)
        return try XCTUnwrap(renderer.uiImage, "no content image (\(typeSize))")
    }

    private func attach(_ image: UIImage, _ name: String) {
        let a = XCTAttachment(image: image)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
