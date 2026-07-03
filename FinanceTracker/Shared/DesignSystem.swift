//
//  DesignSystem.swift
//  FinanceTracker
//
//  Quiet Premium design tokens — single source of truth for the spacing,
//  corner-radius, shadow, and typography scale used across Budget Crab.
//  See AppStore/design-system/MASTER.md for the rationale.
//
//  Semantic colors live in Color+Semantic.swift; this file owns the
//  non-color layout primitives so views stop hardcoding magic numbers.
//

import SwiftUI

// MARK: - Spacing scale

/// 8-pt based spacing rhythm. Use these instead of raw paddings so vertical
/// rhythm stays consistent across screens.
enum Spacing {
    /// 4 — hairline gaps between tightly-coupled glyphs.
    static let xxs: CGFloat = 4
    /// 8 — inside a chip / between an icon and its label.
    static let xs: CGFloat = 8
    /// 12 — between stacked rows in a card.
    static let s: CGFloat = 12
    /// 16 — compact section padding.
    static let compact: CGFloat = 16
    /// 24 — default screen / section padding.
    static let `default`: CGFloat = 24
    /// 32 — generous separation between major sections.
    static let generous: CGFloat = 32
    /// 48 — hero breathing room.
    static let hero: CGFloat = 48
}

// MARK: - Corner radius scale

enum CornerRadius {
    /// 8 — small icon badges.
    static let icon: CGFloat = 8
    /// 12 — buttons.
    static let button: CGFloat = 12
    /// 16 — cards.
    static let card: CGFloat = 16
    /// 20 — emphasised hero cards.
    static let cardLarge: CGFloat = 20
    /// 24 — sheet top corners.
    static let sheet: CGFloat = 24
}

// MARK: - Elevation / shadow

/// Soft, low-opacity shadows. Quiet Premium uses elevation sparingly: one
/// resting level for cards, one slightly lifted level for the active CTA.
enum Elevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Resting card shadow — barely-there lift.
    static let card = Shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    /// Lifted card / active CTA.
    static let raised = Shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
}

extension View {
    /// Apply a token shadow.
    func elevation(_ shadow: Elevation.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Standard Quiet Premium card surface: rounded fill + resting shadow.
    func cardSurface(
        cornerRadius: CGFloat = CornerRadius.card,
        fill: Color = Color.bcCardFill
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .elevation(Elevation.card)
    }

    /// Redesign v2 elevated card: solid `bcSurface1` fill + 1px `bcDivider`
    /// border, radius 16. Depth comes from layered solid surfaces, not shadows
    /// or gradients (DESIGN_DIRECTION_v2 §2). Pads its content, then frames it.
    func bcCard(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = CornerRadius.card,
        fill: Color = .bcSurface1
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.bcDivider, lineWidth: 1)
            )
    }
}

// MARK: - Typography scale

extension Font {
    /// Hero amount display — 60pt rounded bold (e.g. Quick Entry amount).
    static let bcDisplay = Font.system(size: 60, weight: .bold, design: .rounded)
    /// Large amount (preview / dashboard net) — 40pt rounded bold.
    static let bcAmount = Font.system(size: 40, weight: .bold, design: .rounded)
    /// Screen title — 28pt rounded semibold.
    static let bcTitle = Font.system(size: 28, weight: .semibold, design: .rounded)
    /// Section header — 20pt semibold.
    static let bcSectionHeader = Font.system(size: 20, weight: .semibold)
    /// Body — 17pt regular.
    static let bcBody = Font.system(size: 17, weight: .regular)
    /// Caption — 13pt regular (pair with .secondary/.tertiary).
    static let bcCaption = Font.system(size: 13, weight: .regular)
}
