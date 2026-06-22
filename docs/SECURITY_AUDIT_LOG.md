# Security Audit Log

## Audit: PII-Free Logging (T-19)

**Date:** 2026-06-22  
**Auditor:** Dmitry Logachev (assisted by Claude Sonnet 4.6)  
**Branch:** release/v1  
**Scope:** All `print()` / logging call-sites in `FinanceTracker/` Swift sources.

### Methodology

Searched every `.swift` file under `FinanceTracker/` for `print(` calls.  
For each call, assessed whether the interpolated value could contain PII:

- `error.localizedDescription` — safe; Apple frameworks strip model-object
  descriptions from human-readable messages.
- `\(error)` (bare) — **unsafe** for SwiftData errors: `NSError.description`
  can include the full `userInfo` dictionary, which may embed a SwiftData
  model object's `description`. A model object's `description` can expose
  field values such as `merchant`, `note`, or `amountCents`.

### Files Reviewed

| File | Call-site | Status before | Action |
|------|-----------|---------------|--------|
| `FinanceTrackerApp.swift:55` | `[Security] store protection applied` | `.localizedDescription` | OK — no change |
| `FinanceTrackerApp.swift:60` | `[Security] store protection error` | `.localizedDescription` | OK — no change |
| `Data/SeedService.swift:29` | `SeedService failed` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Data/SeedService.swift:87` | `Seed failed` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Data/SeedService.swift:125` | `Category migration failed` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Views/TransactionsView.swift:153` | `Failed to delete transaction` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Views/AddTransactionView.swift:291` | `Save failed` | `.localizedDescription` | OK — no change |
| `Views/AddTransactionView.swift:393` | `Failed to create category` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Views/AddTransactionView.swift:448` | `Failed to create source` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Views/Settings/CategoriesSourcesView.swift:232` | `Save failed` | bare `\(error)` | Fixed → `.localizedDescription` |
| `Views/Settings/GeneralSettingView.swift:173` | `Reset failed` | `.localizedDescription` | OK — no change |

### Changes Made

7 call-sites changed from `\(error)` to `\(error.localizedDescription)`.  
Commit: `chore(security): remove PII from log statements; document audit (T-19)`

### Notes

- No `os_log` or `Logger` usage exists in the codebase; all logging is via `print()`.
- `print()` output is visible only in the Xcode console during development.
  It does not reach device logs on a release build unless explicitly enabled.
  That said, bare `\(error)` on SwiftData errors was changed defensively.
- No analytics SDK or crash-reporting framework is integrated; no log data
  is transmitted off-device.

### Re-audit Trigger Conditions

Re-run this audit before any of the following:
- Adding a crash reporting SDK (e.g. Crashlytics, Sentry).
- Enabling `os_log` with a subsystem visible in Console.app.
- Adding any networking layer that logs request/response bodies.
