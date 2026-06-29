//
//  Category.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import Foundation
import SwiftData

@Model
final class Category {

    /// Stable external identifier (used for UI selection, export/import, future cloud sync).
    /// Not the same as Category.ID, which is SwiftData's PersistentIdentifier.
    @Attribute(.unique) var uuid: UUID

    /// Legacy / fallback (оставляем, чтобы не ломать старые данные и миграции)
    var name: String

    /// Localization key для системных категорий (например "category.food")
    var nameKey: String?

    /// Если юзер создал категорию руками — храним его текст отдельно
    var nameCustom: String?

    /// "expense" | "income"
    var kindRaw: String

    /// SF Symbol name
    var icon: String?

    /// Sort order
    var order: Int

    /// False = shown only when user taps "Show all" in pickers. True = always visible.
    /// Default true so existing user categories stay visible after migration.
    var isPrimary: Bool = true

    init(
        uuid: UUID = UUID(),
        name: String,
        kindRaw: String,
        icon: String? = nil,
        order: Int = 0,
        nameKey: String? = nil,
        nameCustom: String? = nil,
        isPrimary: Bool = true
    ) {
        self.uuid = uuid
        self.name = name
        self.kindRaw = kindRaw
        self.icon = icon
        self.order = order
        self.nameKey = nameKey
        self.nameCustom = nameCustom
        self.isPrimary = isPrimary
    }
}

// MARK: - Helpers

extension Category {

    /// Есть ли валидный key для локализации
    var hasNameKey: Bool {
        !(nameKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Пользовательская ли категория (введена руками)
    var isUserDefined: Bool {
        !(nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Возвращает именно “человеческое” имя категории:
    /// 1) user-defined text
    /// 2) localized by key (если ключ есть и реально найден)
    /// 3) fallback: legacy name
    func displayName(locale: Locale = .current) -> String {
        if let custom = nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }

        if let key = nameKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            let localized = NSLocalizedString(key, comment: "")
            if localized != key { return localized }
        }

        return name
    }

    /// Same resolution as `displayName()` but resolves the localization key
    /// against an explicit `bundle` instead of `Bundle.main`. Needed where a
    /// plain `NSLocalizedString` would leak the launch language despite an
    /// in-app language override — e.g. the Quick Entry preview chip (Bug 1).
    /// Pass `LocalizedBundle.shared.bundle` for the active app language.
    func displayName(bundle: Bundle) -> String {
        if let custom = nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }

        if let key = nameKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            let localized = bundle.localizedString(forKey: key, value: key, table: nil)
            if localized != key { return localized }
        }

        return name
    }

    /// Ключ/текст для `Text(LocalizedStringKey(...))`
    /// 1) custom text (покажется как есть)
    /// 2) localization key (локализуется через Localizable.strings)
    /// 3) legacy name
    var displayKeyOrName: String {
        if let custom = nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        if let key = nameKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }
        return name
    }
}
