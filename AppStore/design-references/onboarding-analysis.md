# Onboarding Analysis — Budget Crab

**Skill:** `onboarding` (activation CRO)
**Date:** 2026-06-28 · **Inputs:** `OnboardingView`, `TutorialFlow` + `TutorialPage1/2/3`, `ContentView` (gating), `DashboardView` empty/Day-0 states, `.agents/product-marketing.md`
**Method:** Source read + live first-run on simulator. Analysis only.

> ⚠️ **Structural measurement caveat:** Budget Crab has **no analytics SDK by design** (the privacy promise). Activation rate / funnel drop-off **cannot be measured remotely** — there are no servers to receive events. All activation tuning must be validated via **TestFlight cohorts + qualitative beta feedback**, not dashboards. This is the single most important constraint on this whole analysis: you are optimizing a funnel you can't instrument in production.

---

## The current first-run flow

```
Install
 → OnboardingView  Step 1: Language   (default: system, pre-filled)
 → OnboardingView  Step 2: Currency   (auto-mapped from language)
 → [AuthGate: passes silently, lock defaults to "never"]
 → TutorialFlow    Page 1: Type or speak   (animated demo)
                   Page 2: Learns as you go (animated demo)
                   Page 3: Your data stays yours + "Add sample data" toggle
 → Dashboard (empty) → animated arrow points up at the Quick Add bar
 → first Quick Add → transaction saved   ← ACTIVATION
```

**Proposed activation definition:** *first real transaction saved in session 1* (ideally via Quick Add or voice). Secondary: opens Analytics with ≥3 transactions (the "see my money" payoff).

---

## What's working (keep)

1. **Config is genuinely short** — 2 steps, both with smart defaults (language → currency auto-map: ES→MXN, PT→BRL, RU→RUB). Low activation energy; near the MoneyWiz "10-second setup" bar on the *config* portion. ✅
2. **Default effect well used** — currency pre-selected from language; user usually taps straight through.
3. **Empty state is directional, not a dead end** — animated arrow points at the Quick Add bar (`DashboardEmptyState`), telling the user exactly where to act. Good empty-state practice.
4. **Demo-data option exists** ("Add sample data to explore," `TutorialPage3`) — a value-first / test-drive path for blank-slate overwhelm.
5. **Goal-gradient on Day 0** — `"Add %d more transactions to see your first insight"` pulls the user forward.
6. **Skippable tour** — never traps the user.

---

## Activation funnel — drop-off risks (Finding → Impact → Recommendation → Priority)

### R1 — Five passive screens before any value
**Finding:** 2 config screens + 3 animated tutorial screens = up to **5 screens the user only watches** before touching the product. The tutorial *shows* "67 gas → Transport" rather than letting the user *do* it.
**Impact:** Time-to-value is the #1 retention driver; this is the biggest delay. Violates "Do, don't show" and "time-to-value is everything."
**Recommendation:** Make the first transaction *be* the tutorial — an interactive "type your first one (try `coffee 4`)" on the empty Dashboard — or cut the tour to 1–2 screens and move feature education to contextual moments.
**Priority:** **P0**

### R2 — The hero differentiator (voice) is never surfaced or primed
**Finding:** Voice entry (on-device dictation) is a top-3 selling point, but first-run never demonstrates it or primes the mic permission. Discovery is left to chance in Quick Entry. Siri/Shortcuts/Widget likewise undiscovered.
**Impact:** The most "magic," most differentiated moment never happens in session 1 — the aha is weaker than it could be.
**Recommendation:** Add an interactive "tap the mic and say it" beat in first-run with proper permission priming (explain *before* the system prompt). Surface Siri/Widget as a post-activation tip.
**Priority:** **P0/P1**

### R3 — Empty Dashboard with no encouraged first action
**Finding:** After the tour, the default path lands on a truly empty Dashboard (demo toggle defaults OFF). Only an arrow nudges the user.
**Impact:** Blank-slate overwhelm; some users bounce without ever saving a transaction.
**Recommendation:** Either (a) inline interactive first entry (R1), or (b) make "explore with sample data" a first-class, clearly-labeled choice up front (see R5).
**Priority:** **P1**

### R4 — Language step is pre-value friction
**Finding:** Language is asked explicitly though the device language is already known; for most users this screen is a redundant tap before value.
**Impact:** Small but real added friction before the first win; also the screen tied to the known sheet-dismiss timing bug.
**Recommendation:** Auto-detect language from the device and confirm silently (or fold into a single combined "Language · Currency" screen), leaving the Settings escape hatch.
**Priority:** **P1**

### R5 — "Test drive" is buried
**Finding:** Demo data is a toggle on tutorial page 3, off by default, easy to miss — versus Copilot's front-and-center test-drive.
**Impact:** The lowest-risk way to reach "aha" (see a populated Dashboard/Analytics instantly) is hidden.
**Recommendation:** Offer an explicit fork early — "Start fresh" vs "Explore with sample data" — clearly labeled as sample, with one-tap clear (the clear action already exists in Settings).
**Priority:** **P2**

### R6 — No first-win celebration (peak-end)
**Finding:** Saving the first transaction fires a success haptic but no moment ("first one down — here's your month taking shape"), and no nudge toward Analytics.
**Impact:** Misses the peak-end opportunity that cements habit and routes to the second aha (seeing patterns).
**Recommendation:** Lightweight first-save acknowledgment + a one-time "see it in Analytics" nudge once ≥3 transactions exist.
**Priority:** **P2**

### R7 — In-session is the *only* activation window
**Finding:** No accounts/email means no welcome/re-engagement email series is possible. The sole re-engagement lever is local notifications (currently only recurring-charge reminders).
**Impact:** If session 1 doesn't activate, recovery options are thin.
**Recommendation:** Consider a *single, gentle, opt-respecting* local nudge for users who finished onboarding but logged nothing in N days. Keep it non-naggy and on-brand (no guilt).
**Priority:** **P2**

---

## vs. 2026 best practices

| Benchmark | Budget Crab | Gap |
|---|---|---|
| MoneyWiz ~10s setup | Config ~10s ✅, but +3 tutorial screens | Net time-to-value longer than it looks |
| Copilot "test drive" | Has demo data, but buried/off | Promote to first-class choice |
| "Do, don't show" interactive first-run | Animated *show* only | Convert to *do* |
| Permission priming for hero feature | Absent for mic | Add priming beat |

---

## TOP 5 ACTIONABLE IMPROVEMENTS

1. **Turn the first transaction into the tutorial (P0).** Replace/trim the 3 passive screens with one interactive "type or speak your first transaction" on the empty Dashboard. Collapse 5 passive screens toward 1 active one.
2. **Showcase + prime voice in first-run (P0/P1).** Demonstrate on-device dictation interactively with permission priming; tease Siri/Widget after the first save.
3. **Auto-detect language; cut a pre-value screen (P1).** Confirm device language silently or merge with currency; reduce taps before value.
4. **Promote "Explore with sample data" to an explicit early fork (P2).** Clearly labeled test-drive with one-tap clear — the fastest path to "see my money."
5. **Add a first-save peak + Analytics handoff (P2).** Small celebration on first transaction and a one-time nudge into Analytics once data exists.

---

**Bottom line:** the *configuration* is admirably lean, but the activation path is **passive where it should be interactive** and **hides its two best accelerants** (voice, sample-data test-drive). Because the privacy architecture forbids production analytics, these changes must be validated through TestFlight cohorts — make the first-run interactive enough that qualitative testers reliably reach a saved transaction without prompting.
