# BRIEF (Claude Code) — v1.0.2 pre-submit fixes from the release review. Model: Sonnet. Branch `main`. Commit per item, build + test before each commit, push. 5-locale parity on any string change.

Items are ordered. #1 and #2 gate the submission; the rest ship in the same release because they're the drift class we've already been burned by.

## 1. [BLOCKER] AddTransactionView.add() — add the gate AND the failed-insert cleanup
`FinanceTracker/Views/AddTransactionView.swift:465-542`. The third entry surface never got the two protections this release standardized elsewhere.
- Add `SaveActionGate` + `isSaving` re-entrancy protection covering **both** Add buttons (`:126` toolbar, `:453` primary) — mirror the `QuickEntryView.swift:1010` pattern exactly, don't invent a variant. Gate the ACTION, content-blind. `reset()` on failure so a deliberate retry lands.
- In the `catch` at `:535`, **delete the inserted `tx`** (`:514`) before surfacing `add.error.save_failed` — mirror `QuickAddSaveService.save:110`. Right now a thrown save leaves a poisoned pending insert in the shared autosaving mainContext: ghost row via `@Query`, every later save re-throws, and the alert invites the retry that stacks the next orphan. This is the cascade documented at `QuickAddSaveService.swift:92-111`, reachable from the full editor.
- Tests: two identical saves from AddTransactionView → two rows; same-tick double-tap → one row; a thrown save leaves **zero** rows and the context clean enough that the next save succeeds (this last one is the regression that matters — assert the recovery, not just the failure).

## 2. [BLOCKER] Tip card must appear from day 1 — it's behind the wrong gate
`FinanceTracker/Views/DashboardView.swift:840-852`, gate at `:815-818`.
`TipOfTheDayCard` sits behind `hasUnlockedInsights` (`daysSince >= 14`). That gate exists for **data maturity** — analytics need history to mean anything. Daily tips are **static content and need no data**, so this is slot reuse, not design. Effect: reveals start at first launch (`FinanceTrackerApp.swift:106`) but the dashboard stays silent for 14 days, then the card debuts alongside a 14-tip back-catalogue — the exact back-catalogue the per-user deck was built to prevent. This is the third time this leak has entered from a new angle (global epoch → orphan-inflated count → now a borrowed gate).
**Decision: the tip card shows from day 1.** Do not delay reveals; do not shorten the gate for analytics.
- If `Day0EducationalCard` genuinely conflicts (the "one teaching card at a time" intent), **report what Day0EducationalCard does and propose the minimal resolution before implementing** — e.g. the daily tip supersedes it once onboarding is complete. Don't stack two teaching cards.
- Test: a fresh install on any real date shows the tip card on day 1 with exactly one revealed tip, and the dashboard card and the hub agree on which tip is today's.

## 3. Derive the trial duration copy — 10 hand-typed strings vs the constant
`paywall.trial_ended.title`, `paywall.preview_active.format` in all 5 locales (`en.lproj/Localizable.strings:854,859` + parity) embed "14-day" while enforcement reads `ReverseTrial.durationDays` (`Purchases/ReverseTrial.swift:39`). `FreeTierLimits`' own header calls these thresholds "a launch guess... expected to move" — when it moves, all 10 strings lie. This is the drift class `PaywallComparison` was built to kill for the caps, and the same class as the hardcoded `$34.99` we already fixed.
- Preferred: pass the duration as a format arg so the copy derives from the constant.
- Minimum acceptable: a test pinning every one of those strings to `ReverseTrial.durationDays`, failing loudly if the constant changes.
- Watch the plural/format traps: don't let a formatter turn 14 days into "2 weeks".

## 4. Fix the stale MARK in the source-of-truth file
`Purchases/FreeTierLimits.swift:82-86` — `proactiveAlerts` still sits under "Premium hooks — NOT built yet... Do not build here". Alerts shipped, are gated, and are **sold on the paywall**. `unshippedCapabilities` is correct (only `.iCloudSync`); only the comment lies — but it lies on the file everything else derives from, and invites a future reader to re-add alerts to `unshippedCapabilities`, which would rip a paid row off the paywall. Correct the comment to reflect what shipped.

## 5. `reports_alltime` — one label speaking for two capabilities
`Purchases/PaywallComparison.swift:87-88` — "All-time PDF & Excel reports" derives only from `.exportPDFAll`; `.exportExcelAll` isn't in `premiumGatesAreListed` at all (whose comment says "the four things money actually buys" while asserting three). Either give Excel its own row, or add a test asserting `.exportPDFAll` and `.exportExcelAll` share a premium flag for as long as one label speaks for both. Fix the comment's count either way.

## 6. `paywall.compare.row.analytics` — the label under-sells the free tier
`en.lproj/Localizable.strings:905` says "Current-month analytics", but `basicAnalytics` is free and **no month-scope gate exists anywhere** — free users get Pulse, Breakdown and the 12-month Horizon. This string is residue from a scope we proposed and then reversed (research falsified gating history/analytics; we de-gated deliberately). Under-promising is the safe direction, but it misrepresents our own free tier, and generous-and-honest free is the positioning. Reword to state what free actually gets, in all 5 locales. Verify against the code, not against this brief.

## 7. `TipRotation.referenceTimeZone` — remove it or correct its comment
`Services/TipRotation.swift:24`, no callers. It documents "the ContentStudio derivation contract" — a contract we **abandoned** when we moved to a per-user shuffled deck (the app no longer has a global "day N"; ContentStudio derives its own schedule independently). So it isn't just dead, it documents a decision we reversed. Delete it, or replace the comment with the truth.

## 8. A guard with no caller is not a guard — pin it
`Shared/ChartGuards.swift:76-78` — `finite(_:)` has only test callers. The header honestly marks it future-proofing, and that's defensible. But this is the **second consecutive release** where a `ChartGuards` member turned out uncalled, and the last one (`dimension`) was written for the exact bug it wasn't wired against — it cost roughly ten rounds of device debugging. Add a test (or a documented exemption list) asserting every `ChartGuards` member either has a production caller or is explicitly listed as intentionally unused. Cheap insurance against a failure mode we've already paid for once.

## Report (≤6 lines per item): what changed, the decision taken on #2 (and Day0EducationalCard's resolution), tests added, build/test, commit per item. Flag anything where the review's reading of the code turns out wrong — verify against the code, don't trust this brief.
