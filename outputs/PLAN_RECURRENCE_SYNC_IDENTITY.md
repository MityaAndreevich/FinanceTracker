# PLAN — recurrence identity under sync (1.0.4)

**Owner doc.** Steps, status, and decided answers live here, not in a chat log.
A previous session's step list existed only in conversation and was lost; every
step below updates this file **in the same commit as its code**. That is the fix
for the class of problem, not just for that instance.

**Related:** `DESIGN_ICLOUD_SYNC_1_0_4.md` (Doc 1) · `DESIGN_AUTOPOST_RECURRENCE_1_0_4.md`
(Doc 2) · `AUDIT_UUID_UNIQUENESS_SYNC_1_0_4.md` (the `uuid ==` audit).

---

## The bug this plan exists for

A recurring series is a normal ledger row with `recurrenceRaw` set — the template
**is** the series' first ledger row. Turning on iCloud sync breaks it two ways at
once, and both end in the user being charged twice:

| # | mechanism | route |
|---|---|---|
| A | `dueRecurring` fetches on `recurrenceRaw != nil`, so it counts **rows**, not series. A first-sync union gives one series two rows sharing a uuid ⇒ two prompts in one sitting. | **fixed, step 2** |
| B | The period watermark is `UserDefaults["recurring.handled.<uuid>"]` — **per device**. Device B never learns A posted ⇒ B prompts too. | step 3 |
| C | Even with a synced watermark: both devices compute "due" **before it replicates**, both post, `max()` converges the watermark afterwards and two rows remain. | step 3 (`occurrenceID`) |

C is the one that survives the obvious fix. `lastPostedPeriod` + monotone `max()`
addresses B only.

---

## Status

| step | what | status |
|---|---|---|
| 1 | `RecurrencePrompt` carries `PersistentIdentifier`; resolution stops going through `uuid` | IN PROGRESS |
| 2 | Collapse twin templates to one prompt, deterministically | **DONE** `9b5679e` |
| 3 | V2→V3: `lastPostedPeriod` + `autoPostEnabled` + `occurrenceID` | **REVIEW-BLOCKED — no code** |
| 4 | `notificationID(for:)` is uuid-keyed and that is load-bearing; document it | PENDING |
| 5 | Period label derivation (the identity key for step 3) | PENDING |
| — | Jan-31 monthly drift | **FILED, not fixed** — separate task below |

**Freeze gate.** Step 3 changes the schema and is review-blocked. Nothing in
steps 1/2/4/5 adds, removes, or retypes a stored property. The CloudKit
production schema is additive-only forever, so step 3's three optional
attributes must land in **one** migration — which is exactly why `occurrenceID`
is in it rather than deferred to a later `RecurrencePost` record type (Doc 2
§3.4.1).

---

## Step 1 — kill `uuid` as a resolution key

`RecurrencePrompt` carries the template's `PersistentIdentifier`. `confirm` /
`skip` / `handleEditRecurring` take the resolved object instead of re-fetching by
uuid. Closes audit sites **1.1** (`fetchTemplate`) and **1.2**
(`DashboardView.handleEditRecurring`) together.

Blast radius is two files: `RecurrencePrompt` only ever appears in
`DashboardView.duePrompts` and `RecurringPromptSheet.queue`.

**Resolve with a fetch predicated on `persistentModelID`** — measured, not
assumed (see Q2). Not `model(for:)`; not `registeredModel(for:)`.

### What 9b5679e already did, and what it did not

Reported honestly, because the two are easy to conflate:

- **Already landed:** `fetchTemplate` resolves through `canonicalTemplate(among:)`
  rather than `.first`, so it picks the *same* twin the prompt displayed. That
  fixed *which* twin, and it was necessary for the collapse to mean anything.
- **Not landed, and the actual point of step 1:** it still resolved **by uuid**,
  and uuid is no longer a unique key. Choosing well among twins is not the same
  as not needing to choose. Step 1 removes the lookup.

## Step 4 — `notificationID(for: uuid)` is load-bearing

A fifth uuid-keyed site the audit's `uuid ==` grep **structurally could not
see**, because it is string interpolation: `"recurring-\(uuid.uuidString)"`.

Twins share a notification identifier. Under the step-2 collapse that is
**accidentally correct** — one series, one prompt, one notification — and
`removePendingNotificationRequests` on the shared id is what stops a second
pending notification existing at all.

Behavior deliberately unchanged. Comment to be added at both sites so nobody later
"fixes" it into per-row notifications and reintroduces the double prompt through
the notification path.

## Step 5 — the period label (identity key for step 3)

The normalization originally proposed for `occurrenceID` — `"yyyy-'W'ww"` on a
frozen Gregorian / `en_US_POSIX` / UTC calendar — **does not produce ISO weeks**,
and the failure mode is a lost charge, not a cosmetic wrong label.

Two independent defects in one format string:

- **`y` is the calendar year; the week-numbering year is `Y`.** 2024-12-30 is a
  Monday in ISO week **2025**-W01 but formats as "**2024**-W01".
- **`Calendar(identifier: .gregorian)` + `en_US_POSIX` is `firstWeekday = 1`,
  `minimumDaysInFirstWeek = 1`** — US weeks. ISO needs `2` and `4`.

Consequence: 2024-12-30 and 2024-01-01 are **different weeks that produce the
same label** `2024-W01`. find-or-create would collapse them into one row and one
real charge would silently vanish. A missing charge is the failure a user detects
last.

**Implementation rule: no `DateFormatter` on the identity path at all.** Take
`dateComponents` and build the string numerically, so no locale-sensitive
formatting can ever reach the key.

| cadence | components | format |
|---|---|---|
| weekly | `.yearForWeekOfYear`, `.weekOfYear` (ISO calendar) | `%04d-W%02d` |
| monthly | `.year`, `.month` | `%04d-%02d` |
| yearly | `.year` | `%04d` |

`RecurrenceType` has exactly three cases and **no `daily`**, so the label set is
closed. The switch is exhaustive with no `default:`, so adding a fourth cadence
is a compile error rather than a silent fallback into a wrong label.

Golden vectors to pin (the dates where week-year and calendar year disagree):
2024-12-30, 2025-12-29, 2027-01-01, 2026-01-01, 2028-02-29 — plus the
2024-01-01 / 2024-12-30 pair as an explicit **collision witness**, so the bug
cannot come back unnoticed.

The label function ships **unconsumed**: step 3 wires it to `occurrenceID` via
UUIDv5. That is deliberate — it makes the frozen part of step 3 reviewable and
testable before the schema change is approved.

---

## Decided answers (Q1–Q3)

### Q1 — `occurrenceID: UUID?` in the same migration: **yes**

Folded into Doc 2 §3.2, §3.4. Amendments made to the proposal as put:

- **The cost premise was wrong.** CloudKit permits adding a *new record type* to
  a production schema later; what is frozen is deleting or retyping existing
  fields. The verdict is unchanged, for better reasons: a new `@Model` is a new
  schema version — another guarded migration, raw-SQL preflight, `didMigrate`
  verifier, §11 drill — and interim rows would carry no occurrence identity and
  could never be retroactively collapsed.
- **A separate field, not a derived `uuid`** (which is what Doc 2 §3.4 originally
  said). Overloading `uuid` gives one field two meanings across 19 comparison
  sites and makes the identity-vs-similarity distinction unwritable.
- **Doc 2 §3.4's sweep tie-break was broken:** it ordered on "the
  lexicographically smaller `persistentModelID`", which is assigned per device.
  The claim that both devices converge without coordinating was false.
- **find-or-create alone does not close the window.** It only sees rows already
  local, so it closes the *sequential* case. The genuinely concurrent case is by
  definition one where the other row has not arrived — that needs the sweep.
  Shipping only find-or-create closes the case that was never the problem.

Normalization: identity is a period **label**, never an instant and never an
index from the anchor. Timezone and DST become structurally unable to affect it
(UTC has no DST; a label is not an instant). Month-end clamping and Feb 29 move
the *posting date* only. Dropping the anchor from the key removes the one input
two devices can disagree about mid-replication — and the mechanism works in the
window that matters precisely *because* both devices fire off the same stale
watermark, so they compute the same period.

**Residual, stated rather than hidden:** partially-replicated watermarks mean the
two devices compute *different* periods, derive different ids, and do not
collapse. `max()` converges afterwards, so it is a window and not a standing
hole — but it is not closed.

### Q2 — `model(for:)` on a deleted row: **it traps**

Measured, iOS 26.5 / iPhone 17 Pro (`DeletedModelIdentifierTests`, `100e268`):

| call | result |
|---|---|
| `ctx.model(for: <deleted id>)` | returns a **non-nil** `Transaction` |
| `.isDeleted` | reads fine |
| `.amountCents` | **EXC_BREAKPOINT** — `_assertionFailure` ← `Transaction.amountCents.getter` |

It vends a live-looking object over a dead row and traps on the first
stored-property read, so "template deleted on the other device" would become a
launch crash.

**Chosen:** `FetchDescriptor(predicate: #Predicate { $0.persistentModelID == id })`.
**Rejected:** `registeredModel(for:)` — it answers on the *context's registry*,
so it returns nil for a live row a fresh context has not materialized yet, which
is the normal cold-launch state; as an existence check it would silently drop
every series on first launch. Both facts are pinned as tests.

The trap reproducer is committed `.disabled`: it does not fail, it takes the test
process down, and iOS has no exit-test support to isolate it.

### Q3 — divergent twins: the tie-break

Total order over **synced fields only**:

1. later `updatedAt` — an edit is newer than a non-edit, and last-writer-wins is
   already how everything else converges. This is what keeps a user's edit.
2. then earlier `createdAt` — the original row of the series.
3. then content — amount, type, currency, date, merchant, note.

`persistentModelID` is deliberately absent: assigned per device, so ordering on
it is the one choice guaranteed to make two devices disagree. `.first` of a fetch
is the same trap — fetch order tracks insertion order, and the insertion-order
test showed two stores landing on **5200 vs 7300** for the same series before the
fix.

Rows tying on all of (3) are identical in every synced field, so either choice
yields the same **values**. Determinism of the outcome is the guarantee needed;
determinism of which row object wins is not reachable and not required.

The same rule serves step 3's convergence sweep (Doc 2 §3.4.3).

---

## Filed, not fixed: Jan-31 monthly series drift

**Independent of sync. Pre-existing. Its own task, its own diff, its own test** —
it changes posting dates for existing users, so it does not belong inside this
work.

`nextDueDate` computes `recurrence.nextDate(after: lastBoundary)` where
`lastBoundary` is the **last handled date** — i.e. it clamps from the previous
*result*, not from the anchor:

```
Jan 31  →  Feb 28  →  Mar 28  →  Apr 28  →  … permanently on the 28th
```

Correct behavior is to clamp the **anchor's** day-of-month into each target
month, so the series returns to the 31st in March. Same rule makes a Feb-29
yearly series return to Feb 29 in the next leap year.

Repro: monthly template anchored 2026-01-31, confirm once in February, then read
the next due date — expect 2026-03-31, observe 2026-03-28.
