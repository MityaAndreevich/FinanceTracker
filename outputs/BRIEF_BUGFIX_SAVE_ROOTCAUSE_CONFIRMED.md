# BRIEF (Claude Code) — DEFINITIVE save-bug fix (root cause CONFIRMED)

Paste into Claude Code. **Restart CC first (superpowers active).** Model: **Opus** (SwiftData schema + delete-rule + context recovery). Use `systematic-debugging` + `test-driven-development`.

## ✅ Root cause captured on device (2026-07-04)
```
Error Domain=NSCocoaErrorDomain Code=1600 "Items cannot be deleted from %{PROPERTY}@."
NSValidationErrorKey = category
origin: [TransactionResetService.reset]  → then every subsequent QuickAddSave #1..#N re-throws the SAME error for Transaction p1
```
**Code 1600 = NSValidationRelationshipDeniedDeleteError.** The `category` relationship has a **`.deny` delete rule** (or a wrong inverse), so deleting a Transaction that points at the primary "Other"/Uncategorized Category (uuid `BE58ABAA-A80B-4DC7-BE87-357F0C46D934`) is DENIED. Reset's `save()` throws, and the un-committable **pending delete stays in the long-lived mainContext** → poisons every later save (same Transaction p1 in all 16 failures). Confirmed: the bug only appears **after Reset Transactions**; a fresh state saves fine (that's why an earlier run looked clean).
Note: the existing anti-poison guard discards failed **inserts** — it can't clear a denied **delete**, so it doesn't help here.

## Fix (data layer — do this, in order)
### 1. Correct the delete rule on the Transaction↔Category relationship
> Research confirm (NotebookLM de492776): `.nullify` is correct for BOTH sides of Transaction↔Category (deleting a Category leaves transactions uncategorized; deleting a Transaction never deletes a Category). **`.cascade` on Category would mass-delete financial records — avoid.** Critically: **if CloudKit sync is enabled, `.deny` is STRICTLY UNSUPPORTED and breaks sync** — and we plan iCloud Sync (v1.0.1), so `.deny` must go regardless of the crash. Use launch arg `-com.apple.CoreData.MigrationDebug 1` to verify the lightweight migration when changing the rule.
- Find the `@Model` for `Transaction` and `Category` and their `@Relationship` for `category` / `transactions` (grep `@Relationship`, `deleteRule`, `category`).
- Transaction's `category` to-one must NOT deny the transaction's own deletion. Set it so deleting a Transaction is allowed:
  - `Transaction.category`: delete rule **`.nullify`** (default) — NOT `.deny`.
  - `Category.transactions` (inverse, to-many): delete rule **`.nullify`** (deleting a category detaches its transactions) or `.cascade` only if that's the intended product behavior — but the immediate bug is the deny on the transaction side. Do NOT use `.deny` on the path Reset walks.
- If a SwiftData schema change requires a migration, handle it (lightweight migration / version the schema). Verify the app still opens an existing store.

### 2. Make Reset (and every save path) recover from a failed save
- In `TransactionResetService.reset` (and any catch around `modelContext.save()`), on failure call **`modelContext.rollback()`** to discard the un-committable pending changes so the context is never left poisoned. (Even with the rule fixed, this is the safety net that stops one bad save from cascading.)
- Prefer deleting via a clean approach that respects rules — e.g. fetch all Transactions and `context.delete(_:)` each, then a single `save()`; if it throws, `rollback()` and surface the error.

### 3. Prove it with a test that mirrors the REAL flow (must fail before, pass after)
- The existing in-memory tests pass while the device fails — so add a test on a **temporary on-disk ModelContainer** (not `isStoredInMemoryOnly`) that reproduces the delete-rule path:
  1. Seed the primary "Other" category + one Transaction assigned to it.
  2. Run `TransactionResetService.reset`.
  3. Assert reset **succeeds** (no throw) AND the context has no lingering pending changes (`modelContext.hasChanges == false` / a fresh fetch returns 0 transactions).
  4. Then do one quick-add save → assert it succeeds and exactly ONE transaction exists.
- This test MUST fail on the current code (1600) and pass after the fix.

## 4. Error toast is styled as SUCCESS on the Dashboard (fix — device-confirmed)
Screenshots show the Dashboard save-failure toast rendered with the **success style: green background + checkmark ✓**, while the text says "Couldn't save your transaction. Please try again." The **"+"-sheet version renders it correctly** (red/coral background + ⚠️). So the Dashboard toast ignores the result type.
- Drive the toast style from the actual result: **failure → error style (coral/red + warning icon), success → green + check.** Find the Dashboard toast/banner call on the quick-add save path (grep the localized key for "Couldn't save"/"try again") and pass the correct severity/type instead of a hardcoded success style. Reuse the same styled component the "+" sheet uses so both paths match.
- (Once the root-cause fix lands, this failure toast should stop appearing at all — but the styling bug must still be fixed so any future error shows correctly.)

## Secondary (note, don't let it block)
- Log storm shows **main-thread Core Data I/O** ("performBlockAndWait", sqlite3_step on main) → can cause hangs and likely contributed to the earlier **memory-termination (code 9)** via the failed-save retry loop. After the root fix, verify the retry loop is gone (no repeated `QuickAddSave #N` on a single user tap). If heavy reads remain on the main thread, move them to a `ModelActor` (per our architecture rule) — but only after the 1600 fix lands.
- Category auto-detect (assigns "Other" instead of Food for "coffee") is a SEPARATE issue — handle via BRIEF_QUICKENTRY_FIX_V2, not here.

## Guardrails
- Build green; commit per fix; push. Report: the exact @Relationship change (before/after), the rollback addition, and the new failing→passing on-disk test output.
- Do NOT touch amount/name parsing. Keep changes scoped to the relationship delete rule + reset/save recovery + the test.
