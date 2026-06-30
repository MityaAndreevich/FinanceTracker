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
        case duplicateName
    }

    /// Builds a validated, **not yet inserted** `Category` from raw user input.
    ///
    /// Returns `.failure` instead of force-unwrapping or trapping so callers can
    /// show a localized error. An empty/whitespace icon is allowed (categories
    /// may have no icon); a non-empty icon must resolve to a real SF Symbol.
    ///
    /// Bug 18 (device test #4): creating a category with an already-used name
    /// failed silently. Pass the existing categories so the same-name collision
    /// is caught *before* insert and surfaced to the user. `existing` defaults to
    /// empty so call-sites that don't (yet) supply it keep their prior behavior.
    static func makeCategory(
        name: String,
        kindRaw: String,
        icon: String?,
        order: Int,
        existing: [Category] = []
    ) -> Result<Category, ValidationError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.emptyName) }

        if existing.contains(where: { matchesName(trimmedName, kindRaw: kindRaw, category: $0) }) {
            return .failure(.duplicateName)
        }

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

    /// True when `category` is the same kind and its user-facing name matches
    /// `name` case-insensitively. Compares the custom name and, for seeded
    /// categories, the localized name (never the raw key). Shared by the duplicate
    /// guard above and the picker's "reuse existing" affordance in AddCategorySheet.
    static func matchesName(_ name: String, kindRaw: String, category: Category) -> Bool {
        guard category.kindRaw == kindRaw else { return false }
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return false }

        if let custom = category.nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty, custom.lowercased() == lower {
            return true
        }
        if let key = category.nameKey, !key.isEmpty {
            let localized = NSLocalizedString(key, comment: "").lowercased()
            return localized != key.lowercased() && localized == lower
        }
        return false
    }
}
