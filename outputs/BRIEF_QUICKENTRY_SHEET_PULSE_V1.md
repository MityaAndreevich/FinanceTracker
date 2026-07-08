# BRIEF (Claude Code) — QuickEntry "+" sheet jank + keyboard dismiss + Pulse income. Model: Sonnet + systematic-debugging.

Device QA (real iPhone, FRESH build with 15b61a1/89ea72c — confirmed: no Core-Data main-thread spam, no crash). Three real defects remain. Do NOT touch save/parser/CSV/entitlement/Charts-guard logic. Build green, commit per item, push. Device-verify (keyboard/sheet don't repro under simctl).

## Confirmed context (don't re-derive)
- Hang fix holds (debounce working) — no `performBlockAndWait`/`sqlite3` spam. Charts crash fixed — Pulse opened without EXC_BREAKPOINT.
- STILL spamming: `Invalid frame dimension (negative or non-finite)` — but it fires on the QuickEntry/keyboard flow, NOT in Analytics. So there is a **separate non-finite layout source in the QuickEntry input bar / "+" sheet** (the earlier "all guarded except Charts" conclusion was incomplete). Ignore keyboard-system noise (`_UIButtonBarButton`/`TUIKeyplane`/`TUIKeyboardContentView height==216`, rate-limit 32hz, share-sheet/LaunchServices, pasteboard, `_dictationButton`).

## Item 1 — QuickEntry "+" sheet: jerky rise + covers the amount hint + non-finite frame (ONE root)
The center "+" tab presents QuickEntry as a bottom sheet. On device: it **rises jerkily**, and the rising sheet/keyboard **covers the "Введите или скажите сумму" hint**. This co-occurs with the `Invalid frame dimension` spam → the sheet/content height is computed non-finite/*transiently wrong* during the keyboard-show animation.
- **Investigate** the QuickEntry sheet presentation + input-bar height math (detents, `GeometryReader`, any `.frame(height:)`/offset derived from keyboard height, safe-area, or the ZStack/cross-fade from the earlier voice-hint fix). Find the value that goes non-finite/negative and **guard it** (`isFinite`, `max(0,…)`), and stabilize the layout so:
  - the amount hint stays visible when the keyboard is up (don't let the sheet/keyboard occlude it — resize content or scroll, keep the input field + hint above the keyboard),
  - the sheet rise is smooth (use proper detents / a single stable height; avoid animating a height that's still being computed).
- **Verify on device:** the `Invalid frame dimension` spam is gone AND the "+" sheet rises smoothly with the hint visible.
- Product note for the report: the user questioned the sheet as the entry surface. Don't redesign now — make the current sheet behave correctly (smooth + hint visible). Log a v1.0.1 note if you think a different presentation is warranted.

## Item 2 — Keyboard won't dismiss on "Add category" (and no affordance)
On the add-custom-category screen (name field), after typing the keyboard **stays up with no way to dismiss it** (no Done/return dismissal, no tap-outside).
- Add standard dismissal: **return key** dismisses/commits, **tap outside the field** dismisses, a **Done** affordance if the layout needs one, and **auto-dismiss on Save/Cancel**. Same treatment for the add-account field if it has the same issue.
- Verify: keyboard dismisses via return, tap-outside, and on save/cancel.

## Item 3 — Analytics → Pulse doesn't reflect added income
Income was added (visible in Trends and Breakdown→Доходы) but **does not appear in the Pulse tab**.
- Determine the intended semantics of Pulse: if it's a net cash-flow / daily-flow view it MUST include income; if it's expenses-only by design, that's a UX gap (income entries look "lost"). Report which it is.
- Fix so added income is reflected in Pulse (net flow) OR, if Pulse is intentionally expenses-only, add a clear income/net toggle or label so income isn't silently missing. Recommend the net-flow interpretation unless the design says otherwise.
- Keep the Charts NaN guards intact (Pulse still must not crash on sparse data).
- Test: with income + expense in the same period, Pulse's data/series includes the income contribution (or the toggle exposes it).

## Report
Item 1: the exact non-finite source + the layout fix; confirm hint stays visible. Item 2: dismissal added where. Item 3: Pulse's intended semantics + the fix. Files changed, build status, commit hashes. Target: v1.0 (Items 1–2 are first-use UX on the marquee entry flow; Item 3 is analytics correctness).
