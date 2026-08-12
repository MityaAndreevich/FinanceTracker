# BRIEF (Claude Code) — v1.0.2 Import: surface the possible-duplicate flag + review/resolve. Model: Sonnet + TDD. Skills: apple-hig-expert, swiftui-design-skill.

**v1.0.2 branch (1.0.1 is frozen/submitted — do NOT touch its release; this is the next cycle).** `main`, commit per unit, push, `xcodebuild … build` + test before commit. Localize new strings in all 5 locales. No CLAUDE.md anti-patterns.

## Problem (device-observed)
Re-importing the same foreign CSV (Mint/bank, no UUID) creates duplicate transactions. Per our design this is correct — foreign rows are **flagged, not dropped** (we can't be sure it's a dup vs two identical real spends). BUT the flag currently lives only in the import-summary count. **On the transaction itself there is no badge/marker**, so the user can't find or resolve the possible dups. That's the gap.

## Step 0 — report the current state first (grep, don't assume)
Find: how the importer records the possible-dup decision (the dedup identity = type|amountCents|currency|dayKey|category|merchant), where that flag is stored (is it persisted on the Transaction model or only counted in the summary?), the Transactions list view, the Transaction model. Report what exists before changing anything.

## Item 1 — Persist + surface the possible-duplicate flag
- Ensure the "possible duplicate" decision is **persisted on the imported Transaction** (a boolean like `isPossibleDuplicate`, defaulted false; additive, migration-safe). If it's currently only a summary count, add the stored flag.
- **Show a visible badge** on flagged transactions in the Transactions list (a small icon + accessible label "Possible duplicate", localized; calm, not alarm-red). Icon+label, not color-only.

## Item 2 — A review/resolve flow
- Give the user a way to act on flagged rows: a filter or a top-of-list banner "N possible duplicates — review", opening a list of the flagged transactions with **Keep** / **Delete** per row (and a "keep all"/"delete all"). Deleting is a normal delete (no hard-delete/permission issues). Clearing the flag (Keep) unsets `isPossibleDuplicate`.
- Keep it simple; don't build an auto-merge engine. The honest position: we flag, the user decides.

## Item 3 — Verify own-export re-import truly dedupes (regression)
- Re-importing OUR OWN exported CSV (which carries the stable UUID) must **not** create duplicates (UUID exact match = idempotent). Confirm this still holds; add/keep a test. Only foreign (no-UUID) rows should ever be flagged.

## Tests (targeted, TDD)
- Foreign file re-import → flagged rows get `isPossibleDuplicate = true`, both kept (not dropped), summary count == badge count.
- Own-export re-import (with UUID) → zero new rows, zero flags.
- Keep clears the flag; Delete removes the row; counts update.
- Badge renders with icon+label (not hue-only); 5-locale parity for new strings.

## Report (≤6 lines/item): current-state finding, where the flag is now persisted, the badge + review flow, files, build/test status, commit per item. Device-verify: import test_import_mint.csv twice → flagged rows show the badge; review flow lets you delete the dups; re-importing an own-export CSV creates no dupes.
