# Split discoverability — the minimum that makes the pre-test honest

**Date:** 2026-08-03 · **Status:** proposal, nothing built
**Blocks:** 1.0.4 submission (see `DECISION_RECEIPT_INPUT_PRETEST.md` §3, T0 rule)
**Constraint accepted:** do not redesign the split editor. Do not add a second category picker.

---

## 1. What is actually wrong (verified, not assumed)

The independent confirmation in the brief is right, and there is a sharper way to
say it than "it takes four steps".

`TransactionDetailView.swift:37`:

```swift
if CategoryAttribution.isSplit(tx) {
    Section("tx_detail.section.split") { … }
}
```

**The affordance is conditional on having already used the feature.** The split
section appears only on transactions that are already split. A user who has never
split a purchase encounters no evidence anywhere — not on the entry screen, not on
the transaction, not in the list — that splitting exists at all. The only surface
that mentions it is inside the Edit sheet, below the fold.

That is not a discoverability *weakness*. It is a feature that is, for practical
purposes, invisible to everyone who has not already found it. Which is exactly the
population the pre-test needs to measure.

Two further facts that shape the fix:

- `EditTransactionView.swift:169` already routes split category picks through
  `CategoryPickerSheet`. **Anything that reuses the Edit sheet inherits correct
  picker routing for free** and cannot violate the CLAUDE.md rule by construction.
- All the copy already exists and is localized ×5: `split.section`,
  `split.add_part`, `split.hint`, `tx_detail.section.split`.

---

## 2. The proposal — two changes, both small

### Change A — the fix. Make the split section unconditional on the detail view.

`TransactionDetailView.swift`: turn the `if` into an `if / else`. When the
transaction is *not* split, render the same section with one tappable row instead
of the breakdown.

```swift
if CategoryAttribution.isSplit(tx) {
    Section("tx_detail.section.split") { … existing breakdown, unchanged … }
} else {
    // The split affordance used to appear only on already-split transactions,
    // i.e. only to users who had already found it. This row is the entry point
    // for everyone else; it opens the same editor, which owns the real UI.
    Section {
        Button { showEdit = true } label: {
            Label("split.add_part", systemImage: "square.split.2x1")
        }
    } header: {
        Text("split.section")
    } footer: {
        Text("split.hint")   // "One purchase, several categories — …"
    }
}
```

Cost: ~12 lines, one existing sheet, **zero new strings**, zero new state, zero
new pickers. `showEdit` and the `.sheet` are already there at lines 13 and 66.

**Optional refinement, and it is a real decision, not a detail.** Have the button
open Edit with one empty split row pre-seeded, so the user lands on a populated
Split section rather than having to find "Add a part" again. This needs one new
parameter on `EditTransactionView` (`startSplitting: Bool = false` seeding
`splitDrafts = [SplitDraft()]`). The trade-off: a seeded empty row makes Save
briefly invalid with `split.incomplete_row`, which is correct feedback for someone
who asked to split, but is a state the editor does not currently open in.
**Recommend taking it** — without it the user is handed the same scroll-and-hunt
problem one screen later, which is most of what we are trying to fix. Flagging it
because it is the only part of this proposal that touches the editor at all.

### Change B — the pointer. Name the feature where the user is entering data.

`AddTransactionView.swift`: one footer line under the category row.

```
"add.category.split_hint" = "Bought several things? Save it, then open it to split across categories.";
```

One new key, ×5 locales (locale baseline 759 → 764). No new UI, no new state, no
new control. This is deliberately a **pointer, not a control**.

---

## 3. Why this is sufficient — and precisely where it is not

The bar set in the brief: *a user who wants to split can find it without knowing
it exists.* Test the proposal against that literally.

- **Does the user learn the feature exists?** Yes — Change B, at the moment they
  are categorising a purchase that has more than one category in it. That is the
  moment the thought occurs.
- **Can they act on it without knowing where to look?** Yes — Change A. From the
  Transactions list, tapping the transaction is one tap they already know how to
  make, and the split entry point is then visible on screen, not hidden behind
  Edit → scroll.
- **Does it require knowing the feature exists beforehand?** No. That is the whole
  change: the affordance is now visible to people who have never split.

**Where it falls short, stated rather than glossed.** This does not put splitting
on the entry surface, which is what §2(a) of the pre-test asks for. A user who
would have split *in the moment* but never reopens the transaction is still
uncounted. So the measured rate stays biased downward relative to a true (a)
implementation. I have recorded this in the pre-test as a new, explicitly weaker
clause (c) with the residual bias named, rather than stretching (a) to fit —
`DECISION_RECEIPT_INPUT_PRETEST.md` §2.1.

**Why not go further and satisfy (a) properly?** Splitting on the entry surface
means the amount is still being typed and can change under the split rows, which
is the validation problem (`split.over_sum`) that made the editor the natural home
in the first place. That is a redesign of the split editor, which the brief ruled
out, and correctly — it would be a large change landing on the critical path of a
release that is already carrying a schema migration and sync.

---

## 4. Why not the post-save prompt

The brief's instinct was "an entry point from the Add flow after save, **or** on
the transaction detail view". Having read both surfaces: **take the second, not
the first.** Three reasons, in increasing order of seriousness.

1. `AddTransactionView` has no post-save surface to attach to. It calls
   `dismiss()` immediately (line 555). There is no toast, no confirmation, no
   undo bar. A post-save prompt is not an addition to an existing moment — it
   would be a new moment, with new state that has to survive the dismiss and be
   owned by the parent.
2. Line 554, immediately before the dismiss, is
   `RatingPromptCoordinator.recordTransactionSaved()`. The StoreKit rating prompt
   fires on the 5th save and is an **out-of-process window that swallows taps**
   (documented, it previously broke the UI suite). Introducing a second
   post-save interruption that races with it is asking for a bug that reproduces
   only on every fifth transaction.
3. It is worse *as design*. A prompt after save interrupts a flow the user has
   just deliberately completed, to offer something most users do not want on most
   transactions. The detail-view row is available to anyone who looks and costs
   nothing to everyone who does not.

Change B keeps the useful half of the instinct — the Add flow *mentions* it — at
the cost of one string.

---

## 5. What this does not do

- Does not touch `EditTransactionView`'s split UI, validation, or
  `CategoryAttribution` maths.
- Does not add a category picker. Reuses `CategoryPickerSheet` transitively via
  the existing editor (`EditTransactionView.swift:169`).
- Does not change what the usage instrument counts. `UsageSummaryBuilder.swift:197`
  still counts `TransactionSplit` rows; the pre-test's numbers stay comparable in
  definition. Only their honesty changes.
- Does not touch Quick Entry.

---

## 6. Verification before this counts as shipped

- `xcodebuild … build` green (CLAUDE.md, before commit).
- Locale parity: `LocaleCompletenessTests` baseline 759 → 764 across all five
  `.lproj`.
- One manual pass on device: a fresh transaction, from the Transactions list,
  splittable without opening Edit from the toolbar.
- Then, at 1.0.4 availability, record in `DECISION_RECEIPT_INPUT_PRETEST.md` §3:
  `Precondition met by version = 1.0.4 · clause (c)`.
