//
//  CategoryIconTile.swift
//  FinanceTracker
//
//  The redesign's category "tile": a rounded, category-colored square holding the
//  category's SF Symbol on a tinted background. One source of truth so every list
//  that shows a category (Categories settings, pickers, quick-entry chip) reads as
//  the same visual language as the Dashboard / Transactions rows.
//  Color + symbol come from the P1 theme map (Category+Theme).
//

import SwiftUI

struct CategoryIconTile: View {
    let category: Category
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(category.themeColor.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: category.symbolName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(category.themeColor)
            )
            .accessibilityHidden(true)
    }
}
