# FinanceTracker

A lightweight personal finance tracker for iOS, built with **SwiftUI** and **SwiftData**.
Focus on simplicity, clarity, and data ownership — every financial record stays on the user's device.

> For implementation details, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Features

### Tracking
- Add income and expense transactions with optional tax, merchant, and free-form note
- Categorize transactions with seeded defaults or custom categories (custom SF Symbol icon)
- Track which account/card paid for each transaction (Cash, Visa, Chase, etc.)
- Edit and delete from the transactions list with swipe actions and a context menu

### Dashboard
- Monthly summary cards: income, expenses, net balance
- Top-5 expense categories and top-5 income accounts at a glance
- Month-by-month navigation (previous month / next month / all time)

### Analytics
- Line, bar, and pie charts powered by Swift Charts
- Expenses grouped by category, income grouped by account
- Diacritic-insensitive search across merchant / category / account / note

### Export & Import
- CSV, TSV (Excel-friendly), and PDF export for the current month
- Full all-time export under Premium
- CSV import with automatic category/account deduplication and a per-row error report
- All data leaves and re-enters the device through the system Share Sheet — never via the network

### Privacy
- No analytics SDKs, no tracking, no ads
- All data lives in a local SwiftData store
- Ships with Apple's privacy manifest (`PrivacyInfo.xcprivacy`)

### Premium (StoreKit 2)
- Monthly, yearly, and lifetime tiers
- Paywall includes Apple-required auto-renewal disclosure and Terms / Privacy links
- Restore Purchases supported

### Localization
- 28 languages out of the box
- Currency selection per user; transactions are denominated in the user's chosen currency
- RTL-aware layout handling for Arabic and Hebrew

---

## Tech stack

- **iOS 17+**, Swift 5.9+
- **SwiftUI** for all UI
- **SwiftData** for persistence
- **Swift Charts** for analytics
- **StoreKit 2** for in-app purchases
- **No third-party dependencies** — native APIs only

---

## CSV format

```
date,type,amount,currency,category,source,tax,note,merchant
```

| Column   | Description                                       |
|----------|---------------------------------------------------|
| `date`   | ISO format (`YYYY-MM-DD`)                         |
| `type`   | `income` or `expense`                             |
| `amount` | Decimal (e.g. `12.34`)                            |
| `currency` | ISO currency code (e.g. `USD`)                  |
| `category` | Category name (required)                        |
| `source` | Account name (optional)                           |
| `tax`    | Decimal tax amount (optional)                     |
| `note`   | Free text (optional)                              |
| `merchant` | Free text (optional)                            |

Parser is RFC 4180 compliant — quoted commas, embedded quotes, and multiline cells are handled.

---

## Getting started

```bash
git clone https://github.com/<user>/FinanceTracker.git
cd FinanceTracker
open FinanceTracker.xcodeproj
```

Pick an iOS Simulator (iPhone 15+ recommended), build and run.

---

## Roadmap

### Pre-launch
- App icon set (iOS 18 light / dark / tinted)
- Real published Privacy Policy and Terms URLs
- StoreKit Connect product setup
- ASO assets — screenshots, subtitle, keywords, description

### Post-launch
- Biometric lock (Face ID / Touch ID) on app open
- iCloud sync via SwiftData + CloudKit
- Recurring transactions and per-category budgets
- Receipt OCR with Vision framework
- Lock Screen and Home Screen widgets

---

## License

MIT
