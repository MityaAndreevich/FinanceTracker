# Guide step 3 — Guide root + card screens from keys + claim test (PLAN, for approval)

Design: `DESIGN_USER_GUIDE.md` §3 (layout), §9 (no drift), §12.2 (guards), §13 item (3). Rulings:
`STATE.md` §13.1, and the D50-class tier rule (`GUIDE_STEP2_PLAN.md`, last section). Branch
`feat/guide-step3-cards`, cut from main at `413bfa8` (steps 1–2 + D52 merged). **Nothing is built yet.**

## What step 3 builds — and what it leaves to step 4
- **Settings row** "How to use Budget Crab", first in group 2 → `SettingsRoute.guide` →
  `screen.settings.guide`.
- **Guide root:** six group headers in the design's order; one row per card (icon, title, one-line
  purpose); search over titles and purposes in the current language; a top row "Replay the
  walkthrough" calling the existing replay action. `GuideDestination.guideRoot` is added here, since it
  needs the screen to exist.
- **Card screen:** title → purpose → numbered steps → Show me → tier line → Related. No screenshots
  (that's step 5). Each element gets an accessibility id.
- **Content in step 3: two cards only, A1 and B1, in all 5 locales.** B1 is the acceptance path
  (§12.1). Step 4 adds the other 24. The catalog lists **only cards that exist**. A filter that hides
  cards whose strings are missing would be the silent-success class, so there isn't one.

## Mechanism
- **`GuideCard` catalog (static, in code):** id, group, `titleKey`, `purposeKey`, `stepKeys`,
  `destination: GuideDestination?`, `capabilities: [AppCapability]`, `related: [GuideCard.ID]`.
  Strings: `guide.card.<id>.title|purpose|step.N`.
- **Tokens (§9.1):** a step string carries `{some.key}`. `GuideText.render` resolves each token
  through `LocalizedBundle` (never `Bundle.main`, per memory `project_learn_tips_hub_v102`) and
  renders it bold. An unresolvable token renders as the key itself. `GuideClaimTests` makes that state
  unshippable. No `String(localized:)` without an explicit bundle (the `LocalizedCallSiteGuardTests`
  rule).
- **Show me = the second caller of `GuideRouter.open(_:)`.** `open` is not edited. No button when
  `destination == nil`, or for `setupSiri` when `canOpenURL` is false.
- **Tier line, derived, never typed (D50 rule):** computed from the card's `capabilities` through
  `AccessManager.isAllowed` and the `FreeTierLimits` constants. This is the pattern the paywall
  comparison table already uses (memory `project_paywall_clarity_v102`). Three states, and the copy
  must be true in all of them:
  - free → no line;
  - gated, unlocked (paid or reverse-trial preview) → "Premium — included in your preview" / "…in your
    plan";
  - gated, locked → "Premium. Show me opens the screen; the locked controls explain the upgrade."
  A card whose gated part is a cap (A7 categories past 3, A8 accounts past 2, A10 scans past 5) says
  the cap, read from `FreeTierLimits`.

## Tests (each observed red before green)
| test | guards | red by |
|---|---|---|
| `GuideClaimTests` (unit) | every `{key}` in every card exists in all 5 `.lproj`, and has ≥ 1 use in a `.swift` outside `Views/Guide/`; every card's own keys exist ×5 | a card citing `{tab.add}` (design §9) |
| `GuideTierLineTests` (unit) | every gated capability yields a Premium line in BOTH the unlocked and the locked state; free cards yield none | tier line hard-coded to "free" |
| `GuideCardJourneyTests` (UI) | Settings → Guide → A1 → Show me lands on Quick Entry; → B1 → Show me lands on `BudgetSetterSheet`. Proven by the step-2 destination ids | a Show me button that does not call `open` |
| `ReleaseDebugAffordanceTests` | unchanged: step 3 adds no DEBUG affordance | — |
| `SettingsStackDeepPopTests` (R1) | unchanged, still in the full suite | — |

The suite count goes up. EXPECTED_TOTAL_RUN is set by the next full run (rule 9), not by arithmetic.

## Decisions for Dmitry before building
1. **E2 (open from step 2).** Code read: on Automatic reports, a tap on a locked row opens
   `PaywallView` (`ReportsSettingsView.swift:97–101`). So the upgrade explanation is one tap away, but
   nothing on the screen says that. **Recommended:** the derived tier line on the E2 card states Premium
   *before* Show me ("tap a locked row to see what Premium adds"), and the screen stays unchanged.
   Alternative: add one line to that screen's footer (a string in 5 locales, outside the Guide).
2. **When "Set up Widget & Siri" goes (ruling 14.2).** **Recommended:** in step 4, once the cards that
   absorb `help.widget` and `help.siri` exist, so the app never has neither.
3. **Step-3 fixture cards: A1 + B1** (recommended). The other choice is a single card, which can't
   exercise Related.
4. **Translations of A1/B1 in ru, uk, es, pt-BR** are drafted by Claude and **flagged for the pt/es
   sweeps** already in 1.0.7 scope. They are not claimed native-reviewed.
