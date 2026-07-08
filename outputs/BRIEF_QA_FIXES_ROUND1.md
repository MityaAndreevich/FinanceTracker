# BRIEF (Claude Code) — Device-QA fixes, round 1 (pre-submit). Model: Sonnet; use systematic-debugging for #1 & #2.

Device QA (real iPhone, RU+EN) found these. All are pre-submit quality fixes (hurt first impression / rating). Build green, commit per item, push, before/after screenshots (dark + one light where relevant). Do NOT touch save/parser mechanics. Localize any new/changed strings in all 5 locales; bump parity.

## 1. Long BLACK screen on first launch (before the mascot) — systematic-debugging
On first launch there's a long black gap, then the crab appears. Investigate cold-start:
- Ensure a proper **branded LaunchScreen** (not black) so there's never a blank gap.
- Move SwiftData container setup / any first-run seeding / heavy reads OFF the main thread or defer them; the greeting must not block on I/O. (We saw main-thread Core Data I/O warnings earlier — relevant.)
- Measure cold-start before/after; target: branded launch → content with no long black gap. Report the numbers.

## 2. Language switch (EN↔RU) doesn't fully re-localize until app restart — systematic-debugging
After switching language in-app, some chrome stays English until relaunch (screenshot: Settings title "Настройки" but rows General/Premium/Data/… still English). Fix so a language change **re-localizes the whole UI immediately** (refresh the LocalizedBundle / environment / view identity so all screens re-render). No "restart to apply." Verify Settings rows + Dashboard + tab bar all switch live.

## 3. QuickEntry ("+"): coach-mark pointer wrong + layout pushed
- The inline hint "Need a category, account or date? Open the full form here" **points UP (finger) but its target button "Use detailed form" is BELOW it** → fix pointer direction/placement to point at the actual target.
- When the hint is present it **pushes the layout** so the title "Type or say an amount" gets clipped/overlapped by the chip row; dismissing the hint fixes alignment. Make the layout correct **with the hint present** (reserve space / don't overlap the title).

## 4. QuickEntry title clipped on keyboard focus
"Type or say an amount" gets overlapped/half-clipped by the chip row once the field is focused (screenshots). Keep the title fully visible OR hide it cleanly — no half-clipped text.

## 5. InlineHintBubble polish
Hint text looks cramped/crooked (uneven padding/line-height) on the open-form hint AND the period-pager hint. Clean up padding, line-height, alignment so hints read tidily on all screens.

## 6. Expense amount color (Dashboard + Transactions)
Expense amounts render plain **white** while income is green (screenshot: "−$50.00" white). Apply our directional color: **expense = coral** (Color.moneyDirectional / bc coral-danger), income = green. Keep it calm coral, NOT aggressive red (per our directional-color decision). Apply on Dashboard recent rows + Transactions list.

## 7. Dashboard "recent" list says a period but shows only 5
The recent-transactions section implies the week but caps at 5. Make it honest: relabel the section to **"Recent"** with a **"See all ›" → Transactions** link (preferred, minimal), OR show all of the stated period. Don't leave a label that contradicts the count.

## 8. "Safe to spend" ring/number reads as INCOME (it's green) — Dashboard
The big "Safe to spend" amount + its progress bar are rendered in the same **green** as income → users read it as income/gain (confusing on the first screen). Fix: **reserve pure directional green strictly for INCOME amounts.** For safe-to-spend, use a neutral treatment — amount in primary/adaptive text (white in dark), progress bar in the **mint brand accent** (distinct from income-green), so budget-remaining no longer signals "income." Keep it calm/premium.

## NON-goals this round → v1.0.1 (capture, do NOT build now)
- **"Custom" quick-category chip** — a chip in the QuickEntry row that opens a quick "create category (name + icon)" flow. Nice, but a feature (new sheet + persistence + localization) → defer to protect the submit date.
- Extra coach-marks/hints for **Analytics + Settings** — optional; only add if trivial, else v1.0.1.

## Report
Per item: files, build status, commit. For #1 the cold-start numbers; for #2 confirm live re-localization verified on the Settings + Dashboard.
