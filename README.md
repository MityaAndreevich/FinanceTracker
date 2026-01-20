# FinanceTracker

FinanceTracker is a lightweight personal finance tracking app built with **SwiftUI** and **SwiftData**.
The app focuses on simplicity, clarity, and data ownership: all financial data is stored locally on the user’s device.

This project is designed as a production-ready MVP following iOS best practices.

---

## Features

### Core
- Add income and expense transactions
- Categorize transactions (expense / income categories)
- Optional income sources (salary, freelance, gig work, etc.)
- Monthly dashboard:
  - Total income
  - Total expenses
  - Net balance
- Transactions list:
  - Income highlighted in green
  - Expenses highlighted in red
  - Filter: This Month / All
  - Transaction details screen
  - Edit existing transactions

### Analytics
- Monthly expenses grouped by category
- Monthly income grouped by source
- Net income grouped by source

### Data Safety
- Prevent deletion of categories or sources that are already used by transactions
- All data stored locally using SwiftData

### CSV Import / Export
- Export transactions as CSV:
  - This month
  - All data
- Share CSV via the system Share Sheet
- Import CSV from Files
- Automatic creation of missing categories and sources during import
- Import summary with imported / skipped rows and errors

---

## Tech Stack

- SwiftUI
- SwiftData
- iOS 17+
- Swift Charts (planned)
- StoreKit 2 (planned)

---

## CSV Format

Exported CSV columns:
### Column details
- `date`: ISO format (`YYYY-MM-DD`)
- `type`: `income` or `expense`
- `amount`: decimal number (e.g. `12.34`)
- `currency`: ISO currency code (e.g. `USD`)
- `category`: category name (required)
- `source`: income source (optional)
- `tax`: decimal number (optional)
- `note`: free text (optional)
- `merchant`: free text (optional)

---

## Data & Privacy

- FinanceTracker does **not** collect or transmit any personal data
- No analytics SDKs, no tracking, no ads
- All data is stored locally on the device
- CSV import/export is handled entirely on-device

---

## Getting Started

1. Clone the repository
2. Open `FinanceTracker.xcodeproj` in Xcode
3. Select an iOS Simulator or a real device
4. Build and run the app

---

## Project Goals

- Simple and intuitive personal finance tracking
- Clean UX following iOS Human Interface Guidelines
- Full user control over financial data
- Reliable import/export without vendor lock-in

---

## Roadmap

### Short-term
- UI polish for production release
- Localization (multiple languages)
- Currency formatting and default currency settings
- Unit tests for CSV import/export
- App Store release

### Post-release
- Charts and visual analytics
- Receipt scanning (OCR, on-device)
- Recurring transactions
- Face ID / app lock
- iCloud sync
- Premium features and subscriptions

---

## License

MIT