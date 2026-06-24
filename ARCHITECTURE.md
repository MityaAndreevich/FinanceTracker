# FinanceTracker — Architecture

A native iOS personal finance tracker built with SwiftUI and SwiftData. Designed for App Store submission, with full localization (28 languages), StoreKit 2 subscriptions, and no third-party dependencies.

## Stack

- **iOS 17+**, **Swift 5.9+**
- **SwiftUI** for all UI
- **SwiftData** for persistence (with `@Attribute(.unique)` and proper `@Relationship` delete rules)
- **StoreKit 2** for in-app purchases (monthly + yearly subscriptions, lifetime)
- **Charts** framework for analytics
- 28 localizations under `FinanceTracker/<locale>.lproj/Localizable.strings`
- No external dependencies — native APIs only
- **Xcode 16 file-system-synchronized project** — `FinanceTracker.xcodeproj` uses `PBXFileSystemSynchronizedRootGroup`, so any `.swift` file dropped into `FinanceTracker/` is auto-discovered and built. No `project.pbxproj` edits are required when adding source files.

## Project layout

```
FinanceTracker/
  FinanceTrackerApp.swift           App entry, SwiftData container, locale handling
  Models/
    Transaction.swift               @Model, monetary values as Int cents
    Category.swift                  @Model, supports both seeded (nameKey) and user-defined (nameCustom)
    Source.swift                    @Model — user-facing label is "Account"; class name kept for storage stability
    TransactionType.swift           Typed enum over Transaction.typeRaw
    SupportedCurrency.swift / SupportedLanguage.swift
  Shared/
    Money.swift                     Single source of truth for money parsing/formatting
    PeriodScope.swift               .month(Date) / .all, with shift / contains / filter
    PeriodSelector.swift            Reusable UI: month navigation + all/month toggle
    Keyboard.swift                  hideKeyboard() extension
    EmptyStateView.swift
  Views/                            Tabs (Dashboard, Transactions, Add, Analytics)
  Views/Settings/                   Settings tree + EditTransactionView
  Views/Onboarding/                 First-run language + currency picker
  Views/Components/                 SFSymbolPicker
  Data/SeedService.swift            Idempotent default-category seeding + legacy migration
  Services/
    CSVImportService.swift          RFC-4180 compliant parser, dedupes against seeded categories
    CSVExportService.swift
    TSVExportService.swift          Tab-separated for Excel users
    PDFExportService.swift          Fully localized, paginated
    TemporaryFileService.swift
  Purchases/
    PurchaseManager.swift           StoreKit 2 singleton (verification, restore, transaction listening)
    PaywallView.swift               Includes required legal disclosures (auto-renewal + Terms + Privacy links)
  PrivacyInfo.xcprivacy             Apple privacy manifest
FinanceTrackerTests/                CSV import + export unit tests
```

## Design decisions

### Money is stored as Int cents

Monetary values are stored as `amountCents: Int` (and `taxCents: Int?`) on `Transaction`. Float and Double are never used for money, because binary floating-point cannot represent decimal cents exactly and rounding errors compound across aggregations.

All parsing, sanitizing, and formatting goes through `Shared/Money.swift`:

- `Money.format(cents:currencyCode:)`
- `Money.formatSigned(cents:isPositive:currencyCode:)` — adds explicit `+`/`−` prefix (color-blind safe)
- `Money.parseCents(from:)`, `Money.sanitizeInput(_:)`, `Money.plainDecimalString(cents:)`

`NumberFormatter` instances are cached per currency code via `MoneyFormatterCache` since instantiation is expensive.

### Currency is locked to the user's default app-wide

A previous version allowed per-transaction currency, which produced incorrect totals when transactions spanned multiple currencies. The current model:

- New transactions are created with `currency: defaultCurrencyCode` (read from `@AppStorage`)
- Dashboard, Analytics, and PDF aggregation always read `defaultCurrencyCode`, never the first transaction's currency
- `EditTransactionView` intentionally has no currency picker

If a user changes their default currency in Settings, historical transactions retain their stored currency string, but reports render in the current default.

### Typed transaction kind

`TransactionType` is a typed enum (`.income` / `.expense`) layered over the raw String storage field `typeRaw` (kept for SwiftData stability). New code should use:

- `transaction.type`, `transaction.isIncome`, `transaction.isExpense`
- `transaction.signedAmountCents` (income positive, expense negative)
- `.tag(TransactionType.income.raw)` rather than `.tag("income")`

### Shared period scope

`PeriodScope` (`.month(Date)` / `.all`) is shared across Dashboard, Transactions, and Analytics. The `PeriodSelector` SwiftUI view encapsulates the month/all toggle plus left/right navigation between months. Each consuming view holds `@State private var scope: PeriodScope = .currentMonth` and filters via `scope.filter(transactions)`.

### Source / Account model

The SwiftData class is named `Source` (kept for storage stability). User-facing labels are "Account" — Card, Cash, Visa, Chase, etc. Accounts are available for **both** income and expense transactions, enabling per-account balance tracking in a future iteration.

### SwiftData constraints

- `uuid` is `@Attribute(.unique)` on `Transaction`, `Category`, `Source` — a stable external identifier independent of SwiftData's `PersistentIdentifier`. Useful for export/import and future iCloud sync.
- `Transaction.category` uses `@Relationship(deleteRule: .deny)`. The UI layer (`CategoriesSourcesView`) blocks deletion of categories in use.
- `Transaction.source` uses `@Relationship(deleteRule: .nullify)`.

### CSV parser (RFC 4180 compliant)

`CSVImportService.parseCSVLine` does **not** trim whitespace inside cells — that would corrupt quoted strings with intentional leading/trailing space. Trimming is applied at the caller for non-text fields (date, type, amount, currency). Category deduplication on import matches against the legacy English name, the localized name (via `nameKey`), and the custom name — preventing duplicate "Food" entries when importing into an existing seeded English categories set.

### Premium gating

- **Free**: this-month CSV / PDF / Excel export, view-only Dashboard and Analytics across any history
- **Premium**: all-time exports, CSV import

The paywall positions the yearly plan as "best value" and includes the auto-renewal disclosure plus tappable Terms of Use and Privacy Policy links — required by Apple's review guidelines.

## Build, test, run

```bash
# Build for simulator
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker -destination 'platform=iOS Simulator,name=iPhone 15' build

# Unit tests
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker -destination 'platform=iOS Simulator,name=iPhone 15' test

# Optional lint
swiftlint
```

## Conventions

- No third-party dependencies without an explicit reason
- Prefer `Shared/` utilities over local re-implementations
- Localize every user-facing string via `LocalizedStringKey` or `String(localized:)`; no hardcoded English in views
- Comments may be in Russian or English — preserve existing style
- SF Symbols for all iconography; users can pick custom icons via `SFSymbolPicker`
- Prefer `@Observable` over `@ObservedObject` for any new view models
- Any class touching `ModelContext` is `@MainActor`; SwiftData is not background-thread-safe without a `ModelActor`

## App Store readiness

### Done
- `PrivacyInfo.xcprivacy` with required reason API declarations (UserDefaults CA92.1, FileTimestamp C617.1)
- Paywall legal disclosures (auto-renewal, Terms, Privacy)
- Color-blind-safe transaction indicators (sign + arrow + color)
- Cleaned entitlements

### Still required before submission
- App icon set (iOS 18 light / dark / tinted variants)
- Real published Privacy Policy URL
- StoreKit products configured in App Store Connect (`ft_premium_monthly`, `ft_premium_yearly`, `ft_premium_lifetime`)
- ASO assets: screenshots, subtitle, keywords, description

### Roadmap
1. Complete localization for the 27 non-English locales (new keys: `paywall.legal.*`, `pdf.*`, `scope.previous_month`, etc.)
2. App icons
3. Biometric lock (Face ID / Touch ID) on app open
4. iCloud sync via SwiftData + CloudKit
5. Recurring transactions and per-category budgets
