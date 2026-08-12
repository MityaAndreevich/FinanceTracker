# FABLE TASK — IMPLEMENT the full 1.0.3 to a submittable state. Now you write code. Branch `main`, commit per logical unit with conventional prefixes, build before every commit, push. Read ARCHITECTURE.md + CLAUDE.md first.

You designed this: outputs/DESIGN_1_0_3_MODELS_FABLE.md (§1–§13). Implement it end to end. Do NOT re-litigate the design; if you find a design error, fix it and say so in the report.

## Build order (from your §13 — the one hard constraint: canaries exist BEFORE the schema they guard)
1. **Canary tests first** (§8, §12): the 7 double-count detectors + the split-sum invariant + `donutSliceSum == monthExpenseTotal` + `entries.count == transactionCount`. Plus the two extractions (MonthTotals, AnalyticsSeries) so canaries pin production formulas, not copies. They will fail until the code exists — that's correct.
2. **Relationship fixes** (§1): Transaction.category → optional with inverse; Transaction.source inverse on Source.transactions; remove all `.unique` (move uniqueness to write sites — the importer already fetches-by-uuid); MerchantCategoryLearning → local-only ModelConfiguration.
3. **V2 schema + migration** (§7, §10): the VersionedSchema bump, the `didMigrate` dangling-ref repair (nullify, never delete; no-op on clean; idempotent; one atomic save), SharedModelContainer's fatalError → recoverable throw, the rollback ladder, the two-key attempt sentinel.
4. **Backup + safety UI** (§9, §10): the immutable pre-migration backup (all 3 store files + manifest into AppGroup/Backups/pre-v2, before any store open), the first-launch export-your-data screen (reuse CSVExportService via a throwaway read-only V1 container; bypass the premium all-time gate for this surface; shown-until-resolved, NO separate "seen" flag), the widget/AppIntents hard gate on `v2MigrationComplete`, the full-screen must-acknowledge restore notice with live post-restore transaction count.
5. **Split transaction** (§2, §3): TransactionSplit child entity, `.cascade`, remainder invariant. Route ALL category math through `CategoryAttribution.rows` — change exactly the 12 paths listed, leave the 7 untouched (the canaries from step 1 guard this). ⚠️ **Prevent over-sum in the UI** (Σ splits > total must be impossible to create — Fable's design excluded it from the mirror but did not prevent it; you must).
6. **Category limits** (§6): Category.limitCents optional, threshold constant `CategoryLimitPolicy.warnThresholdFraction = 0.70`, spent-so-far over CategoryAttribution.rows, wire the gain-framed "X left" alert into the existing proactive-alert refresher with the per-category-per-month latch. Never "exceeded".
7. **Daily allowance** (Velocity Dashboard) + **pace/forecast**: per-day safe-to-spend as the dominant large title, monthly budget as a non-numeric donut, muted mint never alarm red. Pace = sum(month)/dayOfMonth × daysInMonth vs the stored budget. Gain-framed. No new heavy model. 5 locales.
8. **Feedback mail composer**: Settings "Tell me what's missing" → MFMailComposeViewController pre-filled with app version + locale + device model, NO personal/financial data; copy-address fallback if mail unconfigured. 5 locales.
9. **Metadata prep** (do NOT submit): apply the description change from outputs/DESCRIPTION_TRIAL_FIX_5_LOCALES.md is a MANUAL App Store Connect step — just leave a note in the report reminding the founder. Do not touch pricing/offers.

## Two small gaps to close (Sonnet-level, but you're building, so do them)
- What the **widget shows while the `v2MigrationComplete` gate is closed**: a safe placeholder / last-known snapshot, never blank-forever, never a crash.
- If the **backup write itself fails** (disk full, etc.): DO NOT proceed to migration — surface a message and halt. A failed backup must never silently allow the migration.

## Token discipline (§12)
WRITE only: the lie-detector tests above (canaries + invariant + no-op + repair + rollback-restore). DO NOT WRITE: UI permutation matrices, idempotency ceremony, trivial-getter pins. Targeted `-only-testing:` runs, never suite-wide. Version bump to 1.0.3 / build 6 across app + widget targets (test targets untouched).

## 🔴 THE GATE — what "done" means (this is NOT "tests are green")
Bump the version, build, and get it to a state where the founder's ONLY remaining actions are: (a) run the §11 TestFlight verification — migrate on the built binary, run the `--fail-migration` drill through the rollback ladder to a good restore, and the six-item eyeball checklist (totals to the cent, count unchanged, full-list scroll, a known split, merchant-learning survival, backup lifecycle); and (b) press Submit. **Do NOT archive or submit.** Real data doesn't exist yet, but the migration + rollback MUST be proven on a TestFlight build before submission — say so explicitly in your report.

## Report (tight): what you built per item, any design error you fixed, the canary results, the two gap fixes, build status, commits, and a crisp "founder's remaining steps: TestFlight §11 drill, then Submit."
