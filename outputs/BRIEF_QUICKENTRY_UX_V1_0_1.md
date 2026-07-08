# BRIEF (Claude Code) — Quick Entry UX polish. Model: Sonnet. Target: v1.0.1 (do NOT destabilize the v1.0 submission).

Two UX fixes on the transaction-entry form (the "third screen" / QuickEntry + AddTransactionView edit path). Both are friction, not bugs — no reject risk. **Do NOT touch save/parser/rollback mechanics.** Build green, commit per item with a conventional prefix, push, before/after screenshots, add/adjust tests. First INSPECT current behavior and report it before changing — don't assume.

## Context (why)
Fast repeat entry and immediate category visibility are our #2 conversion lever ("track in 10 seconds" / simplicity). Current flow adds friction: (a) after Save you're bounced to the Transactions list, so logging several in a row is painful; (b) seeing the full category set requires leaving the form for a separate menu, which reads as non-native.

## Item 1 — "Save & add another"
**Current:** after confirming a transaction, the form dismisses / navigates to the Transactions list. Fine for a single entry, painful for a batch.
**Desired:** keep the fast single-entry path AND enable rapid multi-entry WITHOUT a confirmation modal (a "add another?" dialog after every save is the wrong pattern — it penalizes the common single-entry case).
- Keep the primary **Save** button behaving as today (save + dismiss/navigate).
- Add a secondary **"Save & add another"** action. On tap: run the SAME guarded save path (rollback on failure), then STAY on the entry screen, clear the input fields, reset to a neutral state, and return focus to the amount field so the user can immediately type the next entry. Show the existing success toast.
- Placement: secondary/less-prominent than Save (e.g. a text button or secondary style), so it never competes with the primary action.
- Localize the new label in all 5 locales (en/ru/es/pt-BR/uk); bump string-parity.
- Test: saving via "Save & add another" persists exactly one transaction, clears the form, keeps the screen presented, and focus returns to amount; a failed save still rolls back and does NOT clear/advance.

## Item 2 — Category picker must reveal ALL categories inline (native expectation)
**Current (INSPECT & REPORT FIRST):** under the form there's a category selector showing a subset; the "see all"/expand affordance appears to push to a **separate menu/screen** instead of showing the full set in place. Report exactly what the current control is (chip row + "All" button? a NavigationLink? a separate sheet?) and how it presents.
**Desired:** tapping the category area shows the **full category set immediately, in context**, so the user picks without a mental "where did they go" jump. Preferred implementation, in priority order:
1. **Inline expand** — the chip row expands into a full wrapping grid of all categories right inside the form (tap a category to select + collapse). No navigation. This best matches the "I expect to see them all when I tap" expectation.
2. If inline is impractical given the layout, use a **native bottom sheet** anchored to the field (`.presentationDetents`) that lists all categories — appears in place, not a pushed screen.
Do NOT route category selection through a disconnected separate menu screen.
- Preserve existing behavior: current selection stays highlighted; "Без категории"/uncategorized option still reachable; user-created categories included; auto-detected category still pre-selected.
- Localize any new strings; bump parity.
- Test: from the entry form, opening the category picker surfaces the complete category list in one step, selecting updates the form, and the auto-detected default is still applied when the user doesn't override.

## Report back
1. Current behavior of each control (as found, before changes). 2. Chosen implementation for Item 2 (inline vs sheet) + why. 3. Effort/risk estimate for EACH item separately — flag if Item 2 is cheap+low-risk enough to consider pulling into v1.0, but default assumption is v1.0.1. 4. Files changed, build status, commit hashes, before/after screenshots.
