# Budget Crab — Device QA Checklist (post bug-fix, ~5–8 min)

Run on a real iPhone after the bug-fix build. Tick each. If any FAILS → back to Claude Code with the specific item. Run the ⭐ core-loop items in BOTH Dark and Light. **Check localization + Quick Entry layout (D, F) in ALL 5 locales — EN, RU, es-MX, pt-BR, uk — not just EN/RU** (longer strings overlap worse).

## A. Quick add on Dashboard  (guards B1, B2)
- [ ] ⭐ Type `50 кофе` (or `$50 coffee`) in the top quick-add → preview shows the amount **once**, correct value.
- [ ] ⭐ Tap **Save once** → exactly **ONE** transaction is added with the **exact amount** (NOT doubled).
- [ ] ⭐ After Save → the input **clears** and the preview **disappears** (no lingering "tap again" state).
- [ ] Tapping Save with an empty input does nothing / is disabled (no empty/ghost transaction).

## B. Detailed "+" Add form  (guards B3)
- [ ] ⭐ Open the **+** tab → **Open form / detailed** → fill amount + category → **Add** → saves with **no error alert**; the transaction appears in Transactions.
- [ ] Save works even with no account selected (account is optional) — or the field is clearly required, not a silent fail.
- [ ] Edit an existing transaction → change amount → save → updates correctly.
- [ ] Delete a transaction → it's gone; totals update.

## C. NL parse + voice  (guards B4)
- [ ] ⭐ Type `50 кофе` → NO false "couldn't recognize" error; amount + **category auto-detected** (Food & Drink / Кофе).
- [ ] Type `Кофе 1000` and `350₽ кофе` → parse correctly (amount + category), no error banner on valid input.
- [ ] ⭐ Tap the **mic**, say "пятьдесят кофе" / "fifty coffee" → transcribes on-device AND **resolves a category** (not "Без категории").
- [ ] A genuinely unparseable string (e.g. random letters) → shows the "open form" hint gracefully (that's correct).

## D. Localization  (guards B5) — run in RU
- [ ] ⭐ Dashboard hero labels are **Russian** ("Потрачено/Заработано", not "Spent/Earned").
- [ ] Parsed-preview + donut legend + tiles show **localized category names** (не "Food & Drink" в русском UI).
- [ ] Scan every visible screen for stray English — Settings, Analytics tabs, Quick Entry, empty states.

## E. Currency  (guards B6)
- [ ] Set default currency to RUB in Settings → **every** amount (hero, donut, preview, rows, quick-entry placeholder) shows **₽**, none show `$`.
- [ ] Switch default currency to USD → all show `$` consistently. (Currency follows the setting, not the language.)

## F. Quick Entry layout  (guards B7)
- [ ] ⭐ Open **+** → nothing **overlaps**; chips row, preview, input, mic, Save are cleanly spaced.
- [ ] Settings → increase **Text Size** (Dynamic Type, large) → re-open + → still no overlap / clipping.
- [ ] Small device (if available, e.g. SE/mini) → layout still holds.

## G. Analytics  (guards B8)
- [ ] ⭐ Analytics → **Тренды/Horizon** → chart renders a **sane** line + Y-axis (no −300 000 spike / broken scale).
- [ ] Breakdown → multi-color donut, correct %, legible.
- [ ] Pulse → net + Earned/Spent rows with correct direction colors/arrows.

## H. Light theme  (guards D1)
- [ ] ⭐ Switch to Light → surfaces look **warm + layered** (cards separated by hairline/shadow), NOT flat blank white.
- [ ] Cards, donut, tiles, text all legible in Light; no invisible white-on-white.

## I. General regression (quick pass)
- [ ] Categories & Accounts screens open, colored tiles correct.
- [ ] Export (CSV/PDF/Excel) works.
- [ ] Face ID lock (if enabled) gates app open.
- [ ] Paywall opens (Settings → Premium) → prices $4.99/$34.99/$99.99, Save 42%, 7-day trial text.
- [ ] Theme switcher System/Light/Dark all apply.

## Sign-off
- [ ] All ⭐ core-loop items pass in Dark + Light, RU + EN.
- [ ] No console/red errors during the run.
→ Only then: regenerate screenshots → compose → submit.
