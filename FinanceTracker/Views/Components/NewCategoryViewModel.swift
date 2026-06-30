//
//  NewCategoryViewModel.swift
//  FinanceTracker
//
//  Pure, testable validation/build step for the "Add Category" flow.
//
//  Bug 16 (device test #3): tapping Add after selecting the "car" icon crashed
//  the app. The category-create path built and inserted a Category with no
//  validation, so any malformed input (an icon name SwiftUI/UIKit can't render,
//  an all-whitespace name) reached `modelContext.save()` unchecked. This type
//  moves all of that into a single function that returns a `Result` instead of
//  trapping — the view surfaces an inline error and never crashes.
//

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum NewCategoryViewModel {

    enum ValidationError: Error, Equatable {
        case emptyName
        case invalidIcon(String)
    }

    /// Builds a validated, **not yet inserted** `Category` from raw user input.
    ///
    /// Returns `.failure` instead of force-unwrapping or trapping so callers can
    /// show a localized error. An empty/whitespace icon is allowed (categories
    /// may have no icon); a non-empty icon must resolve to a real SF Symbol.
    static func makeCategory(
        name: String,
        kindRaw: String,
        icon: String?,
        order: Int
    ) -> Result<Category, ValidationError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.emptyName) }

        let trimmedIcon = icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedIcon: String?
        if trimmedIcon.isEmpty {
            resolvedIcon = nil
        } else if isRenderableSymbol(trimmedIcon) {
            resolvedIcon = trimmedIcon
        } else {
            return .failure(.invalidIcon(trimmedIcon))
        }

        let category = Category(
            name: trimmedName,
            kindRaw: kindRaw,
            icon: resolvedIcon,
            order: order,
            nameKey: nil,
            nameCustom: trimmedName
        )
        return .success(category)
    }

    /// True when `name` is a system symbol UIKit can actually instantiate.
    /// An unrenderable name would otherwise render blank (and historically
    /// contributed to the create-path crash). On platforms without UIKit we
    /// accept the name rather than block category creation.
    static func isRenderableSymbol(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(systemName: name) != nil
        #else
        return true
        #endif
    }
}
