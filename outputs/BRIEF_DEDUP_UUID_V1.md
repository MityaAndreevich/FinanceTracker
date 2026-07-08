# BRIEF (Claude Code) — UUID-based import dedup (replace content+day heuristic). Model: Sonnet + systematic-debugging.

Follow-up to the CSV dedup (0be9f4d). The current identity `type|amountCents|currency|dayKey|category|merchant` is fragile: **two genuinely-distinct identical transactions on the same day get falsely merged on import.** That's wrong for a finance app. Fix with a stable per-transaction UUID. Do NOT touch save/parser mechanics. Build green, commit per unit, push.

## Token discipline (standing rule)
Sonnet. Grep-first to find the Transaction model + CSV writer/reader; Read only those. **Targeted tests only** (listed below). NO suite-wide runs, NO UI-presentation tests.

## Step 0 — Scout (report before/while implementing)
Check whether the Transaction SwiftData model already has a **stable, app-owned UUID** attribute (e.g. `id: UUID` generated at creation) — NOT `persistentModelID` (that is NOT stable across delete+reinsert, so it's useless for round-tripping). Report which exists.

**Decision rule (act, don't wait):** the app is **pre-launch — there is no production data** (only test data wiped on clean reinstall), so adding a `UUID` attribute is low-risk: no real migration burden, default `= UUID()` on the property, generate for any legacy test rows on access. Unless you find a genuine blocker, proceed and implement in v1.0. Only stop and report if the change requires a risky, non-lightweight migration.

## Implement
1. **Model:** ensure Transaction has a stable `id: UUID` (default `UUID()`), assigned at creation, persisted.
2. **Export (CSV writer):**
   - Add an **`id` column** (UUID) to the schema. Also change the date column to an **exact timestamp** (ISO-8601 with time, locale-invariant), not day-only — keep amount locale-invariant per 16f8b75.
   - Document the new column order; writer + reader share it. Keep it readable in Excel (id can be first or last column).
3. **Reader:** parse `id` + timestamp. Must still import **legacy/foreign CSVs that have no `id` column** (fall back to heuristic — don't hard-require the column).
4. **Dedup logic:**
   - Row **has a UUID that matches an existing tx** → same row → **skip** (idempotent re-import of our own export).
   - Row **has a UUID not present** → new → import.
   - Row **has NO UUID** (foreign CSV) → **import it; never silently drop.** If it matches the heuristic (type|amount|currency|exact-timestamp|name) against existing data, **flag it as a possible duplicate** and count it in the summary (`possibleDuplicates`), but keep the transaction. Finance rule: a visible duplicate is recoverable; a silently-dropped real transaction is not.
   - Keep the existing `importAll` override and the localized summary; add the `possibleDuplicates` count string (all 5 lproj, bump parity).

## Tests (targeted only)
- **Idempotent re-import:** create 3 tx → export → import our own file into the SAME store → assert 0 new rows (all UUID-matched/skipped).
- **No false merge (the reported bug):** create TWO distinct tx with identical type/amount/currency/day/category/name but different UUIDs → export → import into an EMPTY store → assert **both** survive (2 rows), not merged.
- **Foreign CSV (no id column):** import a file with a content-matching row and no `id` → assert the row is imported (not dropped) and reported under `possibleDuplicates`.
- Run the round-trip under **ru_RU** (keeps the separator fix honest).

## Report
Whether a stable UUID already existed or was added; the new column schema; effort; v1.0 vs v1.0.1 recommendation (default v1.0 since pre-launch). Files changed, build status, commit hashes, test output.
