# BRIEF (Claude Code) — v1.0.2: replace global seen-only with a PER-USER "collection under lock". Model: Sonnet. Skills: apple-hig-expert. Do on the v1.0.2 branch, commit + push, build + test before commit, 5-locale parity, no CLAUDE.md anti-patterns.

## Why this supersedes 1b6c5be
The seen-only hub you just shipped derives "seen" from a **global fixed epoch (2026-01-01)**: today's day-index is ~195, so a NEW user sees the entire back-catalogue the instant they install — the surprise the feature exists to protect is gone for exactly the users we care about. Fix = make reveal **per-user**, driven by the user's own usage, with an explicitly persisted seen-set. This replaces the global-index `seenTips` logic in `TipLibrary.swift`.

## The model — per-user shuffled deck + persisted seen-set
1. **Per-device shuffle seed.** On first launch, generate and persist a stable seed (e.g. `@AppStorage("tipDeckSeed")` = a random UInt64/UUID). The "deck" = the tip library deterministically shuffled by that seed. Order is stable across launches, unknown to the user (= real surprise), and independent of the install date.
2. **Persist the SEEN SET explicitly** — `@AppStorage`/SwiftData Set<String> of revealed tip `id`s (not an index). This is the source of truth for the collection.
3. **Reveal cadence: at most ONE new tip per calendar day.** On launch, if the current calendar day differs from the last-reveal day AND unseen tips remain in deck order, reveal the next unseen deck entry → add its `id` to the seen set, store today as last-reveal day. That newly-revealed tip is **today's hero**. No backlog catch-up: skipping 5 days reveals ONE on return, not five (preserves the one-a-day ritual, never dumps).
4. **Today's tip** = the most recently revealed id. If the deck is exhausted (all seen), the collection is complete — rotate the hero through the full set (deck order) so there's still a daily tip; nothing new to unlock.

## Collection view (the hub)
- Lists ONLY tips in the seen set, most-recent first. Search scoped to seen.
- Unseen tips appear as **locked rows** (lock glyph, no term/text revealed) OR a single "X of Y unlocked — one more each day" line — your call per HIG; do NOT reveal unseen content. Future set is not browsable.
- Day-1 state: only today's tip is unlocked; show it as hero + the "more each day" line. Must not crash at 1 seen.
- Keep the eight help articles always visible (reference, unaffected).

## Library growth is now SAFE (important)
Because "seen" is a persisted id-set, **growing the library later cannot corrupt the collection**: new tips are simply unseen ids appended to the deck (shuffle the unseen tail with the same seed), revealed on subsequent days. This removes the old "mid-cycle growth remaps the sequence" limitation — we can extend the library post-launch without disturbing anyone's collection or re-showing old tips. Note this in the code comment.

## Edge cases to handle
- Clock moved backward or forward: the seen set only ever GROWS; reveal at most one per real calendar day; a forward clock jump does not dump multiple.
- Fresh install / simulator: seed + start work deterministically; no network.
- Empty/1-item seen set: no crash, no divide-by-zero on deck position.

## Quiz — NOT in this brief (fast-follow)
We will add a quiz over UNLOCKED tips in a later pass. Don't build it now, but don't design the collection in a way that blocks it (the persisted seen-set is exactly what the quiz will draw from).

## Social-calendar note (no code)
The app no longer has a global "day N", so it will not match a single ContentStudio social-post day. That's intended and already decided — ContentStudio derives its own schedule from the same `tips.json` by the fixed epoch. No cross-dependency.

## Tests
- Deck order is stable for a fixed seed; different seeds → different order.
- Seen set only grows; at most one reveal per calendar day (advance a mock clock day-by-day: day 1 → 1 seen, day 3 → 3 seen; jump +5 days → +1 seen, not +5).
- New user on any real calendar date sees exactly ONE tip on first launch (the regression that proves the global-epoch bug is gone).
- Collection lists only seen ids; unseen never leak term/text into the view or search.
- Adding N tips to the library leaves existing seen ids intact and does not re-reveal an already-seen tip.
- 5-locale parity unchanged (id-keyed).

## Report (≤6 lines): the per-user reveal model + how "seen" is persisted, the new-user-sees-one proof, library-growth safety, files, build/test, commit. Device-verify: fresh install shows one tip today; collection shows only that; unseen are locked; next day adds exactly one.
