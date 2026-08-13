# Is `Category.isPrimary` a dead field? — decide before V3 is written

**Date:** 2026-08-13 · **Verdict: NO. It is live, and it must ride into V3.**
**Nothing was deleted.** Removing a model field is a schema change and 1.0.5 has none.

---

## The answer, in call sites

The question was *"is `isPrimary` read by anything at all, or is it set, seeded, documented and
consumed by nothing?"* It is consumed, at **four** live sites, two of which are user-visible.

| # | Site | What it does | User-visible? |
|---|---|---|---|
| 1 | `QuickEntryView.swift:387–388` | Selects and orders the ≤6 quick-category chips: `primary` first, back-filled with the rest | **Yes** — the main entry surface |
| 2 | `CategoriesSourcesView.swift:458` | `Toggle("cs.category.shown_by_default", isOn: $category.isPrimary)` — a **writable** control | **Yes** — users set it |
| 3 | `CategoryEntity.swift:63` | `defaultResult()` — the default category for Siri / Shortcuts | Yes, via Siri |
| 4 | `CategoryEntity.swift:75` | `sortedEntities` — primary-first ordering in Siri disambiguation | Yes, via Siri |

Plus written/persisted at `Category.swift:40,77`, `SeedService.swift:84,110`, `DemoSeeder.swift:324`,
`FinanceTrackerSchemaV1.swift:99,118`, and surfaced on the entity at `CategoryEntity.swift:31`.

**Site 2 is decisive on its own.** The field is not merely read — it is *written by the user* through
a shipped toggle. Dropping it from V3 would silently discard a preference people have already set.

---

## What actually died was the meaning, not the field

The brief counted four artefacts around this field. It was right that they describe a removed
control; it was the *inference* from that — that the field went with it — that does not hold.

`isPrimary` **was** a visibility flag for the two-step picker. When `CategoryPickerSheet` became the
single shared picker for both entry surfaces, the picker stopped filtering on it:

```
CategoryPickerSheet.swift:35–38   filters on kindRaw + search text only
```

So the field **survived the removal with a new job** — ranking — while every sentence describing it
kept the old one. That is why the wreckage looked like a dead field: four artefacts describing a
control that does not exist, attached to a flag that very much does.

**`isPrimary = false` does not hide a category anywhere.** It stays in the picker, searchable and
selectable. It only loses a quick-chip slot and the Siri default.

**Corrected in this pass (comment/copy only, no schema change):** `Category.swift:38`,
`SeedService.swift:65`, `DemoSeeder.swift:307`, and the live string `cs.category.secondary_label`
in all five locales — which shipped *"Under "Show all""* to users and is the subject of brief item 1.

---

## Consequence for the V3 / CloudKit freeze

**Keep it.** The eight-field freeze was disciplined about not paying for dead columns forever, and
that discipline is exactly why this was worth checking — but the check comes back negative. A
CloudKit production schema is additive-forever, so the asymmetry is:

- Freezing a **live** field: correct, costs nothing.
- Freezing a **dead** field: a permanent tax — the thing the freeze exists to avoid.
- Dropping a **live** field: silently discards a user-set preference, breaks the Quick Entry chip
  row and the Siri default, and cannot be undone additively.

The last is by far the worst outcome, and it is the one that a "four stale artefacts ⇒ dead field"
reading would have produced.

**One thing to carry into the V3 design rather than assume:** `isPrimary` defaults to `true`
(`Category.swift:40`). Under sync, a category created on a device that never touched the toggle
arrives as primary, and the ≤6 chip row is a *ranked* selection — so two devices with different
category sets can legitimately show different chips. That is a merge-semantics question for the sync
design, not a reason to change the field now.

---

## Method

Call sites were enumerated, not inferred: every `isPrimary` occurrence across the app, widget and
shared targets was read in place. `CategoryPickerSheet` was read specifically to confirm the negative
— that nothing filters on the flag — since that is the claim the old comments made.

Test-only references (`AddTransactionCategoryPickerTests`, `CategoryEntityTests`) were **excluded**
from the live-site count on purpose: per the reachability sweep filed the same day, a test reference
is not evidence that the app reaches the code.
