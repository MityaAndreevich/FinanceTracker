# DEFECT: CSV import accepts amounts the UI refuses, and the parser fails three ways

**Status:** open, release hold. Not fixed, nothing touched.
**Found:** 2026-08-26, while establishing whether PDF export's font-shrink branch was reachable.
**Scope:** this is a DATA-LAYER inconsistency, not an export bug. `amountCents` reaches totals,
charts, budgets and every aggregate. PDF export is merely where it became visible.

---

## 1. The asymmetry

Manual entry is capped, in two places:

```swift
// AddTransactionView.swift:502   and   EditTransactionView.swift:506 (identical)
guard amountCents > 0 && amountCents <= 10_000_000_000_000 else { … }
```

10^13 cents = 100 000 000 000.00. Import is not capped at all:

```swift
// CSVImportService.swift:710
guard let amountCents = Money.parseCents(from: amountStr) else { … }
```

`Money.parseCents` (`Money.swift:63`) validates the CHARACTER SET only — digits, `,`, `.` — and
delegates to `AmountParsing.parseCents`. There is no magnitude check anywhere on the import path.
**An import can therefore insert a value the UI would refuse to accept, and would refuse to let the
user edit afterwards** — the edit sheet's guard rejects it on save.

## 2. What `AmountParsing.parseCents` actually accepts

`AmountParsing.swift:63-73`:

```swift
let intValue = Int(intDigits) ?? 0
var fracValue = Int((fracDigits + "00").prefix(2)) ?? 0
…
return intValue * 100 + fracValue
```

Three regimes, and two of them are defects in their own right:

| integer digits | `Int(intDigits)` | result |
|---|---|---|
| ≤ 16 | succeeds | correct |
| 17–19, above the ×100 boundary | succeeds | **`intValue * 100` TRAPS — process crash** |
| ≥ 20 | fails → `?? 0` | **silently becomes 0**, keeping only the cents |

The third is the ugly one. `"99999999999999999999999.99"` does not fail the import and does not
crash: it imports as **99 cents**. A row that a user believes they imported is now off by
twenty-three orders of magnitude, with no error, no warning, and no flag on the row.

The second is a crash on a malformed-but-plausible file. `Int(...)` succeeding says nothing about
`× 100` fitting; Swift's `*` traps on overflow by design.

The exact ceiling that survives: `intValue * 100 + fracValue <= Int.max`, i.e.
`92 233 720 368 547 758.07`. That is the largest reachable `amountCents` — reachable only by
hitting the boundary precisely; one cent more and the app traps.

## 3. Which aggregates consume `amountCents` without their own bound

All of these sum `amountCents` in **`Int`**, so they trap on overflow rather than saturating:

| site | expression |
|---|---|
| `MonthTotals.swift:20` | `transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amountCents }` |
| `MonthTotals.swift:25` | same, income |
| `CategoryLimitPolicy.swift:83` | `spent[categoryUUID, default: 0] += row.amountCents` |
| `SafeToSpend.swift:100,104` | `priorExpense += entry.amountCents`, `spentThisMonth += …` |
| `AnalyticsSeries.swift:51,53` | `earned += tx.amountCents`, `spent += tx.amountCents` |
| `AnalyticsSeries.swift:92,94` | monthly income/expense accumulators |

**So yes — they overflow before the PDF ever sees it.** Two imported rows near the ceiling are
enough for `MonthTotals` to trap, and `MonthTotals` feeds the dashboard, which is the first screen
after launch. The failure would present as "the app crashes on open", with the cause sitting in a
CSV the user imported days earlier.

By contrast `PDFExportService.computeSummary` accumulates into `Decimal`:

```swift
let amount = Decimal(tx.amountCents) / 100
if tx.isIncome { income += amount } else { expense += amount }
```

which is why export survives values that crash the dashboard. Export is the safe consumer here; it
is not the defect.

## 4. What is NOT claimed

- Not claimed that any user has hit this. It requires a hand-made or malformed CSV; there is no
  field evidence either way.
- Not claimed which fix is right. The obvious one — apply the UI's 10^13 cap on the import path —
  changes import behaviour for existing files and needs a decision about whether such a row is
  rejected, clamped, or flagged. `?? 0` must stop being a silent zero regardless of that decision.
- Not claimed the trap is reachable without the silent-zero path also being reachable; they are
  adjacent regimes of the same expression.

## 5. Relationship to the PDF work

The PDF export fix sizes the amount column from the content and shrinks the font before it will
truncate, so it renders these values correctly rather than silently clipping them — verified at
`9 000 000 000 000 000` cents, which shrinks the font to 11.5pt and renders with a 0-pixel
difference from an unconstrained render. That is the export doing the right thing with bad data.
It does not make the data good.
