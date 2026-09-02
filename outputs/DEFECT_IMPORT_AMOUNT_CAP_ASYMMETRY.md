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

---

## 6. END-TO-END: the chain completes, and it bricks the app

Measured 2026-08-27 by `FinanceTrackerTests/ImportOverflowChainTests.swift`. Reasoning is not
what establishes any of this; each line below is an observation.

**The file.** Not a hostile one. The app ships flexible column mapping with Mint/YNAB/Monarch
presets, so the user chooses which column is the amount, and bank exports routinely carry 16–18
digit reference or account numbers. Mapping "Reference" onto "Amount" is an ordinary mistake with
an ordinary file, and it yields a 17-digit integer — the widest that stores rather than trapping
inside the parser.

| # | question | measured answer |
|---|---|---|
| 1 | plausible file shape | two rows, amount `92233720368547758` (mis-mapped reference column) |
| 2 | does the real import path store it | **yes** — `imported=2 skipped=0`, each row stored as `amountCents = 9223372036854775800`, six orders of magnitude above the UI's 10^13 cap. No error, no warning, no flag |
| 3 | does the dashboard's own sum overflow | **yes** — overflow at row index 1; running total `9223372036854775800` + the second row exceeds `Int.max`. The real call crashes: `Crash: FinanceTracker at …testProbe_realMonthTotalsTraps()`, last output `PROBE: about to call MonthTotals.expenseCents on 2 rows` |
| 4 | does it survive a relaunch | **yes** — after closing the container and reopening the same store file: `rows still present: 2`, `sum still overflows: true` |
| 5 | any in-app route to delete the row | **no.** `ContentView.swift:28` declares `@State private var selectedTab: Int = 0` — not persisted, so every launch starts on tab 0, `DashboardView`. `expenseCents` is a computed property evaluated in the dashboard's body (`DashboardView.swift:129-130`), so the trap fires during the first render of the first screen. No other tab is ever reached |
| 6 | what does a 22-digit amount store | **zero.** `imported=1 skipped=0`, `stored amountCents: 0`, no error. A row the user believes they imported is a zero in their ledger |

### The one qualifier, and it matters

The dashboard sums `currentMonthTransactions`. The lock-out therefore lasts **as long as the
offending rows are in the current month** — at month roll-over the dashboard recovers on its own.
That makes it "unlaunchable for the rest of the month" rather than "unlaunchable forever", which
is not much comfort: it is still an app the user cannot open, for weeks, with no message and no
way to act on it. And `AnalyticsSeries.swift:92,94` accumulates across ALL months in `Int`, so the
Analytics screen keeps trapping after the dashboard recovers.

### Silent corruption, in those words

A ≥20-digit amount is not rejected and does not crash. `Int(intDigits) ?? 0` at
`AmountParsing.swift:63` **silently yields zero**, and the row is imported as a zero-value
transaction. The user is told the import succeeded. Their ledger is wrong and nothing in the app
will ever tell them.

---

## 7. FIXED IN BUILD 10 — and what the enumeration cost

### Prevention (new rows)

`AmountParsing.parseCents` returns nil for both failure modes instead of `?? 0`
(silent zero) and a trapping `* 100`. `AmountParsing.maxAmountCents` is now the single
ceiling, referenced by `AddTransactionView`, `EditTransactionView` and BOTH import paths —
import could previously write a row the editor then refused to save. Rejection rides the
1.0.5 partial-import disclosure; the reason is localised in all five languages.

### Recovery (rows already in a user's store)

The rule is the same at both ends: **a value that cannot be represented is reported, never
clamped, zeroed, wrapped or saturated.** Ten expressions across eight files now report
instead of trapping — the dashboard's totals and category buckets, the alert path
(`SafeToSpend`, `CategoryLimitPolicy`, `LedgerAggregator`), the widget snapshot builder,
and the transactions list's day header. The alert path and the widget bail silently: an
alert or a widget figure we could not compute is not published. The dashboard gets an
explicit "this month's totals can't be shown" card that replaces the money area and sends
the user to Transactions.

### THE ENUMERATION WAS WRONG FOUR TIMES, IN FOUR DIFFERENT WAYS

This is the part worth carrying forward, because it was not a lapse — it was four
independent methods each failing once, on the same question, in one day:

| # | method | what it missed |
|---|---|---|
| 1 | grep `\.draw(in: CGRect` | multi-line `.draw(` calls — reported 10 sites, there were 13 |
| 2 | grep `(\+=\|reduce\(0)` | `running + share.amountCents` in `DashboardView` — a site ON the launch screen |
| 3 | inspection | predicted `SafeToSpend` on the dashboard; it is not there (`remainingCents` is pure subtraction) |
| 4 | mis-classification | `NetSnapshotBuilder` catalogued as "widget", assumed off the launch path — `DashboardView.refreshWidgetSnapshot()` calls it during the first render |

Errors 3 and 4 were made by two people independently. A fifth attempt at enumeration was
not going to be the right one.

**So the closing evidence is not a list.** `PoisonedAmountsDebugSeed` (`--poison-amounts`)
seeds the store an affected user actually has, and `PoisonedAmountLaunchTests` walks the
whole journey the recovery exists for:

> cold launch → the dashboard renders its unavailable state → Transactions → the list
> renders → **delete the offending row** → the dashboard shows real totals again

It found error 4 immediately, and then found `ScopedTransactionList.dayHeader` on the way
to the list — a site nobody had listed, on the destination rather than the launch path.
The final assertion is positive (the hero label is back), not merely the absence of the
unavailable card: an absence can pass vacuously, which is the same proxy mistake in
miniature.


### The most instructive failure of the day: the fix collapsed the two cases the rule exists to separate

`AmountParsing.parseCents` ended in `Int(intDigits) ?? 0`. That `?? 0` was doing TWO jobs:

| input | `Int(intDigits)` | what it means | what it deserves |
|---|---|---|---|
| `".15"` | nil — the integer part is EMPTY | a legitimate leading-decimal amount | 0, and carry on |
| 22 digits | nil — the integer part CANNOT be represented | a value we cannot read | reject the row |

The fix removed the `?? 0` for the second case and took the first with it, so `.15` and `,15`
— every leading-decimal amount a user can type — stopped parsing. **Two distinct cases were
collapsed into one while implementing the rule against collapsing two distinct cases into one.**

Nothing in review caught it. `AmountParsingTests.testLeadingDecimal` did, in the full run, after
the change had already passed every suite it was tested against in isolation. The lesson is not
"be more careful": it is that a guard which returns the same value for two different reasons will
be read as guarding one of them, and the other will be lost silently the first time someone
tightens it.

### Still filed: 14 expressions, same rule

`AnalyticsSeries` (6), `CategoryDetailView` (2), `DaySpendingSheet` (2), `AnalyticsView` (1),
`AnalyticsBreakdownView` (1), `EditTransactionView` (1), `CSVImportService` (1).

None is on the journey from cold launch to deleting the row, which is why they are not in
build 10. **Whoever fixes them applies the same rule** — `addingReportingOverflow` and an
explicit unavailable state, never a wrapped, saturated, zeroed or widened number. Widening
is not a fix: `Int128` overflows too, it only moves the cliff, and it drags type changes
through public signatures for no invariant.

## 8. What is NOT claimed

- Not claimed that any user has hit this. It requires a hand-made or malformed CSV; there is no
  field evidence either way.
- Not claimed which fix is right. The obvious one — apply the UI's 10^13 cap on the import path —
  changes import behaviour for existing files and needs a decision about whether such a row is
  rejected, clamped, or flagged. `?? 0` must stop being a silent zero regardless of that decision.
- Not claimed the trap is reachable without the silent-zero path also being reachable; they are
  adjacent regimes of the same expression.

## 9. Relationship to the PDF work

The PDF export fix sizes the amount column from the content and shrinks the font before it will
truncate, so it renders these values correctly rather than silently clipping them — verified at
`9 000 000 000 000 000` cents, which shrinks the font to 11.5pt and renders with a 0-pixel
difference from an unconstrained render. That is the export doing the right thing with bad data.
It does not make the data good.
