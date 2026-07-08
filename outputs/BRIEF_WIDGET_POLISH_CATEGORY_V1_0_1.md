# BRIEF (Claude Code) — v1.0.1 Widget polish + category-from-edit + localization. Model: Sonnet. Skills: apple-hig-expert (widget HIG), swiftui-design-skill, high-end-visual-design, emil-design-eng (ring/motion craft), review-animations.

**v1.0.1 (1.0 still in App Review — don't touch the submitted build).** `main`, commit per item, push, `xcodebuild … build` before each commit. Reuse the shipped semantic tokens + `Shared/Money.swift` (`formatCompact` already exists). Localize all new strings in ALL 5 locales. Don't reintroduce CLAUDE.md anti-patterns.

Device-QA evidence (real iPhone, ru_RU, light home screen + dark app). Do NOT re-derive; these are observed, not hypotheses.

---

## Item 0 (BLOCKER-ish, do FIRST) — widget leads with the LOSS frame
Observed: small widget renders "**194 ₽ / Расходы**"; large renders "Расходы 194 ₽ из 2 800 ₽ дохода". That is the **loss frame**. Our entire analytics research says lead with the **gain frame** ("safe to spend"), because loss pain ≈ 2× gain.
- The no-budget fallback picked "Spent" even though **income is known (2 800 ₽)** → remaining IS computable (2 606 ₽). Fix the hero selection precedence:
  1. Budget set → **"Safe to spend {remaining}"** (of {budget}).
  2. No budget but income known → **"Safe to spend {income − spent}"** (of {income}), gain-framed.
  3. Neither → "Spent {amount}" (last resort only).
  4. Over budget → over-budget state (see Item 2).
- Same precedence must hold on all three sizes. Verify the in-app Dashboard hero uses the same rule (don't let widget and app disagree).

## Item 1 — Can't create a new category when editing a transaction
Observed: Transactions → tap a transaction → "Изменить" → **Категория: «Выбрать…»** offers only existing categories; no way to add a new one. (Screenshot: edit screen for "Пряники".)
- Grep how the edit surface picks a category. Per CLAUDE.md, `CategoryPickerSheet` is the SINGLE shared picker for all entry surfaces — **route the edit screen through it too** (do not add a per-view picker; do not build a subset picker).
- Add an **"＋ New category"** affordance inside `CategoryPickerSheet` itself (reusing the existing `AddCategorySheet`), so every surface that uses the picker gets creation for free. Newly created category is auto-selected on return.
- Keep the keyboard-dismiss fixes on `AddCategorySheet` intact.

## Item 2 — Widget doesn't look Apple-native (the real complaint)
Observed problems, in priority order:
1. **Ring renders as a "worm."** At low progress the thick stroke + round caps reads as a smudged blob at 12 o'clock; the track is near-white on a near-white card in Light mode → no contrast. Fix: thinner stroke, visible track (use a proper tinted/secondary track that adapts to Light/Dark), and make a small-progress arc still read as an arc (min visible sweep or a dot-cap treatment). Follow WidgetKit/HIG proportions — the ring should look like Activity/Fitness-grade, not a paint stroke.
2. **Light-mode card is off-brand.** Use the system widget background (`containerBackground(.fiat)` / `.widgetBackground` per current API) so it adapts to Light/Dark and to the home-screen wallpaper tinting, instead of a flat white card. Verify in Light, Dark, and tinted/clear home-screen modes.
3. **Text truncation.** "Превышение бюд…" and "Еда и напит…" truncate. Shorten the localized strings for the widget (a widget label is not a sentence), allow `minimumScaleFactor` + `lineLimit(1)` deliberately, and check the longest of the 5 locales (ru/pt-BR are longest). No ellipsis in the shipped states.
4. **Over-budget is alarm-red.** A full red ring + large red number contradicts the calm direction. Keep a danger *signal* but soften: muted terracotta ring, neutral number, **icon + localized label** ("Over budget") — never hue-alone. (Accessibility: ~8% red-green colorblind.)
5. Typography/hierarchy: hero number dominant, period label secondary, category rows tertiary with mini bars. Match the app's type scale.

## Item 3 — Widget/app data mismatch (VERIFY before assuming it's cosmetic)
Observed at 12:12–12:13: app shows `Квадроцикл −1 000 000,00 ₽ / Без категории`, but the medium widget's category list shows `Без категории 700 ₽` (and hero 1 894 ₽). The 1M transaction is not reflected.
- Determine WHY: stale snapshot (debounce/reload not firing after that save), a filter excluding it, or an amount/overflow issue in the snapshot builder (1M in cents = 100,000,000 — check for Int overflow / truncation anywhere in the v2 contract).
- Report the actual root cause with evidence. **Do not "fix" blind.** If it's a reload timing issue, confirm `WidgetCenter.reloadAllTimelines()` fires after that save path.

## Item 4 — In-app: large numbers truncate + 0% rows
Observed (dark, Analytics): donut center reads `ПОТРАЧЕНО 1 003 893,9…` — truncated.
- Use the existing `Money.formatCompact` for the donut center (and any other constrained hero number) so large values abbreviate instead of clipping. Don't add a per-view formatter (anti-pattern).
- Legend rows currently show `0%` for real categories when one outlier dominates. Render **`<1%`** instead of `0%` for non-zero shares.

## Item 5 — Widget localization must follow the app's language
Question from QA: "if I change the language inside the app, does the widget stay on the system language?"
- **First, grep how language switching is implemented.** If it's the standard iOS per-app language setting, extensions generally follow. If it's a **custom in-app switcher** (writing `AppleLanguages` to standard `UserDefaults` or Bundle swizzling), that only affects the app process → **the widget will stay on the system language.** Report which mechanism we use.
- Fix so the widget matches the app:
  - Persist the selected language code in the **App Group** defaults.
  - **Do NOT bake localized strings into `NetSnapshot`.** Store category *keys* + SF Symbol names + amounts; localize inside the widget using the shared language code (explicit `Bundle` for that locale). Otherwise you get a mix: category names in the app's language, widget chrome ("Расходы") in the system language.
  - Call `WidgetCenter.reloadAllTimelines()` when the language changes.
- Number/currency formatting in the widget must use the same locale as the chosen language (via `Money.swift`).

## Item 6 (ONLY after Items 0–5 land green) — widget style variants
Requested by the CEO. Do it the Apple way: **widget configuration via AppIntent** (user picks in widget edit mode), NOT an in-app setting.
- Ship **2 variants max** to start (e.g. "Ring" and "Minimal/number-forward"). Both must obey the gain-frame hero, the calm palette, icon+label accessibility, and no truncation in any of the 5 locales.
- Don't add variants until the base widget passes device review — variants on a broken base multiply the defect.

## Tests (targeted)
Hero precedence (budget / income-only / neither / over-budget); ring fraction guards still hold (isFinite, clamp 0…1, budget==0); `formatCompact` used at the donut center; `<1%` legend rule; snapshot stores keys not localized strings; 1M-value round-trip through the snapshot (no overflow); category creation from the edit surface selects the new category; 5-locale parity + longest-string no-truncation check.

## Report (≤6 lines/item): root cause for Item 3 with evidence, hero-precedence change, ring/background/typography changes, localization mechanism found + fix, files changed, build status, commit hash per item. Device-verify: all 3 widget sizes in Light + Dark + tinted home screen, with budget / income-only / no data / over-budget; change app language → widget follows; edit a transaction → create a new category inline.
