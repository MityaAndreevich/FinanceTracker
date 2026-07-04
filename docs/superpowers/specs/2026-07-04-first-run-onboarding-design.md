# First-Run Onboarding — Coach-marks + Demo Data (Brief 28 Part B/C/E)

**Date:** 2026-07-04 · **Status:** design for review (Part A already shipped in `5e9713b`)

## Goal

Replace the current setup-first first-run (a language+currency wall + a passive
3-page carousel) with a "learn by doing" flow that lands a first win in 30–90s:
silent locale auto-detect → brief mascot greeting → in-place coach-marks on the real
Dashboard → guided first transaction (or demo-data sandbox) with a success moment.

Research anchors (from brief): interactive > passive carousels; progressive disclosure;
Day-0 activation drives trial conversion; **no rating prompt in onboarding**.

## What already exists (reused / retired)

- `OnboardingView` (language→currency wall) — **retired**; its `detectDeviceLanguage`
  / `defaultCurrency` logic is extracted for silent auto-detect.
- `TutorialFlow` + `TutorialPage1..3` (passive carousel, gated by `hasSeenFeatureTour`)
  — **retired**; best line folds into the mascot greeting.
- `DemoSeeder.resetAndSeedDemoData` — reused, but transaction insert routed through a
  new **guarded** path (Part C).
- Theme: Light + Dark both implemented (PART D finding) — **no change**.
- Part A budget CTA / open-form button — shipped; they become coach-mark targets.

## Architecture

### Coach-mark engine (new, `Views/Onboarding/Coachmarks/`)

- **`CoachmarkID`** enum: `.quickAdd`, `.budget`, `.analyticsTab`. (Dashboard + tab-bar
  targets only — the co-located set. Off-screen targets use inline hints, below.)
- **`CoachmarkAnchorKey`** — a `PreferenceKey` collecting `[CoachmarkID: Anchor<CGRect>]`.
- **`View.coachmarkTarget(_:)`** modifier — publishes a view's bounds anchor into the key.
- **`OnboardingCoordinator`** (`@Observable`, injected via environment) — phase state
  machine: `.inactive → .greeting → .coachmark(index) → .firstWin → .done`. Owns
  `advance()`, `skip()`, and the demo-data trigger. Persists completion to
  `@AppStorage("hasCompletedOnboarding")`. A `replayRequested` flag (set from Settings)
  restarts at `.greeting` without clearing user data.
- **`CoachmarkOverlay`** — full-screen `ZStack` layered over `ContentView`: a dimmed
  backdrop with a rounded-rect **cutout** around the active target's resolved frame, a
  caption bubble placed adjacent to it (flips above/below by available space), and
  **Next** + **Skip** controls. Tapping the backdrop advances; Skip ends the whole flow.
- **`MascotGreetingView`** — one small centered card: Budget Crab mascot + a single
  privacy line + "Show me" / "Skip". Not a carousel.
- **First win** — a compact prompt in the overlay's final step: "Add one now" (focuses
  the quick-add bar) OR "Explore with demo data" (guarded seed). On the first successful
  save (real or the sandbox landing), `.sensoryFeedback(.success)` + spring + a
  "You're set!" beat, then `.done`.

### Inline hints (off-screen targets — shown in-context, once each)

- **Open-form hint** — first time the "+" QuickEntry sheet opens, a one-line hint bubble
  points at the "Use detailed form" button. Gated by `@AppStorage("hasSeenOpenFormHint")`.
- **Period-pager hint** — first visit to the Transactions tab, a hint on the
  `PeriodSelector` ‹ › ("Tap ‹ › to change months"). Gated by
  `@AppStorage("hasSeenPeriodHint")`.
- Reused component: a small `InlineHintBubble` with a dismiss ("Got it") ≥44pt.

### Demo data (Part C — guarded)

- New guarded insert used by `DemoSeeder`: build the demo `Transaction` rows (unchanged),
  then perform ONE `modelContext.save()` wrapped in the SAME try/catch cleanup as
  `QuickAddSaveService.save` — on throw, delete the just-inserted rows so no poisoned/
  ghost pending inserts remain (the mid-fix save bug). Rows carry `isDemo = true`.
- Fully reversible: existing **Settings → Reset Transactions** clears them; add a one-tap
  **"Clear demo data"** action (deletes only `isDemo == true` rows) surfaced when demo
  data is present. A subtle "Demo data" label communicates the sandbox state.

### Launch sequence (Part E — no setup wall)

`RootView`: on `hasCompletedOnboarding == false`, run silent `LocaleAutoDetect`
(language from `Locale.preferredLanguages`, currency from `Locale.current.currency`,
falling back to language-based default), write `appLanguageCode` / `defaultCurrencyCode`
/ `AppleLanguages`, then present the app with `OnboardingCoordinator` active
(`.greeting`). No picker gate. Pickers remain in Settings unchanged. "Replay tutorial"
added to Settings.

## Components & boundaries (one purpose each)

| Unit | Does | Depends on |
|---|---|---|
| `LocaleAutoDetect` | device → (language, currency) | Foundation `Locale` |
| `CoachmarkAnchorKey` / `.coachmarkTarget` | publish target frames | SwiftUI preferences |
| `OnboardingCoordinator` | phase state machine + persistence | AppStorage |
| `CoachmarkOverlay` | dim + cutout + caption + Next/Skip | coordinator, anchors |
| `MascotGreetingView` | greeting card | coordinator |
| `InlineHintBubble` | one-shot contextual hint | AppStorage flags |
| guarded demo seed | reversible sandbox insert | DemoSeeder, save guard |

## Testing

- `LocaleAutoDetect` — unit tests: device-language/region → expected language+currency,
  ambiguous region → silent default (no crash).
- Guarded demo seed — test: a forced mid-seed save failure leaves **zero** rows (no
  ghosts), mirroring the existing poison-guard tests; success path inserts the full set
  and is idempotent under re-seed.
- `OnboardingCoordinator` — phase transitions incl. skip and replay.
- Locale parity test updated for all new keys (all 5 locales).
- Manual/screenshot: every coach-mark step + mascot greeting + first-win, dark.

## Guardrails

- All new strings keyed in en/ru/es/pt-BR/uk; parity baseline bumped.
- Captions honor Dynamic Type; tap targets ≥44pt; VoiceOver labels on targets + controls.
- No parser/save mechanic changes beyond routing demo inserts through the guarded path.
- No rating prompt anywhere in onboarding.

## Non-goals

- No Dashboard month-paging feature (A#3 stays an inline hint on the existing
  Transactions `PeriodSelector`).
- No theme changes (PART D: Light already works).
- Coordinated tab/sheet-hopping tour (rejected for fragility).
