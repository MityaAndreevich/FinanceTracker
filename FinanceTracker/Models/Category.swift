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
    /// V2: no longer `@Attribute(.unique)` — CloudKit forbids it; uniqueness is
    /// a write-site responsibility (SeedService is idempotent by nameKey).
    var uuid: UUID = UUID()

    /// Legacy / fallback (оставляем, чтобы не ломать старые данные и миграции)
    var name: String = ""

    /// Localization key для системных категорий (например "category.food")
    var nameKey: String?

    /// Если юзер создал категорию руками — храним его текст отдельно
    var nameCustom: String?

    /// "expense" | "income"
    var kindRaw: String = "expense"

    /// SF Symbol name
    var icon: String?

    /// Sort order
    var order: Int = 0

    /// Ranking flag, NOT a visibility flag. False does not hide a category anywhere:
    /// `CategoryPickerSheet` — the single shared picker for both entry surfaces —
    /// filters on kind and search text only (CategoryPickerSheet.swift:35–38).
    ///
    /// What it actually decides, and the only things that read it:
    ///   • `QuickEntryView.swift:387–388` — which categories win the ≤6 quick chips
    ///   • `CategoryEntity.swift:63` — the Siri/Shortcuts default category
    ///   • `CategoryEntity.swift:75` — primary-first ordering in Siri disambiguation
    ///   • `CategoriesSourcesView.swift:458` — a live user-writable toggle
    ///
    /// The original doc here read "shown only when user taps 'Show all' in pickers".
    /// That two-step picker was removed; the sentence outlived it and seeded a
    /// matching false user-facing string (see LocaleCompletenessTests, 2026-08-13).
    /// Default true so existing user categories keep their ranking after migration.
    var isPrimary: Bool = true

    /// Optional monthly spend limit in cents (1.0.3 Item 3). nil = no limit —
    /// the default for every existing and new category. Only meaningful on
    /// expense categories; the UI never offers it on income ones.
    var limitCents: Int?

    /// Explicit inverse of Transaction.category (V2). `.nullify`: deleting a
    /// Category detaches its transactions — legal now that the far side is
    /// optional, and actually ENFORCED now that the inverse exists.
    /// CategoriesSourcesView keeps its "block delete while in use" UX on top.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    /// Explicit inverse of TransactionSplit.category. Same rule; "in use" for
    /// the delete guard now means transactions OR splits.
    @Relationship(deleteRule: .nullify, inverse: \TransactionSplit.category)
    var splits: [TransactionSplit]?

    init(
        uuid: UUID = UUID(),
        name: String,
        kindRaw: String,
        icon: String? = nil,
        order: Int = 0,
        nameKey: String? = nil,
        nameCustom: String? = nil,
        isPrimary: Bool = true,
        limitCents: Int? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.kindRaw = kindRaw
        self.icon = icon
        self.order = order
        self.nameKey = nameKey
        self.nameCustom = nameCustom
        self.isPrimary = isPrimary
        self.limitCents = limitCents
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
