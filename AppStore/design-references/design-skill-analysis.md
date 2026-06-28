# Design Skill Analysis — Budget Crab UI

**Skill:** `design` (Apple HIG / Liquid Glass / visual hierarchy lens)
**Date:** 2026-06-28 · **Scope:** Dashboard, Analytics (Pulse/Breakdown/Horizon), QuickEntry, Settings, Categories, Onboarding, Tutorial, AuthGate
**Method:** Source read + live simulator screenshots (iPhone 16 Pro Max, iOS 18.6). Analysis only — no code changed.

---

## Headline finding

**A complete "Quiet Premium" design-token system already exists and is ~30% adopted.**
`DesignSystem.swift` defines `Spacing`, `CornerRadius`, `Elevation`, `cardSurface()`, and a `Font` scale (`bcDisplay`/`bcAmount`/`bcTitle`/…). `Color+Semantic.swift` defines `Color.brand` (the exact mint `61/220/151`), `bcIncome`, `bcExpense`, `bcCardFill`, `bcSeparator`, `money(isPositive:)`.

Yet most views **bypass these tokens** with hardcoded magic numbers:
- `Color(red: 61/255, green: 220/255, blue: 151/255)` is re-declared as a private `mintColor` in **5 view files** (`DashboardView`, `TutorialFlow`, `TutorialPage1/2/3`) — `Color.brand` already is this exact value.
- Card surfaces are built three different ways: `.cardSurface(...)` (Pulse only), `Color(.secondarySystemBackground)` + manual `RoundedRectangle(cornerRadius: 12)` + `strokeBorder` (Dashboard, Breakdown legend), and `.thinMaterial` + `RoundedRectangle(cornerRadius: 16)` (Dashboard "This Week"). Radii drift between **12 and 16** on sibling cards.
- Fixed point sizes (`.font(.system(size: 48))`, `26`, `34`, `13`) are used in place of `Font.bcAmount`/`bcTitle`/`bcCaption` and Dynamic Type text styles.

This is the single highest-leverage, lowest-risk design improvement: it is mostly mechanical token substitution, it removes visible inconsistency, and it does **not** require touching the token files (which are frozen).

> Note re HIG **2026 / Liquid Glass**: the `design` skill centers on `.glassEffect()` (iOS 26+). The app's deployment target is **iOS 17/18.5**, so Liquid Glass is **not adoptable pre-submission** without dropping the iOS 17–18 install base. It is listed below as a *strategic* item, not a launch blocker.

---

## What's working (keep)

- **CVD-safe money encoding** — sign (`+`/`−`) + direction arrow + color, never color alone (`DashboardView:291`, HIG/WCAG compliant). This is genuinely above-average.
- **`.privacySensitive(true)`** on every balance → redaction in the App Switcher (HIG Privacy). Consistent across Dashboard/Pulse/Breakdown/Horizon.
- **Restraint** — system materials, inset-grouped lists, no gratuitous chrome. The light Dashboard/Analytics screens read calm and premium (matches the Things 3 / Copilot "quiet" register).
- **Chart interaction** — sticky scrub selection + haptics + tappable drill-down on Pulse & Horizon is a genuine Apple-Stocks-grade touch.
- **VoiceOver chart descriptor** on Breakdown (`AXChartDescriptorRepresentable`) — most indies skip this.

---

## Anti-patterns & HIG issues (by severity)

### P0 — Visual-system inconsistency (token bypass)
Evidence above. Symptoms a reviewer/user feels: subtly different card radii, two different "mint"s if the brand color is ever retuned (5 copies won't update), and amount type that doesn't match the documented scale. Contradicts the project's own `MASTER.md` design-system intent and the CLAUDE.md "no per-view color helpers" rule.

### P1 — Tutorial is a different design universe
`TutorialFlow` uses a **dark purple gradient** (`0.11,0.09,0.22 → 0.15,0.10,0.32`) with white text, while the entire rest of the app is light/system "Quiet Premium." The tour also uses raw **`.red`** for the expense preview (`TutorialPage1:60`) instead of the `bcExpense` terracotta used everywhere else — so the very first thing a new user is taught looks different from the real app. First-run visual promise ≠ product. (Reference: Day One / Bear keep onboarding in the same palette as the app.)

### P1 — Dynamic Type fragility
Pervasive fixed `.font(.system(size:))`. The 48pt hero uses `minimumScaleFactor(0.7)` (good), but onboarding 34pt titles, tutorial 26pt headlines, and many captions have no scaling path and will clip or overflow at large accessibility text sizes. HIG calls Dynamic Type support a baseline. Things 3 and Bear scale fluidly.

### P2 — Dashboard hero hierarchy is crowded
Under the net amount sit **four** stacked secondary lines: spent/earned caption, "Earned more than spent," "Based on tracked transactions," plus the section starts immediately. Three tiers of gray text dilute the one number that matters. Copilot/Reflect keep the hero to amount + one supporting line.

### P2 — Donut "opacity-by-rank" hurts legibility
Breakdown encodes *direction* as hue and *rank* as opacity down to 0.35 (`AnalyticsBreakdownView:150`). Clever and CVD-defensible, but ≥4 expense slices become near-indistinguishable washes of the same terracotta, and low-rank slices fall below comfortable contrast. Reference donuts (Copilot) use distinct per-category hues. Consider a small fixed categorical palette (still paired with labels) or a floor higher than 0.35.

### P3 — AuthGate locked screen is utilitarian
Plain `lock.fill` + secondary text. Functional, but it's a daily touchpoint for lock users and the one screen with zero brand warmth. A subtle brand-tinted lock glyph would cost nothing.

---

## TOP 5 ACTIONABLE IMPROVEMENTS

1. **Adopt the existing tokens app-wide (P0, low effort, high impact).** Replace all 5 private `mintColor` decls with `Color.brand`; route every card through `.cardSurface(cornerRadius: CornerRadius.card)`; swap fixed amount fonts for `Font.bcAmount`/`bcDisplay`/`bcTitle`. Pure substitution, no token-file edits, instantly unifies radii/color/type.

2. **Re-skin the tutorial to the app palette (P1, med effort).** Drop the purple gradient for the app's light surface (or a soft `Color.brand` tint), and replace `.red`/`.white` previews with `bcExpense`/`bcIncome`/primary so the first-run preview matches the product the user lands in.

3. **Make type scale with Dynamic Type (P1, med effort).** Move titles/headlines/captions to text styles (`.largeTitle`/`.title`/`.caption`) or `Font` tokens with `relativeTo:`; add `minimumScaleFactor`/`lineLimit` audit on the hero numbers. Verify at XXL accessibility size.

4. **Simplify the Dashboard hero (P2, low effort).** Collapse the four sub-lines to **amount + one** ("Earned more than spent" *or* the spent/earned caption). Demote "Based on tracked transactions" to an info affordance. Let the number breathe.

5. **Raise donut legibility (P2, low effort).** Lift the opacity floor (e.g. 0.5) or introduce a small distinct-hue categorical palette for the top slices; keep the label+% so it stays CVD-safe.

---

## Reference-app calibration

| Pattern | Budget Crab | Things 3 / Bear / Reflect / Day One |
|---|---|---|
| Token discipline | Defined, under-used | Rigid single source, fully applied |
| Onboarding palette | Diverges (purple) | Same palette as app |
| Dynamic Type | Partial | Fluid |
| Hero restraint | Slightly crowded | Single focal element |
| Calm/premium register | ✅ Strong | ✅ |
| Chart craft | ✅ Above peer indies | n/a |

**Bottom line:** the foundations are genuinely good — the gap is *discipline*, not taste. Closing the token-adoption gap and unifying the tutorial would move the app from "nicely built" to "cohesive," with most of the work being low-risk substitution that preserves submission readiness.
