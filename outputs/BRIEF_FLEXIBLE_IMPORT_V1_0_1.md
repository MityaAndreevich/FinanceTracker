# BRIEF (Claude Code) — v1.0.1 Flexible CSV import (Tier 2: column-mapping + source presets). Model: Sonnet + TDD (parser is data-correctness — write the table first). Skills: apple-hig-expert / swiftui-design-skill (mapping sheet UX), + systematic TDD for the parser.

**v1.0.1 cycle (1.0 in App Review — don't touch the submitted build).** `main`, commit per unit, push, `xcodebuild … build` before commit. Localize all new strings in ALL 5 locales. No hardcoded English. Don't reintroduce CLAUDE.md anti-patterns. **This is data-correctness on user's financial data — a wrong mapping silently corrupts amounts/signs, worse than a crash. TDD, guard everything, never drop rows silently.**

## Why (source: outputs/MIGRATION_IMPORT_ROADMAP.md — don't re-derive)
Tier 1 (generic CSV round-trip + UUID dedup) already shipped. Tier 2 is the migration unlock that rides the post-Mint vacuum ("Mint refugees"; Monarch won purely on Mint-CSV import). The scariest part — **duplicate reconciliation — is already solved** (UUID dedup + flag-not-drop for foreign rows); reuse it, don't rebuild. **Honesty gate: we only add "switch from Mint" marketing claims/keywords AFTER this ships and is verified.**

## Step 0 — grep the current import path first (don't assume line numbers)
Find and reuse: `CSVImportService` / `CSVImportActor`, the existing RFC-4180-aware reader (already quote-aware), the dedup logic (UUID exact + day-granular flag for no-UUID foreign rows), `Shared/Money.swift`, `tx.isIncome`, `@AppStorage("defaultCurrencyCode")`, the "Без категории"/uncategorized fallback. Extend this path — do NOT fork a parallel importer.

## Scope = Tier 2 only. Build these.

### 1. Header detection + preview
On file pick, parse header row + first ~10 data rows. Show a **preview table** so the user maps against real values, not blind column names.

### 2. Source-preset auto-detect (one-tap mappings)
Detect the source by header signature; preselect a preset the user can override:
- **Mint CSV** (priority): `Date, Description, Original Description, Amount, Transaction Type, Category, Account Name, Labels, Notes`. Note: Mint puts sign in the **`Transaction Type`** column (debit/credit), amount is unsigned.
- **YNAB**, **Monarch**, **generic bank CSV**. (Columns per the roadmap table.)
- **"Custom"** = fully manual mapping (fallback for anything unrecognized).

### 3. Column-mapping UI
Let the user map their file's columns → our fields: **date, amount, type/sign, category, merchant/description, note, account**. Preset fills defaults; user can reassign any. Required fields = date + amount (+ a sign source). Unmapped optional fields are fine.

### 4. The #1 bank-CSV gotcha — two-column debit/credit
Explicitly support amount as **two separate columns** (e.g. `Debit` + `Credit`) as well as a single **signed** column, and Mint-style **unsigned amount + a type column**. Combine into one signed amount and derive `isIncome`:
- Two-column: credit>0 → income; debit>0 → expense.
- Signed single: sign → type.
- Unsigned + type column (Mint): map credit/deposit/income → income; debit/payment/withdrawal → expense.
This is where naive importers fail — cover all three in tests.

### 5. Locale-tolerant value parsing (foreign files vary — our own export is en_US_POSIX, others are not)
- **Amount:** accept comma-decimal AND period-decimal source files, with space/NBSP/`.`/`,` grouping — reuse the tokenizer discipline from the QuickAdd amount fix (en_US_POSIX target, strip only true grouping seps, keep one decimal). A Mint `1,234.56` and a EU `1.234,56` must both parse correctly.
- **Date:** support the common formats (ISO `YYYY-MM-DD`, US `MM/DD/YYYY`, EU `DD/MM/YYYY`, `DD.MM.YYYY`). Ambiguous (e.g. `03/04/2026`) → let the **preset** declare the order, and/or infer from values >12; surface the detected format in the preview so the user can correct before import. Never silently guess wrong.
- **Currency:** foreign files usually omit it → assume `@AppStorage("defaultCurrencyCode")` and **flag** the assumption in the result summary.

### 6. Category — minimize the re-categorization tax (friction #1 in reviews)
Map category names where a preset provides them; otherwise import as **uncategorized** ("Без категории") for the user to fix later. Do NOT force re-tagging and do NOT block import on unmapped categories.

### 7. Dedup + safety
- Reuse existing dedup (UUID exact; day-granular possible-dup **flag, not drop** for foreign rows). Re-importing the same file or overlapping ranges must not duplicate.
- **Import result summary:** imported N, flagged as possible-dup M, skipped/failed K with reasons, currency-assumed count. Never drop a row silently — a row that can't be parsed is reported, not discarded.
- Import stays on the existing background actor; ModelContext only via the actor (no main-thread writes).

## Explicitly OUT of scope (Tier 3 — do NOT build now)
PDF/statement OCR, OFX/QFX/QIF, screenshots, SQLite, MT940/CAMT.053, live bank sync. No marketing-claim changes in-app — claims follow a separate metadata step after this is verified.

## Tests (TDD, targeted — no suite-wide runs)
Parser table asserting `mappedTransaction == expected` for:
- Mint preset: unsigned amount + `Transaction Type` debit/credit → correct sign + `isIncome`; `1,234.56` → 123456¢; category mapped or uncategorized.
- Two-column bank CSV: `Debit`/`Credit` → single signed amount + correct type; both-empty / both-filled edge rows reported not crashed.
- Signed single-column bank CSV → sign→type.
- EU comma-decimal source `1.234,56` → 123456¢; date `DD.MM.YYYY` parsed; ambiguous date respects preset order.
- Dedup: re-import same file → 0 new; overlapping file → only new rows added, dups flagged.
- Uncategorized fallback; missing currency → assumed defaultCurrencyCode + flagged.
- Malformed row → in the failed/reported bucket, not silently dropped.
- 5-locale string parity for new UI keys.

## Report (≤6 lines/unit): the mapping model + presets added, how the three amount/sign shapes are handled, date/amount locale handling, the result-summary UX, files changed, build status, commit hashes. Device-verify: import a real Mint-style CSV + a two-column bank CSV; confirm signs/amounts/dates correct, dedup on re-import, uncategorized rows land in "Без категории", summary shows flags. **Do NOT touch marketing copy** — I'll handle the "switch from Mint" claim + keywords separately once you confirm it's verified.
