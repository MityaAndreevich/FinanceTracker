# BRIEF (Claude Code) — Device-QA fixes, round 2 (Transactions/search). Model: Sonnet + systematic-debugging.

Device QA: on the Transactions tab the list showed the empty state ("Транзакций пока нет / Add your first") while the Dashboard showed all the same transactions (donut + Recent). Data is NOT lost (on disk, Dashboard proves it) — it's a Transactions view/query/filter bug. Also search sometimes doesn't react. Both are pre-submit (a "my transactions vanished" impression tanks ratings). Build green, commit per item, push, before/after screenshots. Do NOT touch save/parser mechanics.

## 1. CONFIRMED cause (a) — stale search + misleading empty-state (NOT a query bug)
Device confirm: tapping ✕ to clear the search **restored the full list** → the data/query are fine; the list was empty only because a stale search ("Футболка 550") matched nothing. Skip any @Query/predicate investigation. Fix = #2 (honest empty-state) + #3 (search clear + semantics):
- **Don't let a stale search text survive** in a way that silently hides everything — clear the search field on tab switch / when leaving Transactions, OR at minimum surface the active-search state clearly so it never reads as "no data."

## 2. Empty-state copy must distinguish "no results" from "no data" (HIGH, cheap)
When transactions EXIST but are hidden by a search or filter, the empty view must say **"Ничего не найдено / No results"** (with a "Clear search/filters" affordance) — NOT "Транзакций пока нет / Add your first" (which reads as data loss). Only show the true empty state when there really are zero transactions in scope. Localize both strings in all 5 locales; bump parity.

## 3. Search responsiveness + semantics
- Search "sometimes doesn't react" — fix the binding/debounce so typing filters the list live and reliably.
- Semantics: match by **merchant/name**, case-insensitive, partial/substring, ideally token-wise so "Футболка" matches the "Футболка" row. Decide + document whether the amount is searchable; a query like "Футболка 550" should at least match on the name token "Футболка" (don't require the whole string to be a substring). If nothing matches → show the #2 "No results" state.

## 4. Editing a transaction is BROKEN — tap does NOT open the editor at all (HIGH, functional) — systematic-debugging
**Device-confirmed narrowing:** tapping a transaction row on the Transactions screen does **nothing — the editor never opens.** So this is the row's **tap/navigation/sheet binding**, NOT a save-persist issue. Likely regressed in the recent Transactions refactor (search extraction, 3-way empty-state, `.onDisappear` search-clear).
Check, in order: (a) the row's `NavigationLink` / `.onTapGesture` / `sheet(item: $editTx)` binding — is `editTx` still being set on tap and does the sheet/nav still present? (b) is an overlay eating the tap — the InlineHintBubble/period-hint, a coach-mark layer, or a full-row `.swipeActions`/gesture that swallows the tap? (c) did the search/empty-state wrapper change the view hierarchy so the tap target is no longer hit-testable?
Fix so tapping a row opens the editor (AddTransactionView in edit mode); ensure the edit Save still routes through the guarded save path (rollback on failure). Add a UI/logic test that a row tap presents the editor AND that editing an amount persists + refreshes the list. Report the exact cause.

## 5. Purchase-success message shows in ENGLISH while app is RU
Device (RU): after tapping subscribe, an alert "You're all set. / Your purchase was successful. [Environment: Xcode]" appears in English.
- **`[Environment: Xcode]` = Apple's StoreKit LOCAL-TEST sheet** (only with a local `.storekit` config in Xcode); it's English-only in the test harness and does NOT ship — in Sandbox/App Store the SYSTEM purchase sheet is localized. First confirm whether this alert is that StoreKit test sheet OR the app's own success UI.
- If it's the **app's own** post-purchase confirmation/entitlement text → **localize it in all 5 locales** (en/ru/es/pt-BR/uk); grep for the "You're all set"/"purchase was successful" strings and route through Localizable.strings. Bump parity.
- Verify the real flow in **Sandbox** (real sandbox Apple ID, StoreKit config OFF) shows a localized system sheet. Report which case it was.

## 6. "Invalid frame dimension (negative or non-finite)" + main-thread Core Data I/O (note)
- Investigate the recurring `Invalid frame dimension (negative or non-finite)` — a view is getting a negative/NaN width/height (likely a progress bar / donut / safe-to-spend ring computing a width from a zero or negative value). Guard the computation (clamp ≥0, guard against divide-by-zero). Small but it can glitch layout.
- The `-[NSManagedObjectContext performBlockAndWait:]` / `sqlite3_*` main-thread warnings are **suppressable performance diagnostics, not crashes** — do NOT do a big ModelActor refactor now. Only ensure launch-time reads are deferred/off-main (covered in ROUND1 #1). Broader main-thread-I/O → v1.0.1 perf pass. Report if any screen visibly hangs.

## Report
For #1: the identified cause (a or b), the fix, the new test. For #2/#3: the copy keys added + confirm live search works and the correct empty-state shows.
