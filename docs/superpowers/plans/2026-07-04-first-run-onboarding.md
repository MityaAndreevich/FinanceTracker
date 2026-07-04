# First-Run Onboarding Implementation Plan

> **For agentic workers:** Execute with superpowers:executing-plans, inline, task-by-task. Each task ends with a green build + a dark device-size screenshot (where UI) and a commit. Steps use `- [ ]`.

**Goal:** Replace the setup-first first-run with silent locale auto-detect → mascot greeting → in-place Dashboard coach-marks → guided first win, plus a reversible demo-data sandbox.

**Architecture:** A `@Observable OnboardingCoordinator` drives a phase state machine; a `CoachmarkOverlay` reads target frames published via a `PreferenceKey` (`.coachmarkTarget(id)`) and renders dim+cutout+caption over `ContentView`. Off-screen targets get one-shot inline hints. `DemoSeeder` gains a guarded bulk insert.

**Tech Stack:** SwiftUI, SwiftData, @AppStorage, Xcode 16 (filesystem-synchronized groups — new files auto-compile).

## Global Constraints

- Localize every new string in en/ru/es/pt-BR/uk; bump `LocaleCompletenessTests` baseline (currently 533).
- Tap targets ≥44pt; captions honor Dynamic Type; VoiceOver labels on targets + controls.
- No parser/save mechanic changes beyond routing demo inserts through the guarded path.
- No rating prompt in onboarding.
- Build green before each commit; commit per unit; push; dark screenshot per UI unit.
- Mascot: reuse app-icon crab centered; SF Symbol fallback; `// TODO` for real art.

---

### Task 1 (Unit: engine): Coach-mark overlay engine

**Files:**
- Create: `FinanceTracker/Views/Onboarding/Coachmarks/CoachmarkID.swift` (enum + PreferenceKey + `.coachmarkTarget` modifier)
- Create: `FinanceTracker/Views/Onboarding/Coachmarks/OnboardingCoordinator.swift` (`@Observable`, phase machine, AppStorage persistence)
- Create: `FinanceTracker/Views/Onboarding/Coachmarks/CoachmarkOverlay.swift` (dim + rounded cutout + caption bubble + Next/Skip)
- Test: `FinanceTrackerTests/OnboardingCoordinatorTests.swift`

**Interfaces:**
- Produces: `enum CoachmarkID { case quickAdd, budget, analyticsTab }`; `extension View { func coachmarkTarget(_:CoachmarkID) -> some View }`; `@Observable final class OnboardingCoordinator { enum Phase; var phase; func start(); func advance(); func skip(); func finishFirstWin() }`; `struct CoachmarkOverlay: View { }`.

- [ ] Write `OnboardingCoordinatorTests` (phase transitions: start→greeting; advance walks coachmark indices then →firstWin; skip→done sets hasCompletedOnboarding; replay restarts).
- [ ] Implement the three engine files; anchor via `anchorPreference(key:value:)` + `overlayPreferenceValue` reading `[CoachmarkID: Anchor<CGRect>]` through a `GeometryProxy`.
- [ ] Run `OnboardingCoordinatorTests` green; build green.
- [ ] Commit `feat(onboarding): coach-mark overlay engine (coordinator + anchors + overlay)`.

### Task 2 (Unit: launch flow): silent auto-detect + greeting + wiring; retire wall & carousel

**Files:**
- Create: `FinanceTracker/Shared/LocaleAutoDetect.swift` (device → language+currency; extracted from OnboardingView logic)
- Create: `FinanceTracker/Views/Onboarding/MascotGreetingView.swift`
- Modify: `FinanceTracker/Views/RootView.swift` (first-run: run auto-detect, present app + coordinator; drop `OnboardingView`)
- Modify: `FinanceTracker/Views/ContentView.swift` (host coordinator + `CoachmarkOverlay`; add `.coachmarkTarget` to quick-add bar / budget CTA / Analytics tab; remove `TutorialFlow`/`hasSeenFeatureTour`)
- Modify: `FinanceTracker/Views/DashboardView.swift` (tag quick-add + budget CTA targets)
- Delete: `FinanceTracker/Views/Onboarding/OnboardingView.swift`, `FinanceTracker/Views/Tutorial/*`
- Test: `FinanceTrackerTests/LocaleAutoDetectTests.swift`
- Strings: greeting + coach-mark captions in 5 locales; parity bump.

**Interfaces:**
- Consumes: `OnboardingCoordinator`, `CoachmarkID`, `.coachmarkTarget`.
- Produces: `enum LocaleAutoDetect { static func resolve() -> (language: SupportedLanguage, currency: SupportedCurrency) }`.

- [ ] `LocaleAutoDetectTests`: en/US→(.en,.usd), ru/RU→(.ru,.rub), unsupported→(.en, region-or-usd), ambiguous region→no crash.
- [ ] Implement `LocaleAutoDetect`; `MascotGreetingView` (app-icon crab, one line "quick_entry.privacy_chip"-tone, Show me/Skip).
- [ ] Rewire RootView/ContentView; delete wall + carousel; tag 3 Dashboard/tab targets.
- [ ] Add strings (all 5) + bump parity; run locale + auto-detect tests green; build green.
- [ ] Screenshot: greeting + each of the 3 coach-mark steps (dark). Commit `feat(onboarding): silent locale detect + mascot greeting + Dashboard coach-marks; retire setup wall & carousel`.

### Task 3 (Unit: demo data): guarded bulk seed + first-win + clear

**Files:**
- Modify: `FinanceTracker/Data/DemoSeeder.swift` (guarded insert: build rows → one `save()` in try/catch with delete-on-failure, mirroring `QuickAddSaveService.save`)
- Modify: `FinanceTracker/Views/Settings/GeneralSettingView.swift` (one-tap "Clear demo data" when `isDemo` rows exist)
- Modify: coordinator/overlay first-win step ("Add one now" / "Explore with demo data")
- Test: `FinanceTrackerTests/DemoSeederGuardedTests.swift` (forced mid-seed failure → zero rows; success → full set; idempotent)
- Strings: first-win + clear-demo in 5 locales; parity bump.

**Interfaces:**
- Consumes: `DemoSeeder`, `OnboardingCoordinator.finishFirstWin`.
- Produces: `DemoSeeder.seedDemoDataGuarded(modelContext:) throws`; `DemoSeeder.clearDemoData(modelContext:)`.

- [ ] `DemoSeederGuardedTests` using the existing `_forceSaveFailureForTesting` pattern → assert 0 rows after failure.
- [ ] Implement guarded seed + clear; wire first-win (success beat on first REAL save only; demo lands populated dashboard, no fake toast).
- [ ] Strings (5) + parity bump; tests green; build green.
- [ ] Screenshot: first-win step + populated demo dashboard (dark). Commit `feat(onboarding): guarded demo-data sandbox + guided first win`.

### Task 4 (Unit: hints): one-shot inline hints for off-screen targets

**Files:**
- Create: `FinanceTracker/Views/Onboarding/InlineHintBubble.swift`
- Modify: `FinanceTracker/Views/QuickEntry/QuickEntryView.swift` (open-form hint, `@AppStorage("hasSeenOpenFormHint")`)
- Modify: `FinanceTracker/Views/TransactionsView.swift` (period-pager hint, `@AppStorage("hasSeenPeriodHint")`)
- Strings: 2 hint captions in 5 locales; parity bump.

- [ ] Implement `InlineHintBubble` (caption + "Got it" ≥44pt, Dynamic Type, VoiceOver).
- [ ] Gate each hint to first appearance of its surface; strings (5) + parity bump; build green.
- [ ] Screenshot: open-form hint + period hint (dark). Commit `feat(onboarding): one-shot inline hints for open-form and period pager`.

### Task 5 (Unit: polish): Replay tutorial + a11y/Dynamic-Type sweep

**Files:**
- Modify: `FinanceTracker/Views/Settings/GeneralSettingView.swift` ("Replay tutorial" → coordinator replay)
- Modify: coach-mark/greeting views (VoiceOver labels, Dynamic Type caps, reduce-motion)
- Strings: "Replay tutorial" in 5 locales; parity bump.

- [ ] Add Replay row; verify skip/replay loop; a11y labels on all coach-mark controls; captions cap at xxxLarge with reduce-motion respected.
- [ ] Strings (5) + parity bump; full `FinanceTrackerTests` suite green; build green.
- [ ] Screenshot: Settings replay + a large-Dynamic-Type coach-mark (dark). Commit `feat(onboarding): replay tutorial + accessibility polish`. Push.

## Self-Review

- **Spec coverage:** greeting ✓(T2) · coach-marks ✓(T1/T2) · silent detect + retire wall ✓(T2) · retire carousel ✓(T2) · guarded demo + first win ✓(T3) · clear demo ✓(T3) · inline hints (open-form, period) ✓(T4) · replay ✓(T5) · a11y ✓(T5) · locale parity ✓(each task) · no rating prompt ✓(N/A). PART D: no task (no change, by design).
- **Placeholders:** none — code written at execution per unit; interfaces named.
- **Type consistency:** `CoachmarkID`, `OnboardingCoordinator.{start,advance,skip,finishFirstWin}`, `LocaleAutoDetect.resolve`, `seedDemoDataGuarded`/`clearDemoData` used consistently across tasks.
