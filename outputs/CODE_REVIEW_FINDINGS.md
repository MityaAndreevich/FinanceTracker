# Budget Crab (FinanceTracker) — Pre-Submission Code Audit

**Mode:** read-only audit. No code was modified. **Date:** 2026-07-06.
**Scope:** crash safety, memory/lifecycle, concurrency/SwiftData, security/privacy, documented anti-patterns, dead code, localization, performance.

## Summary

| Severity | Count | One-line verdict |
|---|---|---|
| **P0 (fix before submit)** | **1 (FIXED)** | Lock-screen/background AppIntent crash + transaction loss — fixed in commit below. |
| **P1 (post-launch / verify)** | 4 | One is a submission blocker to *verify* (product IDs); rest are hardening. |
| **P2 (backlog)** | 4 | Style / convention deviations. |

**Headline:** The codebase is unusually clean and well-guarded — every force-unwrap is provably safe, every Swift Charts input routes through the `ChartGuards` choke-point, all untrusted-input indexing (CSV import, Quick Add / voice parser) is bounds-guarded, all `ModelContext` access is on `@MainActor` or the `CSVImportActor` `@ModelActor`, and nothing is transmitted off-device. The first audit pass found **0 P0**; the **independent verification pass overturned that** and found **one P0** — a reachable background-process crash + data loss that the first pass had under-rated by splitting it across two separate P1 hardening notes. It is now **fixed** (see below). The most important remaining pre-submit action is a *configuration* verification (P1-1, product IDs).

---

## Findings (sorted by severity)

### P0 — FIXED

**[P0] · crash + data-loss · `Data/SharedModelContainer.swift:105` (composed with `AddTransactionIntent.swift:80`, `CategoryEntity.swift:41`, `BudgetCrabShortcuts.swift:29`) · headless AppIntent crashes on a locked device and loses the user's transaction**

- **What:** `AddTransactionIntent` runs **headless in a background process** (no `openAppWhenRun`) and is auto-surfaced via `BudgetCrabShortcuts: AppShortcutsProvider` to Siri / Spotlight / Action Button / Shortcuts automations. Its first touch of `SharedModelContainer.shared` (`AddTransactionIntent.swift:80`, also `CategoryEntity`/`TransactionEntity`) lazily opens the SwiftData store. That store was stamped `URLFileProtection.complete` (`:105`), which seals the file ~10s after the device locks. Opening a sealed store while locked **throws**, and the container init falls into `fatalError(...)` (`:45`) → the intent process hard-crashes and the transaction the user tried to add via automation is **lost**.
- **Why it matters:** Reachable at runtime without Siri auth assumptions — a Shortcuts "Run Immediately" automation, an Action Button press, or a time-of-day automation firing while the phone is locked hits it. It is a crash + silent data loss on a headless path a reviewer/user can trigger. (The Home-Screen widget is unaffected: it reads the App-Group `NetSnapshot` Codable snapshot, never the SwiftData store.)
- **Why the first pass missed it:** it filed the `.complete` protection and the `fatalError` as two independent P1 hardening notes and never composed them with the background/locked execution path.
- **Fix applied:** `Data/SharedModelContainer.swift:105` — `URLFileProtection.complete` → `.completeUntilFirstUserAuthentication`. The store stays encrypted at rest but is readable by background code after the first post-boot unlock, which covers all realistic automation/Action-Button use; this closes the reachable crash window. Effort: S. **Build green.**
- **Residual (tracked as P1-2 below):** the `fatalError` on a genuine store-open failure (true corruption / incompatible migration) is still a crash-loop path. It is no longer the *reachable* trigger once file protection is relaxed, so it is left as a P1 hardening item rather than expanded into a throwing-accessor refactor days before submit (that refactor touches the SwiftUI scene wiring and is higher-risk than the submit warrants).

### P1

**[P1] · monetization/config · `Purchases/PurchaseManager.swift:24-26` · StoreKit product IDs disagree with the documented source of truth · why: code loads `bc_premium_monthly` / `bc_premium_annual` / `bc_premium_lifetime`, but `ARCHITECTURE.md:166` and MEMORY both say App Store Connect is configured with `ft_premium_monthly` / `_yearly` / `_lifetime`. If ASC actually holds `ft_*`, `Product.products(for:)` returns empty → paywall renders no plans → **zero purchases possible and premium features (import / all-time export) permanently locked**. · fix: reconcile — confirm the exact product identifiers in App Store Connect and make code + ASC match verbatim. (`PurchaseEntitlementTests` already assert on `bc_*`, so code+tests are internally consistent; the docs may simply be stale — but this must be verified against live ASC before submit.) · effort: S (verify) / M (if IDs must change)**

**[P1-2 · crash-resilience/data-loss] · `Data/SharedModelContainer.swift:30,45` · two `fatalError` on container init (missing App Group entitlement / `ModelContainer` init failure) · why: a corrupt or migration-incompatible on-disk store turns every launch into a crash loop with no recovery path or user messaging — effectively total data loss from the user's perspective. Reachable at runtime (disk corruption, failed schema migration), not just at build config time. NOTE: the *lock-screen* reachability of this `fatalError` was the P0 above and is now closed by the file-protection fix; what remains here is resilience against genuine store corruption. This is the standard Apple template pattern, so it's a judgment call, but for a shipping finance app a recover/rebuild path is worth it. · fix: catch the init error, attempt a one-time store rebuild (or surface a "reset data" recovery screen) instead of `fatalError`. · effort: M**

**[P1] · privacy/hygiene · ~15 sites (e.g. `Views/DashboardView.swift:437,470`, `Views/AddTransactionView.swift:502`, `Views/TransactionsView.swift:352`, `Data/SeedService.swift:29,92,214`, `Data/DemoSeeder.swift`) · bare `print(...)` not wrapped in `#if DEBUG` · why: `print` is NOT stripped from Release builds; these execute on device and write to the unified log. **None of them log transaction amounts, merchant text, or PII** (they log `error.localizedDescription` and record counts only), so this is not a privacy-label violation — but it is release console noise and a minor perf cost, and it's an easy foot-gun for future edits that might add PII to a log line. The `VoiceInputService` and `SharedModelContainer` prints are already correctly `#if DEBUG`-gated; these are not. · fix: gate behind `#if DEBUG` or route through the existing `PersistenceLog` seam. · effort: S**

**[P1] · localization · `AppIntents/*` (e.g. `AddTransactionIntent.swift:14,23,31`, `ShowSpendingIntent.swift:13`, `TransactionTypeAppEnum`, `PeriodAppEnum`) · Siri / Shortcuts user-facing phrases are English-only · why: intent titles, parameter dialogs ("How much?", "Which category?"), and enum display representations are hardcoded English `LocalizedStringResource` defaults with no `.strings` entries, while the app ships 5 fully-localized UI locales (en/ru/es/pt-BR/uk, 563 keys each — perfect parity confirmed). Siri surfaces the app in English regardless of app language. · fix: localize AppIntents strings, or accept as a known v1.0 limitation. · effort: M**

### P2

**[P2] · convention · `Views/DashboardView.swift:292` · `String(format: "%.2f", Double(template.amountCents) / 100)` to prefill an amount field instead of `Money.plainDecimalString(cents:)` · why: bypasses the shared money path (the exact anti-pattern class the repo warns about); `%.2f` is locale-invariant so it's not a corruption bug today, but it duplicates logic that `Shared/Money.swift` already owns. · fix: use `Money.plainDecimalString(cents: template.amountCents)`. · effort: S**

**[P2] · convention/duplication · `Views/Analytics/AnalyticsHorizonView.swift:427` (and `Services/CSVExportService.swift:38`) · locally-constructed `NumberFormatter` · why: Horizon builds a per-view formatter for axis abbreviation (K/M). It's not money-parsing so it's not the banned per-view `MoneyFormatter`, but it's un-shared. (CSVExport's local formatter at :38 is **correct and intentional** — en_US_POSIX locale-invariant, comment-documented — not a finding.) · fix: none required; optionally hoist axis abbreviation into a shared helper. · effort: S**

**[P2] · lifecycle · `Views/DashboardView.swift:256,58` · `widgetRefreshTask` / `undoExpiryTask` (`@State Task<Void,Never>`) not cancelled on `onDisappear` · why: both self-terminate after a `Task.sleep`, and each is cancelled before re-arming, so there is no leak or race — a stray fire only mutates `@State` or refreshes the widget, which is harmless. Noted for completeness. · fix: optional `.onDisappear { task?.cancel() }`. · effort: S**

**[P2] · convention · `Views/Settings/CategoriesSourcesView.swift:49,55`, `Views/Components/AddCategorySheet.swift:157` · category **kind** compared via raw string (`$0.kindRaw == "income"/"expense"`) · why: these are `Category.kindRaw`, not `Transaction.typeRaw`, so they are NOT the documented `tx.typeRaw == "income"` anti-pattern — but a typed `Category.isExpense`/`isIncome` helper (mirroring `Transaction.isIncome`) would be safer. · fix: add a typed accessor on `Category`. · effort: S**

---

## Verified-clean (checked and explicitly cleared — no finding)

- **Force-unwraps:** all are provably safe — `URL(string: <literal>)!`, `Calendar.current.date(from: <literal components>)!`, and `tx.merchant!` guarded by `tx.merchant?.isEmpty == false`. No `try!`, no `as!`.
- **Swift Charts:** every chart routes through `ChartGuards`. Pulse & Horizon gate on `canRenderContinuous(pointCount:)` before drawing interpolated line/area; Breakdown donut and `CategoryDonutView` gate on `renderableSlices` (drops non-positive, collapses zero-total to a placeholder). `DaySpendingSheet` bar chart is categorical-Y with positive Int-cents X. Money is `Int` cents (always finite). No chart input can be NaN/±inf or a degenerate domain.
- **Frame dimensions:** all computed `.frame(width: geo.size.width * fraction)` clamp `fraction` to `0...1`; donut sizes are constants; coach-mark rects add positive padding.
- **Integer division:** `remainingCents / daysLeftInMonth` — denominator is `max(1, …)`. No div-by-zero trap.
- **Untrusted-input indexing:** CSV import guards `!rows.isEmpty`, `cols.count >= 9` (and `>= 10` for the optional id column) before subscripting; Quick Add parser guards `!candidates.isEmpty` before `candidates[0]`; edit-distance loops are bounds-correct; `Money.sanitizeInput` `index(_,offsetBy:2)` runs only when `decimals.count > 2`.
- **Memory/lifecycle:** `PurchaseManager` is a `@MainActor` singleton; its `Transaction.updates` listener lives for the process lifetime (no leak). `VoiceInputService` uses `[weak self]` in the recognition callback and silence timer, `[request]` (not self) in the audio tap, removes its `NotificationCenter` observer and tears down audio in `deinit`. `@StateObject` used correctly for owned `VoiceInputService()`; singleton `PurchaseManager.shared` via `@StateObject` is harmless.
- **Concurrency / SwiftData:** all AppIntent `context.fetch`/save wrapped in `MainActor.run`; large CSV import runs on the dedicated `CSVImportActor` `@ModelActor` via `Task.detached`; `Transaction.category` delete rule is `.deny` with UI-level guard (the prior `.deny`-cascade crash was already fixed to the current guarded model per MEMORY).
- **Security / privacy:** no `URLSession`/network/off-device transmission anywhere (the only URLs are `openURL` targets for legal/support links). No hardcoded secrets/keys. `PrivacyInfo.xcprivacy` declares UserDefaults `CA92.1` — and grep confirms the app uses **no** file-timestamp / disk-space / boot-time required-reason APIs, so the manifest is complete and accurate (ARCHITECTURE.md's mention of `C617.1` is stale, but the manifest itself is correct). Store is excluded from backup and file-protected.
- **Localization:** en / ru / es / pt-BR / uk each have exactly 563 keys — full parity. Only hardcoded `Text` literal in views is `Text("Budget Crab")` (brand name, intentional).

---

## (a) P0 punch-list

1. **[FIXED]** `SharedModelContainer.swift:105` — headless/background `AddTransactionIntent` crashed + lost the transaction on a locked device because the `.complete`-sealed store threw at open and hit `fatalError`. Fixed: `.complete` → `.completeUntilFirstUserAuthentication`. Build green.

## (b) P1 / P2 backlog

**P1**
1. `PurchaseManager.swift:24-26` — VERIFY product IDs `bc_premium_*` match App Store Connect (docs say `ft_*`); empty product list = no purchases (submission blocker).
2. `SharedModelContainer.swift:30,45` — `fatalError` on store init = crash loop / data loss on genuine corruption; add recovery (lock-screen reachability now closed by the P0 fix).
3. ~15 sites — ungated `print()` in Release (no PII, but hygiene); gate behind `#if DEBUG`.
4. `AppIntents/*` — Siri/Shortcuts phrases English-only; localize or accept as v1.0 limitation.

**P2**
1. `DashboardView.swift:292` — use `Money.plainDecimalString` instead of `%.2f`.
2. `AnalyticsHorizonView.swift:427` — un-shared per-view `NumberFormatter` (axis abbreviation).
3. `DashboardView.swift:256,58` — optionally cancel `widgetRefreshTask` / `undoExpiryTask` on disappear (harmless today).
4. `CategoriesSourcesView.swift:49,55` / `AddCategorySheet.swift:157` — add a typed `Category.isIncome/isExpense` helper instead of raw `kindRaw` string compares.

---

## Uncertainties / could not fully verify

- **Product IDs (P1-1):** I cannot see App Store Connect. Code + `PurchaseEntitlementTests` are internally consistent on `bc_*`; ARCHITECTURE.md + MEMORY say `ft_*`. One is stale. This needs a human check against live ASC.
- **File-protection impact (P1-2):** whether lock-screen `AddTransactionIntent` actually fails depends on OS behavior for `.complete`-protected SwiftData under a locked device; I reasoned from the protection semantics rather than a device repro.
- **`fatalError` reachability (P1-3):** flagged as a resilience concern, not a confirmed-in-normal-use crash. It fires only on missing entitlement (config) or store corruption / incompatible migration.
- I did **not** run `xcodebuild` (per instructions) and did not execute the app, so all findings are static.
