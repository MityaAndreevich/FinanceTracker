# BRIEF (Claude Code) — First-run onboarding (coach-marks + demo data) + discoverability fixes

Paste into Claude Code. **Restart CC first so superpowers is active.** Model: **Sonnet**. Use superpowers `brainstorming` → `writing-plans` to spec the coach-mark overlay component, then execute; verify with screenshots.

## Why (research-grounded — do not improvise past this)
- First "win" must land in **30-90s** (critical: we ship a **30-day trial**, 86% of trials start within 24h → Day-0 activation decides conversion).
- **Interactive "learn by doing" beats passive carousels** (Headspace 96% activation, Blinkist +23%). So: coach-marks on the REAL UI + a demo-data sandbox, NOT a full-screen slideshow.
- **Progressive disclosure**: reveal advanced surfaces (Analytics/Trends) only after the first action; don't dump everything at once.
- **Do NOT put a rating prompt in onboarding** — Apple now rejects onboarding rating prompts (§ our Legal notebook). Rating prompt stays gated to a later success moment.
- Mascot (Budget Crab) anchors the empty state; success haptic + spring on first save.

## PART A — Discoverability fixes (ship regardless; these are the user's real pain points)
1. **Monthly budget entry point is invisible.** When no budget is set, show a clear dashboard card/CTA "Set your monthly budget" that opens the budget setter. When set, keep a clearly-labeled, tappable entry (label + chevron), not a bare number.
2. **"Open form" is tiny and unreadable as a control.** Replace with a proper button: SF Symbol + label ("Add details" / "Open full form"), min **44pt** tap target, visible button styling (filled/bordered), not micro-text.
3. **Period paging isn't discoverable** (user couldn't tell it scrolls). Add a persistent visual affordance — chevrons ‹ › or a hint — on the period selector, plus a first-run coach-mark.
4. **Feature discovery**: ensure tab bar items have visible labels; surface Analytics after the first transaction.

## PART A.5 — Calmer empty state (QuickEntry chips)
On the quick-add / "+" screen, in the EMPTY state (before the first keystroke), the colored category chips sit right under the title and out-shout the input. Per Quiet Premium (single restrained accent, input is the hero):
- **Hide the category chips until the first keystroke.** Empty state = no transaction yet → no category to pick → chips add noise. Reveal them once the user starts typing / a value parses (they're a correction tool). Keep the input's mint focus ring as the visual lead. This is a small, contained change to the QuickEntry empty/typing state.

## PART B — First-run onboarding (coach-marks + demo data)
Trigger once on first launch (gate with `@AppStorage("hasCompletedOnboarding")`); add **"Replay tutorial"** in Settings.

Flow:
1. **Brief mascot greeting** (single small bubble/sheet, NOT a carousel): Budget Crab + one line — "Private, on-device money tracking. Nothing leaves your phone." → "Show me" / small "Skip".
2. **Sequential coach-marks** (one at a time, dimmed backdrop, highlight target, short caption, "Next"; fully skippable):
   - Quick-add bar: "Type an expense — e.g. `coffee 50` — and tap Save."
   - The new **Open-form button** (Part A #2): "Need category, account or date? Open the full form here."
   - **Budget entry** (Part A #1): "Set your monthly budget here to see what's left to spend."
   - **Period pager** (Part A #3): "Swipe to move between months."
   - **Analytics tab**: "See your breakdown and trends here." (may appear after first tx instead)
3. **Guided first win**: prompt the user to add ONE transaction now OR tap **"Explore with demo data"**. On first successful save → `.sensoryFeedback(.success)` + spring transition + "You're set!" This is the 30-90s win.

## PART C — Demo data
- Reuse the existing **DemoSeeder**. Load must be **fully reversible** via Settings → Reset Transactions.
- ⚠️ **Route demo inserts through the SAME guarded save path** as normal saves (the anti-poison guard in QuickAddSaveService, commit eaa6091). Do NOT bulk-insert on a path that bypasses it — we are mid-fixing a poisoned-context save bug; a new unguarded bulk insert would reintroduce ghost rows.
- Label demo data clearly and offer a one-tap "Clear demo data".

## PART D — Theme state (report, don't guess)
Your last report said the app "renders dark-only (fixed Color.bcPage surface)". **Report clearly:** is Light theme actually implemented, or is the app hard-dark? If hard-dark, the Settings theme switcher (System/Light/Dark) is offering non-functional options → either wire Light properly OR remove the dead options. **Do not ship a Settings toggle that does nothing.** Flag your finding + recommendation before changing behavior.

## PART E — Remove the standalone Language + Currency first screen (CEO-approved, research-backed)
The first-run "pick language + currency" screen is a friction anti-pattern (setup-before-value; research: reach first "win" in 30-90s, don't front-load setup).
- **Auto-detect on first launch:** language from the device locale, currency from the device region (`Locale.current`). Do NOT gate onboarding on a picker.
- **Move both pickers to Settings** (they already exist there — keep them). Optionally surface a one-line "Currency: $ — change in Settings" hint in a coach-mark, not a blocking screen.
- Go straight from launch → brief mascot greeting → coach-marks → first transaction. No language/currency wall.
- If the detected currency is ambiguous, still default silently (device region) rather than blocking; user corrects in Settings.

## Guardrails
- **Localize everything**: every new string keyed in ALL 5 locales (en/ru/es/pt-BR/uk) — no hardcoded strings. Update the locale-parity test.
- **Accessibility**: captions honor Dynamic Type; tap targets ≥44pt; VoiceOver labels on coach-mark targets and the new buttons.
- Do NOT modify the mechanic services (parser/save) beyond routing demo inserts through the existing guarded path.
- No rating prompt in onboarding.
- Build green; commit per unit; push. **Deliver screenshots of every coach-mark step + the new budget CTA + the new Open-form button** (dark).
- Report: files changed, build status, commit hashes, + the Part D theme finding.
