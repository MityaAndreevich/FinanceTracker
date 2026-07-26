# Device bisection — 1.0.3 first-QuickAdd crash (#22, round 4)

Status: **NOT REPRODUCED in the simulator. No fix committed.** The device is the
arbiter. This is the protocol; it takes about five minutes and ends with an
attribution, not another hypothesis.

Build: `593db05` (harness) + `17c91df` (input probe). Debug, on the physical
phone, on the **7-row store that crashes** — do not reset it, that store is the
only known deterministic repro we have.

## Before you start — open the log stream

In Terminal, with the phone connected:

```bash
log stream --device \
  --predicate 'subsystem == "com.dmitrylogachev.budgetcrab" AND category == "ChartInput"'
```

Every chart now prints one line per render:

```
[chart-input] dashboardDonut n=4 total=250800 min=300 max=200000 spread=199700 minShare=0.0012
```

**The last line before the debugger stops is the answer to "with what".** Copy
the whole tail of that stream into the report whatever the outcome.

## The protocol

Settings → Debug.

**Step 0 — prove the build still crashes.** Domain guard OFF, all charts ON.
QuickAdd once. It **must** crash. If it does not, stop: this build proves
nothing and every step below is meaningless.

**Step 1 — domain guard ON, all charts ON.** QuickAdd once.
- No crash → the degenerate continuous domain was the cause. Done.
- Crash → continue.

**Step 2 — hide ALL charts.** QuickAdd once.
- No crash → it **is** a chart. Go to step 3.
- Crash → it is **not** a chart, and the Charts reading of the stack has been
  wrong in all four rounds. Report that; it is the single most valuable outcome
  on this page.

**Step 3 — re-enable one chart at a time**, QuickAdd after each, in this order:
`dashboardDonut` → `pulse` → `horizon` → `breakdownDonut` → `daySpending`.
The first one that brings the crash back is the answer.

Note on order: the Dashboard donut is first because it is the only chart on the
visible screen. But **do not stop at "it wasn't the donut"** — a TabView retains
tabs once visited, so Pulse / Horizon / the Breakdown donut are still mounted
and re-render on the same save if Analytics was opened earlier in the session.
That is a live possibility, and it is why steps 3c–3e matter even though the
Dashboard is what is on screen.

## What to report

1. Step 0 result (crashed / did not crash) — without this nothing else counts.
2. The step at which the crash disappeared.
3. The chart that brought it back.
4. **The last 20 lines of the `ChartInput` log stream before the trap.**
5. Whether Analytics had been opened at any point in that session.

## What has already been ruled out — do not re-derive

Simulator-clean, on iOS 18.6 **and** 26.5, 22 render cases
(`FinanceTrackerTests/DonutSectorInsetTests`), each hosting the real views and
forcing the real layout pass across the 7→8 row delta:

- donut slices from 10% down to 0.01% of the total, and $3-coffee-against-rent
- the 7→8 delta with: a new category, a new day, a split whose share is
  negligible, the seventh-category "Other" fold, all-equal amounts, a Cyrillic
  merchant and a Cyrillic custom category
- budget set, unset, and explicitly 0
- Analytics visited and retained, then the save done from the Dashboard
- every chart in the app live at once, all re-rendering on one save

Ruled out by construction, not by test:

- **H2 (budget division) is dead.** There is no Velocity donut and no
  pace/forecast Chart — the budget ring is plain SwiftUI `Circle().trim`, and
  `DailyAllowance.compute` returns `nil` when the budget is ≤ 0, so no fraction
  derived from a budget ever reaches Swift Charts.
- The Dashboard's **only** Swift Charts view is `CategoryDonutView`.

One real defect surfaced but is **not** claimed as the cause: `angularInset: 1.5`
costs 0.0625 rad at the donut's 48pt inner radius, so any slice under ~1% of the
month is a negative-width sector. Ordinary data produces it (0.12% for a $3
coffee in a $2500 month) and Charts renders it clean anyway. If step 3 lands on
`dashboardDonut`, start there — it is the one degenerate input the donut still
carries. If step 3 lands elsewhere, ignore it.
