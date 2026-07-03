//
//  Color+Semantic.swift
//  FinanceTracker
//
//  Quiet Premium semantic color tokens. The brand accent stays the Budget Crab
//  mint (mirrors the AccentColor asset); these tokens add light/dark-adaptive
//  income / expense / surface colors so views stop reaching for raw
//  `Color.green` / `Color.red`, which read poorly in daylight.
//
//  Money sign is *never* communicated by color alone — Money.formatSigned adds
//  an explicit +/− and the UI pairs an arrow glyph — so these hues are an
//  accent, not the signal (color-blind safe).
//

import SwiftUI
import UIKit

extension Color {

    // MARK: Brand

    /// Budget Crab brand mint. Mirrors `AccentColor.colorset` so code paths that
    /// can't use `.accentColor` (e.g. gradients) stay on-brand.
    static let brand = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)

    // MARK: Money semantics

    /// Income — a deep, confident green in light mode (4.5:1+ on cream/white for
    /// large amounts) brightening for dark mode. Replaces ad-hoc `.green`.
    static let bcIncome = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.84, blue: 0.62, alpha: 1)   // mint-forward
            : UIColor(red: 0.10, green: 0.56, blue: 0.38, alpha: 1)   // deep emerald
    })

    /// Expense — muted warm terracotta rather than alarm-red. Calmer, premium,
    /// still clearly "money out". Replaces ad-hoc `.red` for amounts.
    static let bcExpense = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.53, blue: 0.44, alpha: 1)   // warm clay
            : UIColor(red: 0.75, green: 0.33, blue: 0.24, alpha: 1)   // burnt terracotta
    })

    // MARK: Surfaces

    /// Primary card fill — sits one step above the screen background with a
    /// faint warm tint so cards read on both cream and charcoal backdrops.
    static let bcCardFill = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor.secondarySystemBackground
    })

    /// Subtle warm separator / hairline.
    static let bcSeparator = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.06)
    })

    // MARK: Helpers

    /// Money color for a signed amount (positive = income).
    ///
    /// Legacy: this paints expenses in terracotta (`bcExpense`), the monochrome
    /// look retired in redesign v2. Prefer `moneyDirectional` for net / delta /
    /// budget readouts (where direction is the message) and `bcTextPrimary` for a
    /// single expense amount (which is normal, not an alert). Kept only for the few
    /// pre-redesign surfaces not yet migrated.
    static func money(isPositive: Bool) -> Color {
        isPositive ? .bcIncome : .bcExpense
    }

    /// Directional money color for **net / delta / over-budget** values, where the
    /// sign is the message: `bcPositive` (green) when up/positive, calm `bcDanger`
    /// (coral) when down/negative. Pair with an up/down arrow. Distinct from an
    /// individual expense amount, which renders neutral in `bcTextPrimary`.
    /// (DESIGN_DIRECTION_v2 §Locked decision 2.)
    static func moneyDirectional(isPositive: Bool) -> Color {
        isPositive ? .bcPositive : .bcDanger
    }

    // MARK: - Redesign v2 semantic tokens
    //
    // Dark-default token set from `outputs/DESIGN_DIRECTION_v2.md` §1. These are
    // backed by Asset Catalog color sets (Any + Dark appearances) under
    // Assets.xcassets, so Xcode auto-generates the type-safe accessors
    // (`Color.bcPage`, `Color.bcSurface1`, `Color.bcTextPrimary`, `.bcDivider`,
    // `.bcAccent`, `.bcPositive`, `.bcWarning`, `.bcDanger`, …). No manual
    // declarations are needed here — adding them would collide with the
    // generated symbols. New (redesigned) screens reach for these instead of raw
    // system colors; the older `bcCardFill` / `bcIncome` / `bcExpense` tokens
    // above stay for screens not yet migrated.
    //
    // Rule: expenses are NOT alarm-red. Amounts render in `bcTextPrimary`; red
    // (`bcDanger`) is reserved for genuine over-budget / alert states. Income
    // renders in `bcPositive`.
}
