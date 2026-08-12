# BRIEF (Claude Code) — LAUNCH BLOCKER: Charts crash when adding the SECOND transaction. Model: Sonnet + systematic-debugging. This is a device-confirmed crash — fix with evidence, don't guess.

## Confirmed evidence (device, local 1.0.2) — do NOT re-derive
Adding the 2nd transaction crashes. `bt` = EXC_BREAKPOINT (`brk #0x1`) with frames #0–#9 all inside **`Charts`**, during a SwiftUI render/layout pass (`CanvasDisplayList.updateValue` → `ViewGraphRootValueUpdater.render(...)` → `_UIHostingView.layoutSubviews`). Crash fires right after `QuickAddSave #2`. Same class as the prior Charts NaN crash we fixed with `Shared/ChartGuards.swift` (memory: swift_charts_nan_crash) — but a chart path that wasn't guarded, tripping at exactly 2 data points. Log noise (`CFPrefs`, "variant selector cell index", `RTIInputSystemClient`) is cosmetic — ignore.

## Step 0 — identify the exact chart + the degenerate input (report first)
- Determine WHICH chart view is on screen and re-rendering when the 2nd transaction lands (Dashboard? Analytics preview? Pace/trend? the safe-to-spend area?). The app frame is `FinanceTrackerApp`; find the Chart whose data changes on the 2nd insert.
- Find the **specific degenerate value at count == 2**: a zero-width domain (min == max), a NaN/inf from a division, a `catmullRom`/interpolation on 2 (or 2 identical) points, or an axis/scale domain with equal bounds. Report the concrete cause before changing code.
- **Is this a 1.0.2 regression or also in live 1.0.1?** Check git: did this chart's data/config change since the 1.0.1 tag (e.g. the SafeToSpend extraction or the alerts `didSave` refresh altered its input)? If the offending chart shipped in 1.0.1, **live users can crash on their 2nd transaction → this also needs a 1.0.1 hotfix.** State clearly which.

## Fix — guard this chart AND audit ALL charts (stop the whack-a-mole)
- Fix the offending chart via the existing `ChartGuards` discipline: sanitize every value (`isFinite`, clamp ≥ 0 where required), ensure the domain has `min < max` (or fall back to a safe range / empty state), and never feed `catmullRom`/spline interpolation a point count below its safe minimum (guard or drop to `.linear` / empty state on sparse data).
- **Then audit EVERY `Chart {}` in the app** for the same class of bug — degenerate at 0/1/2 points, equal domain bounds, div-by-zero. We've now been bitten twice; make the guard systematic (a shared sanitizer applied to all chart inputs), not one more point fix.

## Tests
- A regression that inserts 1, then 2, then 3 transactions and renders each affected chart without crashing (drive the real data path).
- ChartGuards unit tests for: 2 points, 2 identical points, equal domain bounds, zero total, NaN/inf input → safe output / empty state, never non-finite to Charts.

## Report (≤6 lines): the exact chart + degenerate value (Step 0), whether 1.0.1 is affected (→ hotfix?), the guard applied + the all-charts audit result, files, build/test, commit. Device-verify: add 2 / 3 / 1 transactions in a fresh month and on the 1st of a month — no crash.
