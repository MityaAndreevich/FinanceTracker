# DESIGN 1.0.4 — auto-post recurring transactions

**Status: DESIGN ONLY.** No code, no schema change, no entitlement edit was made
producing this document. Depends on `DESIGN_ICLOUD_SYNC_1_0_4.md` (§3 here is
the joint crux).

Today: a recurring transaction is a normal `Transaction` with `recurrenceRaw`
set; it counts as occurrence #1. Each period the Dashboard raises
`RecurringPromptSheet` offering **Add / Skip / Edit**. Confirming creates a
concrete non-recurring instance (deep-copying the template's splits) and
advances a per-device watermark in `UserDefaults.standard`.

Asked for: the series posts **by default**, and the user is told after the fact
with edit / undo / skip available.

---

## 0. Two corrections to the brief, up front

### 0.1 A notification cannot truthfully say "posted"

`UNNotificationContent` is frozen at schedule time (this is already a load-bearing
fact in this codebase — it is why proactive alerts recompute on `didSave` rather
than repeating on a trigger). iOS gives us no way to run code at the due moment,
so on the day the notification fires, **the row does not exist yet** — it is
created on the next launch (§1). A notification that says "Netflix $15.99 was
added" while nothing was added is a false statement about the user's money, and
it is exactly the class of bug the 1.0.2 alert work was cleaning up ("the
brief's 'through {day}' was a false-number bug").

Recommended copy instead — future-neutral, and true whichever order things
happen in:

> **Netflix — $15.99 today**
> Your monthly charge is due. Open Budget Crab to add or skip it.

The "posted / undo / skip" affordance the founder wants lives **in the app**, as
a review card on the launch that actually posted (§2.3). That is where it can be
truthful, tappable per-row, and undoable.

The alternative that *would* make "posted" true — pre-posting the next
occurrence in advance, back-dated to its due date — is spelled out and rejected
in §1.3.

### 0.2 The watermark change is not optional and not really about auto-post

Moving `recurring.handled.<uuid>` out of per-device `UserDefaults` is a
**prerequisite of sync**, with today's manual prompt unchanged (Doc 1 §0.1):
device A confirms, device B never learns, device B prompts again, user adds
twice. Auto-post makes it worse (no human in the loop to notice), but it does
not create the bug.

---

## 1. Where auto-post runs

### 1.1 The mechanism: launch-time catch-up

iOS will not run our code at 09:00 on the 3rd because a subscription is due. So
"auto" means:

```
app becomes active
  → LaunchGateView reports ready (post-migration, container open)
  → RecurrenceAutoPost.run(context:now:)
       for each template with recurrenceRaw != nil:
           gap = the list of due periods in (watermark, now]
           if gap is empty                → nothing
           if gap.count <= autoPostCap    → post each, back-dated to its due date
           else                           → post nothing; queue for review (§2)
  → one context.save()
  → if anything posted, show the review card (§2.3)
```

Entry point: replaces `loadDueRecurring()` at `DashboardView.swift:322/384`.
It must run **after** the migration gate (never on the pre-migration path — the
container is not open) and it must be idempotent against being called twice in
one launch (the `.task` + foreground path both reach it).

Instances are **back-dated to the due date**, not stamped "now". A charge that
happened on the 3rd belongs on the 3rd — month totals, safe-to-spend, pace, and
the widget all read `tx.date`.

### 1.2 Reuse, don't reimplement

`RecurrenceService.confirm(_:modelContext:)` (`:78–110`) already does exactly
the right thing for one period, including the part that is easy to get wrong:
the **split deep-copy** with fresh uuids and `copy.parent = instance` (A10 — a
split recurring purchase materializing without its splits mis-categorizes
silently, every period). The refactor is:

- Extract the body into `post(template:period:context:) -> Transaction` — no
  save, no watermark write.
- `confirm` becomes: `post(…)` + advance watermark + save + reschedule
  notification. Unchanged externally.
- `RecurrenceAutoPost` calls `post(…)` in a loop and does **one** save for the
  whole batch, then one watermark write per template, then one notification
  reschedule per template.

One save for the batch matters for three reasons: SwiftData cost, the
`didSave` → `LedgerAggregator`/widget/alert cascade firing once instead of N
times (this is the exact hang the 1.0.3 work fixed), and — under sync — the
whole batch going up as one zone batch (Doc 1 §3.1).

### 1.3 Rejected: pre-posting the next occurrence

Post the next occurrence *early*, dated its future due date, so the "posted"
notification is true. Rejected because a future-dated row is inside the current
month for every aggregation we have: month totals, `SafeToSpend`, the budget
ring, `PaceMetric`, and the proactive alert body. The user would see money
spent that they have not spent. Making budgets show *committed* spend is a
defensible product idea, but it is a different feature and a much bigger change
than "post it automatically".

### 1.4 Rejected for 1.0.4: `BGAppRefreshTask`

It would narrow the gap (post + widget refresh without a launch) at the cost of
`BGTaskSchedulerPermittedIdentifiers`, a `fetch` background mode, and — the real
objection — **a third process that writes money rows** (app, AppIntent,
BG task), each a potential racer against the others and against sync. iOS also
gives no delivery guarantee, so it cannot be the mechanism, only an
optimization on top of one. Ship the launch-time loop; revisit the BG task in
1.0.5 once §3's guard has a release of field evidence.

### 1.5 What the notification does

Keep the existing local notification (`scheduleNotification`, `:200`), with two
changes:

- Fire **on** the due date rather than one day before, when auto-post is on. The
  −1 day lead exists to let the user act before being charged, which is the
  *manual* flow's job. With auto-post on, the useful moment is "this is in your
  ledger now (or will be the moment you open the app)".
- New copy per §0.1. Tapping it opens the app, which runs the catch-up loop
  immediately and lands on the review card — so in practice the tap makes the
  notification retroactively accurate.

Everything else — the one-shot authorization request, per-uuid identifiers,
remove-then-add rescheduling — stays as is.

---

## 2. Catch-up policy

### 2.1 The constraint that decides the design

The watermark is a **single high-water date per series**. That representation
cannot express "I posted the last 3 periods but left the 30 older ones
undecided". So the catch-up decision must be all-or-nothing per series for the
whole gap. (A per-period ledger *could* express it — §3.3 — but it is a heavier
model and this policy is better UX anyway.)

### 2.2 Recommendation: auto-post gaps of ≤ 3 occurrences; review anything larger

| Gap | Behavior |
|---|---|
| 1–3 occurrences | Post silently, back-dated, then show the review card (§2.3). Covers every normal usage pattern: open the app weekly, monthly, or after a two-month holiday with a monthly series. |
| ≥ 4 occurrences | **Post nothing.** Queue the series for review: *"Netflix — 8 charges since March 3. Add all · Add the most recent only · Skip all."* The watermark advances only when the user chooses. |

Occurrence-count rather than a day-count, so the rule reads the same for weekly,
monthly and yearly series. Three because it is the largest number where "the
user obviously still has this subscription" is a safe assumption; at eight
months unopened, the subscription may well be cancelled, and silently writing 35
guessed charges into someone's financial history is not a mistake you can undo
from a support email.

Not advancing the watermark for the over-cap case means the review re-appears on
later launches until decided. That is correct — it is a pending decision, not a
nag — and the existing once-per-calendar-day throttle
(`shouldPromptToday()` / `lastPromptDay`) already bounds it.

### 2.3 The review surface

One surface, three entry conditions:

1. **"Added while you were away"** — the auto-post happened. Non-blocking card
   on the Dashboard: *"3 recurring charges added"* → tap → list of what was
   created, each row with **Edit** / **Undo**, plus **Undo all**.
2. **"These need a decision"** — over-cap gap, or the one-time upgrade review
   (§4). Per series: Add all / Add most recent only / Skip all.
3. **Auto-post OFF** — today's `RecurringPromptSheet`, unchanged.

Semantics that must be written down because they are easy to get backwards:

- **Edit** opens the normal editor on the created instance. It is an ordinary
  transaction. The watermark does not move.
- **Undo** deletes the created instance (cascade removes its copied splits) and
  **leaves the watermark advanced** — undo means *"not this period"*, i.e. it
  is a Skip. Rewinding the watermark would re-post the same charge on the next
  launch, which is the worst possible response to a user saying "no".
- **Skip** on an un-posted period advances the watermark without creating a row
  (today's `skip`, `:113`).

Note an existing wrinkle to fix while here: `DashboardView.handleEditRecurring`
(`:394`) currently calls `skip` *then* opens the editor — so "Edit" today
silently means "skip this period and edit the template". Under auto-post that
mapping is wrong; Edit must target the posted instance.

### 2.4 Auto-posted rows must not trip the rating prompt

`RatingPromptCoordinator.recordTransactionSaved()` counts saves toward the
StoreKit review request. A catch-up batch is not the user achieving anything —
and the review prompt is an out-of-process window that eats taps (that is the
documented cause of an entire UI-suite failure). Auto-post calls the post path
**without** `recordTransactionSaved()`. This is a one-line rule and a named
regression test.

---

## 3. Idempotency under sync — the crux

### 3.1 The requirement

Two devices, both launched around the due date, must produce **exactly one**
instance per period. Under eventual consistency this cannot be guaranteed by
mutual exclusion — there is no lock, and the devices may be offline from each
other at the moment they both decide. So the design has three layers, and the
third is the one that actually saves us:

1. **Shared state**, so a sequential second device sees the first device's work.
2. **Monotonicity**, so a stale device can never rewind the boundary.
3. **Deterministic identity + a convergence sweep**, so a genuinely concurrent
   double-post is *detectable and self-heals to the same outcome on both
   devices*.

### 3.2 Layer 1 — representation: a field on the template

**Recommended: `Transaction.lastPostedPeriod: Date?`** — a new optional
attribute on the existing model, in the synced store.

- It commits in the **same `context.save()`** as the instance it authorizes, so
  the row and the boundary that accounts for it travel together (one zone, one
  batch).
- No new model, no new store, no new entitlement, no separate consent.
- Optional-with-no-default → CloudKit-legal, additive, and lightweight-migratable
  (V2 → V3, one field). It is the *only* schema change this release needs.

Add **`Transaction.autoPostEnabled: Bool?`** in the same bump even though 1.0.4
does not read it (§5). A second migration on a synced store is strictly more
expensive than an unused optional field, and the CloudKit production schema is
additive-only forever (Doc 1 §1.3) — the cheap moment to add a field is now.

Add **`Transaction.occurrenceID: UUID?`** in that same bump as well (§3.4). It is
not an optimization: `lastPostedPeriod` + `max()` fixes only the *unsynced
watermark*, and leaves the *sync-lag* double charge completely open. The V2→V3
migration is the moment to close both. So the migration carries three optional
attributes, not one.

**Rejected:** `NSUbiquitousKeyValueStore` — eventually consistent with *no*
relationship to the store's own transaction boundary, and silently inert when
signed out. Not acceptable for something that decides whether money rows exist.

### 3.3 Layer 2 — the monotonic rule

> **Every write to `lastPostedPeriod` is a `max()`. The watermark only ever
> moves forward.**

This single rule kills most of the failure space:

- A device whose LWW copy lost still cannot rewind the boundary — its next write
  is a max against the value it has, and the losing older value never wins.
- The UserDefaults→model migration (§4) becomes safe on a second device:
  `max(synced value, this device's local key)`.
- `stopRecurrence` / `applyRecurrenceSideEffects(previous:current: nil)` are the
  only writes that *clear* it (series ended → nil), and they are user-initiated,
  so they are exempt by intent, not by accident.

The alternative representation — **a `RecurrencePost` ledger** (one row per
`(templateUUID, period)`) — is strictly more expressive (it could support the
"post recent, leave old undecided" policy §2.1 rules out) and it makes
idempotency an existence check rather than a comparison. It is rejected for
1.0.4 only on cost: a new synced model, rows forever, and a new CloudKit record
type frozen into the production schema on day one. Worth revisiting if per-period
decisions ever become a real product need.

### 3.4 Layer 3 — deterministic identity + convergence sweep

> **Revised 2026-07-30.** The previous version of this section was right about
> the mechanism and wrong about two details, one of which did not work at all.
> It proposed deriving the auto-posted instance's **`uuid`**, and a sweep
> tie-broken on "the lexicographically smaller `persistentModelID` string".
> `persistentModelID` is assigned **per device**. Two devices cannot agree on
> its ordering, so the sentence "both devices converge on the same survivor
> without coordinating" was false as written — that tie-break is precisely the
> thing that makes them diverge. This is not theoretical: the insertion-order
> test added with the twin collapse (`RecurrenceTwinCollapseTests`) shows two
> stores holding the same two rows landing on 5200 and 7300 respectively,
> because fetch order tracks insertion order.

Neither a watermark nor a post-ledger prevents a *concurrent* double-post: both
devices decide, both create, both set the boundary, LWW picks a winner among the
boundaries — and **both instances survive**. Note what this means for §3.2's
`lastPostedPeriod` + `max()`: that pair fixes "the watermark never syncs". It
does **not** fix "both devices computed due before the watermark replicated".
CloudKit is explicitly not a real-time database, so that window is real and the
double charge survives it by a different route. So make the duplicate
**detectable**:

> Every recurrence-created instance carries **`Transaction.occurrenceID: UUID?`**,
> derived deterministically from `(template uuid, cadence, normalized period
> label)`. Both devices independently compute the SAME id for the same
> occurrence. `nil` on every row the recurrence engine did not create.

**Two rows sharing an `occurrenceID` are provably one record**, not a content
coincidence — which is what makes collapsing them legal (§3.4.3).

#### 3.4.1 A separate field, not a derived `uuid`

The earlier proposal overloaded `uuid`. Rejected, for three reasons:

- `uuid` already carries the CSV export/import identity and the "is this row
  already here" import skip. Giving it a second meaning means every future
  reader of a `uuid ==` comparison has to work out which of the two is intended
  — and there are already 19 such sites (Doc 1 audit §0).
- "Two rows share a `uuid`" would then mean two different things: *first-sync
  union twin* (Doc 1 §2.3) and *same occurrence posted twice*. They need
  different handling and must stay distinguishable.
- It makes §3.4.3's justification unwritable. `occurrenceID == occurrenceID` is
  an identity claim; `amount + merchant + date` is a similarity claim. If both
  live on `uuid`, the code comment at the merge site has to explain why this
  particular uuid comparison is one and the neighbouring one is the other.

**One optional field now vs. a `RecurrencePost` record type later — verdict: now,
but the stated reason needs correcting.** CloudKit does *not* forbid adding a new
record type to a production schema later; what is frozen is the ability to delete
or retype existing fields. So "a brand-new record type after the schema is frozen
forever" is not the blocker. The real costs still point the same way:

1. A new `@Model` is a new SwiftData schema version — another guarded migration,
   another raw-SQL preflight, another read-only `didMigrate` verifier, another
   §11 TestFlight drill. In this project *that* is the expensive artifact, not
   the CloudKit record type.
2. Rows posted in the interim would carry no occurrence identity at all and
   could never be retroactively collapsed — the later fix would need this exact
   derivation *plus* a backfill *plus* a repair sweep.
3. The field is one optional UUID, additive, lightweight-migratable, riding a
   migration that is already review-blocked.

#### 3.4.2 Normalization — where determinism actually breaks

The identity must not be derived from an **instant**. `Date` is an absolute
time; the moment any device renders it through `Calendar.current` to get a
"period", the answer depends on that device's time zone, and a user who travels
disagrees with themselves. Two rules:

**Canonical calendar, frozen forever:** Gregorian, `en_US_POSIX`,
`TimeZone(secondsFromGMT: 0)`. Never `Calendar.current`. Precedent exists in the
same file — `todayKey()` already pins gregorian + `en_US_POSIX` for the daily
throttle.

**Identity is a period LABEL, not a period date, and not an index from the anchor.**

| cadence | label | format |
|---|---|---|
| weekly | ISO-8601 year + week | `yyyy-'W'ww` (`yearForWeekOfYear`, `weekOfYear`) |
| monthly | civil year + month | `yyyy-MM` |
| yearly | civil year | `yyyy` |

Name string, byte-exact and frozen once shipped:

```
"\(templateUUID.uuidString.lowercased())|\(cadence.rawValue)|\(label)"
```

`occurrenceID` = UUIDv5 (SHA-1, namespaced, version/variant bits set) over that
UTF-8 string, under a fixed app namespace UUID. CryptoKit is a system framework,
so this adds no dependency. **Pin a golden vector in a test** — a literal
expected UUID for a known input — so that an innocent refactor of the format
string, which would silently re-key every occurrence and un-collapse everything,
fails loudly instead.

Why a label and not an occurrence index `n` counted from the anchor: an index
puts the template's own `date` into the identity, and during the very lag window
this exists to survive, two devices can disagree about which twin is canonical
and therefore about the anchor. A label removes the anchor from the identity
entirely. This is also what makes the mechanism work in the window that matters:
**both devices fire precisely because they hold the same stale watermark**, so
they compute the same period, so they derive the same id.

Now the four cases asked for, against that scheme:

- **Timezone / travel.** Cannot affect it. The canonical calendar is UTC and is
  never the device's. *Constraint that follows:* a transaction created 23:30
  local in UTC+3 has a UTC civil date one day earlier, so the label can sit one
  day off what the user sees. That is acceptable for an internal identity key
  and **must never be reused for display**, or a user who created a series on
  Feb 1 sees it labelled January.
- **DST, both directions.** Cannot affect it, twice over: UTC has no DST, and a
  civil period label is not an instant, so there is no hour to gain or lose.
  This is the main reason to prefer a label over any arithmetic on `Date`.
- **Month-end clamping (anchored on the 31st, in a 30-day month).** Affects the
  **posting date only**, never the identity — Jan 31 and its Feb 28 posting are
  both simply period `2026-02`. The posting-date rule: clamp the anchor's
  day-of-month to the last valid day of the target month, **always clamping from
  the original anchor, never from the previous clamped result**.
  *Pre-existing bug this exposes:* today `nextDueDate` computes
  `nextDate(after: lastBoundary)` where `lastBoundary` is the last handled date,
  i.e. it clamps from the previous result. A Jan-31 monthly series therefore goes
  Jan 31 → Feb 28 → **Mar 28** and stays on the 28th forever. It must clamp from
  the anchor. Independent of sync; worth its own fix and its own test.
- **Feb 29.** A yearly series anchored Feb 29 2024 labels its occurrences `2025`,
  `2026`, `2027`, `2028` — the identity never touches the day. The posting date
  clamps to Feb 28 in common years and returns to **Feb 29 in 2028**, precisely
  because clamping is from the anchor and not from the previous posting.

**Residual, stated honestly:** if the watermark has *partially* replicated so the
two devices hold *different* watermarks, they compute different periods, derive
different ids, and the sweep will not collapse them. `max()` converges the
watermark afterwards, so this narrows to a genuine window rather than a standing
hole, but it is not closed by this mechanism and should not be described as if it
were.

#### 3.4.3 The merge site, and why this is not content dedup

`confirm()` (and the auto-post path) does **find-or-create on `occurrenceID`**
rather than a bare insert, plus a convergent sweep on remote-change import.

**Both are required, and the reason is worth stating because the proposal reads
as complete without it:** find-or-create only sees rows that are already local,
so it closes the *sequential* case — the other device's row arrived before this
device prompted. The genuinely *concurrent* case is by definition one where the
row has not arrived yet, so nothing at insert time can catch it. That one is
closed by the sweep, on import. A design that ships only find-or-create closes
the case that was never the problem and feels finished.

Survivor rule for the sweep: **the same total order the twin collapse already
uses** — `RecurrenceService.canonicalTemplate` / `precedes`: later `updatedAt`,
then earlier `createdAt`, then content (amount, type, currency, date, merchant,
note). Synced fields only; no `persistentModelID`. Later-`updatedAt`-wins is what
keeps a user's edit: if this device auto-posted and the user then corrected the
amount, and the other device's untouched copy arrives, the edit survives.
"Earliest `createdAt`" as the primary key — the previous version of this section
— would have discarded it.

At the merge site, in a comment:

> Collapsing two rows here is **identity**, not similarity: they carry the same
> `occurrenceID`, which is a pure function of (template, cadence, period), so
> they are provably two representations of one posting. This does **not** breach
> the rule in `project_quickadd_no_content_dedup` — that rule forbids inferring
> "duplicate" from *content* (amount | type | merchant within a window), because
> two identical coffees are two real spends. Nothing here reads content to
> decide; content is only ever used to break a tie between rows already proven
> identical. A row with `occurrenceID == nil` is never a merge candidate, which
> is why a manual "Netflix 15.99" typed on the same day is never absorbed into
> the auto-posted one.

This is legal because `.unique` is gone (V2) — we own uniqueness at the write
sites now, which here means we own it in the sweep. It also keeps the CSV
round-trip idempotent: `uuid` keeps its single meaning, so an own-export
re-import still uuid-skips.

### 3.5 Layer 0 — don't post at all on an unconverged device

A freshly-synced device that has not yet imported the other device's history
would compute gaps against a template whose watermark has not arrived, and post
everything. Guard:

> Auto-post runs only when sync is off, **or** at least one successful remote
> import has been observed on this install (the "last remote change" timestamp
> from Doc 1 §6 is non-nil).

Until then, fall back to the review surface (§2.3 case 2) — never a silent
write.

### 3.6 One more audit item — **DONE (9b5679e)**

`RecurrenceService.fetchTemplate(_:)` returned `.first` of a `uuid` predicate. If
a first-sync union produced two templates with the same uuid (Doc 1 §3.6),
auto-post could drive one and prompt for the other.

The framing here understated it. The primary defect was not *resolution* in
`fetchTemplate` — that takes one twin, once. It was the **row count** in
`dueRecurring`, which fetches on `recurrenceRaw != nil` and so counted rows, not
series: two rows meant the user was asked to log the same charge **twice in one
sitting**. Shipped fix:

- `dueRecurring` groups by `uuid` and collapses each series to one prompt.
- `fetchTemplate` resolves through the *same* canonical rule, so `confirm()`
  cannot materialize a twin the prompt never showed (approve 73.00, get 52.00).
- Prompt ordering is total — `(dueDate, uuid)` — so both devices ask in the same
  sequence rather than presenting the same two decisions in different orders.

The proposed mitigation ("drive auto-post from the fetched template object
itself") is necessary but was not sufficient on its own: holding the object
avoids a *re-fetch*, but the object the loop is holding is still an arbitrary
twin unless something canonicalizes it first. That something is
`canonicalTemplate(among:)`, which §3.4.3's sweep now shares.

---

## 4. Migrating existing series — never a silent bulk post

Existing users set up their series under "you will be asked" semantics.
Retroactively converting a pending decision into a write is the one move there
is no recovering from. So:

1. **One-shot watermark migration**, before any auto-post pass, on the first
   1.0.4 launch: for every template with `recurrenceRaw != nil`, set
   `lastPostedPeriod = max(existing synced value, UserDefaults recurring.handled.<uuid>, nil)`;
   if all are absent, leave nil (`nextDueDate` then keys off `tx.date`, exactly
   today's behavior). Then remove the defaults key. On a *second* device
   upgrading later, the same `max()` rule means its stale local key cannot
   clobber the synced value.
2. **Stamp `autoPostIntroducedAt`** (a local one-shot date).
3. **Every period due before `autoPostIntroducedAt` goes to review, never to
   auto-post** — regardless of the §2.2 cap. The user sees the list of what
   *would* be added and decides. Only from the next period onward does the
   series post silently.

That is the whole compatibility story: nobody who upgrades wakes up to rows they
did not authorize.

---

## 5. The global "auto-add recurring" setting

**Where:** Settings → Recurring (`RecurringSettingsView`, which already lists
the series), as a single toggle backed by `@AppStorage("autoPostRecurring")`.

**Default: ON**, for two reasons — it is what the founder asked for, and the §4
migration already protects every existing user's pending periods from it. New
users get the behavior the feature exists to provide.

**Per-device or synced?** Per-device for 1.0.4 (no new sync surface). The
observable consequence, stated plainly rather than discovered later: because the
*watermark* is synced but the *toggle* is not, the effective behavior of a
two-device setup is "auto-post happens if **any** device has it on" — whichever
device runs first posts, and the other device sees the row and the advanced
watermark. There is no double-post (that is §3's job) and no missed post. A user
who wants auto-post off must turn it off on every device; the Sync settings
screen lists it under "kept separate on each device" (Doc 1 §4).

**Per-series override** (`autoPostEnabled`) is *not* wired in 1.0.4 — the field
is added to the schema now (§3.2) so that shipping it later is not a second
migration on a synced store.

---

## 6. Backward compatibility — what changes, what is removed

**Removed: nothing.** `RecurringPromptSheet` survives and gains roles (§2.3).
The daily throttle survives. `RecurrenceType`, `nextDueDate`, the notification
identifiers, and the Settings → Recurring list are untouched.

| Symbol | Change |
|---|---|
| `handledDate` / `setHandledDate` / `clearHandled` | Same three functions, backed by `template.lastPostedPeriod` instead of `UserDefaults`. Setter enforces `max()` (§3.3). They stay internal-not-private for the same reason as today: the boundary is what an edit's effect can only be verified by reading back. |
| `confirm(_:modelContext:)` | Body split into `post(template:period:context:)` + boundary + save. External behavior identical. |
| `skip(_:modelContext:)` | Unchanged semantics; writes the new boundary. |
| `stopRecurrence` | Unchanged; clears the field instead of the defaults key. |
| `applyRecurrenceSideEffects(for:previous:)` | Unchanged decision table (`:155–185`). The "cadence change keeps the boundary, series end clears it" reasoning holds verbatim. |
| `scheduleNotification` | Fires on the due date instead of −1 day **when auto-post is on**; new copy (§0.1, §1.5). |
| `checkAndPromptDueRecurring` | Becomes the auto-post entry point; returns what to review rather than what to prompt. |
| `DashboardView.handleEditRecurring` | Retargeted at the posted instance instead of skip-then-edit (§2.3). |

Tests that must move with it: anything reading `RecurrenceService.handledDate`
now needs a `ModelContext`. That is a net win — the boundary becomes assertable
in the same store as the row it authorizes.

---

## 7. Open questions, with a recommended default for each

| # | Question | Recommended default |
|---|---|---|
| **R-1** | Auto-post cap: 3 occurrences, or a day-window, or post-all? | **≤ 3 occurrences auto-posts; ≥ 4 goes to review** (§2.2). Cadence-independent, and it bounds silent writes to a number the user can audit in one glance. |
| **R-2** | Global toggle default? | **ON**, protected by the §4 one-time review for existing series. |
| **R-3** | Toggle synced or per-device? | **Per-device**, with the "any device with it on will post" consequence documented in the Sync settings screen (§5). |
| **R-4** | Watermark: field on the template, or a `RecurrencePost` ledger? | **Field** (`lastPostedPeriod`), plus monotonic `max()` and the deterministic-uuid sweep (§3.2–3.4). Ledger revisited only if per-period decisions become a product need. |
| **R-5** | Do we also add `autoPostEnabled` now? | **Yes**, unused. One migration is cheaper than two on a synced store whose production schema is additive-only forever. |
| **R-6** | Notification says "posted"? | **No** — impossible to say truthfully (§0.1). Due-date copy in the notification, "added / undo" in the app. |
| **R-7** | `BGAppRefreshTask`? | **Not in 1.0.4** (§1.4). |
| **R-8** | Does Undo rewind the watermark? | **No** — Undo == Skip for this period (§2.3). Rewinding would re-post it next launch. |
| **R-9** | Do auto-posted rows count toward the rating prompt / free-tier counters? | **Rating prompt: no** (§2.4). Free-tier caps: unaffected — there is no cap on transactions, only on accounts and custom categories. |
| **R-10** | Ship with sync, or after it? | **After**, if the schedule allows — see below. |

### The smallest safe 1.0.4 slice

**In:**

1. V2→V3: two optional fields on `Transaction` (`lastPostedPeriod`,
   `autoPostEnabled`), lightweight migration, CloudKit-legal.
2. The UserDefaults→model watermark migration with the `max()` rule (§4.1).
3. `post(template:period:context:)` extracted from `confirm`, splits deep-copy
   preserved; launch-time catch-up loop with the ≤3 cap and one batched save.
4. Deterministic instance uuid + convergence sweep + the "don't post before the
   first import" guard (§3.4, §3.5).
5. The review surface: added-while-away card with per-row Edit / Undo, and the
   over-cap / upgrade decision list.
6. One-time upgrade review for every existing series (§4).
7. Global toggle, default ON, in Settings → Recurring.
8. Notification: due-date timing + honest copy, 5 locales.
9. No rating-prompt increment from auto-posted rows.

**Out:** per-series override (field only) · `BGAppRefreshTask` · pre-posting /
committed-spend semantics · a `RecurrencePost` ledger · anything that reconciles
duplicate *templates* (that is sync's §2.4, and it deliberately does not touch
transactions).

**On R-10 — sequencing.** Items 1–2 (watermark into the model) are a hard
prerequisite of sync and should ship **with** sync regardless. The rest of
auto-post is independent and safer one release later: if a double-charge report
arrives from a build that shipped both, you cannot tell whether sync converged
wrongly or the catch-up loop raced, and that is a bad position to debug a money
bug from. If the founder wants both in 1.0.4, drill **D-7** (Doc 1 §7 — two
devices, one due series, exactly one instance) becomes the single hardest gate
in the release and must be run twice on real hardware, on two different
cadences, with one device offline for one of the runs.
