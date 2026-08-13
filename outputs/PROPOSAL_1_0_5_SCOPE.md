# PROPOSAL — 1.0.5 scope

**Date:** 2026-08-12 · **Base:** HEAD `4e6a8db` · **Status: PROPOSAL. Nothing built.**
**Constraint:** no schema, no sync, all user-visible.
**Not in this release, not started:** sync, V3, the rollback ladder, Reports, family.

Companion to `AUDIT_BACKLOG_VERIFIED_2026-08-12.md`. Where the two disagree, this document is
later and wins — see §0.

---

## 0. Two corrections to my own audit, before anything is planned on them

Both are in Group 2's list of eight. **Verifying them to propose a fix showed the fix already
exists.** The audit was wrong; the code is right.

### 0.1 The mic does NOT vanish. It has never vanished since Bug 7.

You asked me to explain the current behaviour before proposing a hint. The current behaviour is
correct, and my audit entry was drawn from a stale comment rather than from the rendering path.

`QuickEntryView.swift:769–773`:

```swift
// Bug 7: always show the mic so voice is discoverable in every locale.
// When on-device recognition isn't installed for the user's language,
// tapping surfaces a friendly "type instead" toast (toggleVoice →
// .deviceUnavailable) rather than hiding the control with no explanation.
micButton
```

`micButton` (`:787`) is rendered **unconditionally**. There is no `if voice.isAvailable` anywhere
in the view. Tapping with no recognizer routes through `authState = .deviceUnavailable`
(`VoiceInputService.swift:173`) to `QuickEntryView.swift:965`, which shows
`quick_entry.voice.unavailable` = *"Voice not available for this language"* — localized ×5.

**Exactly the design a hint would have proposed. It shipped already.**

**What misled me — and it is the fourth instance of this project's recurring pattern.** Two stale
artifacts still describe the pre-Bug-7 behaviour:

- `VoiceInputService.swift:8` — doc comment: *"the service hides itself entirely
  (`isAvailable == false`) when on-device…"*
- `VoiceInputService.swift:123` — DEBUG print: *"No on-device recognizer… **Mic will be hidden.**"*

`isAvailable` (`:162`) still exists and is still correct as a *predicate*; nothing in QuickEntry
gates the mic on it any more. **Proposed action: delete the two stale claims. Zero behaviour
change.** This is the same failure mode as the `.deny` delete rule, the `@Attribute(.unique)`
claim in CSV import, and the "Vela" privacy policy — a comment that outlived the code beneath it,
and it cost this audit a false finding.

→ **Removed from the discoverability list. Filed in Group 1 as a comment deletion.**

### 0.2 The alerts screen is not a dead end, and not a design defect

Your instinct was that this sounded like a design defect rather than a discovery gap. It is
neither — it is already a guided precondition, and a well-written one.

`AlertsSettingsView.swift:35–40` is a three-way branch, and the middle arm is not a wall:

```swift
if !access.isAllowed(.proactiveAlerts) { premiumSection }
else if !isBudgetSet                   { needsBudgetSection }
else                                   { alertSection }
```

`needsBudgetSection` (`:104–113`) renders a header, an explanation, **and a CTA that opens
`BudgetSetterSheet` inline** (`:50`) — the user never leaves the screen:

- `alerts.needs_budget.title` — "Set a budget first"
- `alerts.needs_budget.message` — "Alerts tell you what's safe to spend, so they need a monthly budget to work from."
- `alerts.needs_budget.cta` — "Set a budget"

It states the precondition, gives the reason, and offers the action in place. **Nothing to fix,
nothing to teach.**

→ **Removed from the discoverability list.**

### 0.3 The list is therefore six, not eight

**Shake-to-undo · the widget · Siri intents · chart drag-to-scrub · category limits ·
merchant learning.**

I would rather hand you six real ones than eight with two invented. Both removals also make the
"don't turn the app into a tutorial" constraint easier to hold, since the two I got wrong were the
two that would have needed the most explaining.

---

## GROUP 1 — things that lie to the user

### 1.1 `AboutView.swift:57` — `idTBD` → `6784424678`

One-line change, no decision needed.

```swift
private static let appStoreURL = URL(string: "https://apps.apple.com/app/budget-crab/id6784424678")!
```

Also delete the now-false instruction comment at `:56`. Verify by tapping through both call sites
(rate + share). **Ready to execute on a word — no proposal needed.**

### 1.2 The dead "Restart onboarding" button — **RECOMMEND: REMOVE IT**

**Recommendation: remove the button, its alert, its handler, and its three strings.
Do not make it work.** Three reasons, in increasing order of seriousness.

**Reason 1 — it is a duplicate of a button that already works, in the same screen.**
`GeneralSettingView` ships two tutorial-restart affordances:

| | "Replay tutorial" (`:420–429`) | "Restart onboarding" (`:436–440` → `:456–459`) |
|---|---|---|
| Section | Tutorial & Sample Data | Maintenance |
| Sets replay flag | ✅ `:425` | ❌ |
| Posts the notification | ✅ `:428` | ❌ |
| Resets the rating gate | ✅ `:427` | ❌ |
| Takes effect | **immediately** | next cold launch |

Making the dead one work produces **two buttons in one Settings screen that do exactly the same
thing**. That is a worse outcome than either fixing or removing.

**Reason 2 — its alert promises a screen that no longer exists.** This is the part I did not have
when I wrote the audit:

```
"general.alert.restart_onboarding.message" = "You'll see the language & currency setup again.
                                              Your transactions will stay intact.";
```

The language & currency wall was **deleted** (Brief 28 Part E; `RootView.swift:64–66`). Its strings
are orphaned (`onboarding.language.*`, `onboarding.currency.*`). So the button does not merely fire
late — **it describes an outcome that cannot happen in any build.** "Make it work" is not even
well-defined: there is no such screen to restore.

**Reason 3 — it is the class you spent a month removing.** A destructive-styled confirmation, user
consent, and no observable effect. Silent no-op *plus* a false promise about what it would have
done.

**Scope of removal:** the Button (`:436–440`), the `.alert` (`:152–157`), `restartOnboarding()`
(`:456–459`), `@State showRestartOnboardingAlert` (`:46`), the `@AppStorage hasCompletedOnboarding`
in this file (`:17`) if it becomes unused, and 3 keys × 5 locales
(`general.restart_onboarding`, `general.alert.restart_onboarding.title`, `.message`).
`general.alert.restart` is shared with other alerts — **check before deleting it.**

**Also dead, worth taking in the same pass:** `OnboardingCoordinator.requestReplay()` (`:94`).
Settings writes `replayKey` directly; nothing calls the method. Harmless, but it is the API the
working path bypasses, and leaving it invites someone to "fix" the wrong path later.

**Cleanup this unblocks:** `RootView.swift:11` reads `hasCompletedOnboarding` and `:69` animates on
it, but `appContent` (`:62–68`) never branches on it. Both are vestigial from the deleted gate.
Removing them is what makes the button's deadness impossible to reintroduce.

**The honest counter-argument, stated so the decision is real.** "Restart onboarding" in
Maintenance and "Replay tutorial" under Tutorial & Sample Data may read as different promises to a
user — one sounds like a reset, the other like a demo. But the *only* implemented behaviour is
replay, the alert's description of a reset is false, and no data is touched either way. If the
naming matters, the fix is to rename the surviving button — not to keep a second one.

### 1.3 Delete `tutorial.page1–3` — with one key that must survive

**Verified across all five locales: 9 `tutorial.page*` keys each, in perfect parity.**
`en` · `ru` · `uk` · `es` · `pt-BR` — 9, 9, 9, 9, 9.

**⚠️ `tutorial.page3.demo_offer` is LIVE and must NOT be deleted.** It renders at
`GeneralSettingView.swift:164`. It is the only survivor of the retired carousel.

**Delete — 8 keys × 5 locales = 40 entries:**

```
tutorial.page1.headline      tutorial.page2.headline      tutorial.page3.headline
tutorial.page1.caption       tutorial.page2.caption       tutorial.page3.bullet1
                                                          tutorial.page3.bullet2
                                                          tutorial.page3.bullet3
```

**Keep:** `tutorial.page3.demo_offer`.

**Recommend taking three more in the same pass** — same carousel, same orphan status, verified
unused in `*.swift` (note `onboarding.skip` is a *different*, live key used by `CoachmarkOverlay`):

```
tutorial.skip      tutorial.cta.next      tutorial.cta.get_started
```

That makes **11 × 5 = 55 entries**, baseline **765 → 754**. `LocaleCompletenessTests.swift:244`
asserts the exact English count and must be updated in the same commit or the suite goes red.

**Deliberately NOT in this pass** — the retired language/currency wall's orphans
(`onboarding.language.*`, `onboarding.currency.*`, `onboarding.start`, `onboarding.search.*`,
~12 more keys). They are the same class, but they are entangled with the "Restart onboarding"
removal in 1.2 and with `SupportedLanguage` / `SupportedCurrency`, which are still live models.
Worth a separate sweep with its own grep; batching them here risks deleting a key something still
reads.

**Side benefit that pays for the work:** deleting `tutorial.page3.bullet1` removes the string
`DESIGN_ICLOUD_SYNC §2.1` named first among the copy that breaks when sync ships. One fewer
landmine, deleted rather than rewritten. (§2.1's count is corrected as of today — it said five,
listed four, and the real live number is ten.)

---

## GROUP 2 — discoverability, proposed per capability

**Six capabilities.** Ranked by *shipped value currently earning nothing*, not by ease.

### The governing rule I applied

Every hint costs attention, and calm is the wedge. So I applied one test to each: **does the user
need to be told this, or do they need to be able to find it at the moment they want it?** The
second is almost always cheaper and quieter — a visible affordance costs nothing when ignored,
where a hint costs attention every time it fires.

**Result: 4 of 6 need NO new mechanism.** No new coachmark step is proposed. The first-run flow
stays at three steps.

| # | Capability | Proposal | New mechanism? |
|---|---|---|---|
| 1 | **Widget** | Settings entry + one Help pointer | **None** |
| 2 | **Siri / Shortcuts** | Settings entry, same row group | **None** |
| 3 | **Chart drag-to-scrub** | Affordance, not a hint — this is a design fix | **None** |
| 4 | **Category limits** | Empty-state / footer copy where limits are already visible | **None** |
| 5 | **Shake-to-undo** | Replace the gesture's discovery problem — see below | Small |
| 6 | **Merchant learning** | One-line confirmation on the moment it learns | Small (1 inline hint) |

---

### 1. Widget — **Settings entry. No new mechanism.**

*Current:* mentioned only in `help.widget` article, four taps into Settings. A redesigned,
twice-iterated surface the app never mentions.

*Proposal:* a row in Settings, next to Learn & Tips, that opens the existing `help.widget` article
(`help.widget.body` already gives the exact Home Screen procedure). Nothing new is written.

*Why not a coachmark:* the action happens **outside the app**, on the Home Screen. A coachmark
cannot point at it, and interrupting first-run to describe a Home Screen procedure is precisely
"turning the app into a tutorial".

*Why this is enough:* the widget is a thing users go looking for once they like an app. They need
it to be **findable on purpose**, not pushed. A one-line Settings row converts "invisible" to
"discoverable by ordinary poking" for near-zero attention cost.

**Cheaper alternative worth considering:** promote the existing `help.widget` + `help.siri`
articles out of the Learn & Tips sub-list into a single "Set up Widget & Siri" Settings row. One
row, both capabilities, no new copy at all.

### 2. Siri / Shortcuts — **Settings entry, same row. No new mechanism.**

*Current:* `BudgetCrabShortcuts` auto-surfaces headless intents to Siri / Action Button /
Shortcuts. The app never says so. `help.siri.body` already contains the exact phrasing
("Hey Siri, add ten dollars groceries in Budget Crab").

*Proposal:* fold into the row above.

*Why not a hint on the entry surface:* offering Siri at the moment someone is typing an expense
competes with the action they are already completing. Wrong moment.

*Deliberately not proposed:* an `AppShortcut` tip or a donation prompt. That is a new mechanism for
a capability whose problem is a missing signpost.

### 3. Chart drag-to-scrub — **an affordance, not a hint. This is a design fix.**

**This is the one I would build first, and it is not really a discoverability item.**

*Current:* Pulse and Horizon both support drag-to-scrub. **Neither shows any visual cue.** The
interaction is documented only in `help.analytics.body`. Tap-to-drill on Breakdown slices and
Horizon months has the same problem.

*Why it is a defect, not a gap:* a chart that responds to a gesture it does not advertise reads as
**broken or static**, not as hiding a feature. Users do not fail to discover it; they conclude
there is nothing there. That is a worse outcome than a missing feature, and no hint fixes it,
because a hint fires once and the affordance is absent forever after.

*Proposal — the standard Swift Charts idiom, no new mechanism:* a resting selection indicator —
a faint vertical rule at the most recent point with its value in the annotation slot, present on
first render. It says "this axis is addressable" permanently and silently, and it disappears into
the design the moment the user drags. Same treatment on Horizon.

*Cost:* per-chart, inside `AnalyticsPulseView` / `AnalyticsHorizonView`. **Must route through
`ChartGuards`** — a resting indicator is a rendered mark, and this project has a documented history
of degenerate-domain and degenerate-frame crashes on exactly these two charts. It also lands
while #22 is still open, so the ChartBisection scaffolding stays and this change must be
bisectable through it.

*Risk: the highest in Group 2*, and it is the only Group 2 item that touches the crash surface.
If that is unwelcome in 1.0.5, **defer this one item** — but defer it explicitly, not by folding
it into a copy change that will not fix it.

### 4. Category limits — **empty-state / footer copy. No new mechanism.**

*Current:* set inside a category row in Settings → Categories & Accounts, below the fold. Nothing
in the Dashboard or Analytics points at it. A 1.0.3 feature that is effectively unshipped.

*Proposal:* a footer line in `CategoriesSourcesView` stating that expense categories can carry a
monthly limit, on the section that already lists them. That is where a user is *already looking at
the categories*, which is the moment the thought occurs — the same logic that made
`add.category.split_hint` the right shape for splits.

*Why not a Dashboard surface:* the Dashboard already runs a strict one-teaching-card-at-a-time slot
(`DashboardTeachingSlot.decide`, `DashboardView.swift:1089–1122`). Adding a competitor for that
slot costs the tip or the Day-0 nudge. Not worth it.

*Cost:* one new key ×5. **Note the interaction with 1.3:** it lands in the same
`Localizable.strings` pass, so the baseline arithmetic is 765 − 55 + 5.

### 5. Shake-to-undo — **the discovery problem is real, but the gesture is the wrong answer**

*Current:* `DashboardView.swift:318` — `onShake { undoLastAutoSave() }`, a 30-second window
(`:598`). **Zero strings anywhere mention shaking.** No hint, no article, nothing.

*The honest read, and it argues against teaching it:*

- Shake-to-undo is a real iOS system idiom, so it is not unreasonable — but it is one of the
  **least-known** system idioms, and Apple's own guidance treats it as a supplement, never as the
  only path to an action.
- It is **undiscoverable by design**. A gesture with no visual affordance cannot be found; it can
  only be told. That makes it a permanent teaching cost, on every new user, forever.
- Teaching it requires firing a hint at a moment the user has *just successfully saved something* —
  interrupting a success with "by the way, you can undo that" is exactly the anxious-app tone the
  wedge is against.

**Proposal: give undo a visible home, then stop teaching the gesture.** The 30-second window
already exists and already works; what it lacks is a surface. A brief undo affordance on the
confirmation that already appears after an auto-save (`ConfirmationToast` exists) gives the
capability a discoverable path and makes the shake a power-user shortcut rather than the only door.
Keep the gesture — it costs nothing and delights the people who try it.

**If that is more than 1.0.5 should carry: cut the teaching, keep the gesture, and write it down as
a known-undiscoverable delight.** That is a legitimate answer, and it is better than a hint that
fires on every user's first save to explain a gesture most will never use.

*This is the one where I would most welcome your call*, because it trades directly against "do not
turn the app into a tutorial" and the toast work is real.

### 6. Merchant learning — **one inline hint, at the single moment it is true**

*Current:* nothing surfaces it. Categories simply start being right. `help.categories.body`
mentions it in a final sentence.

*The case for teaching it, which is not a discoverability case:* the user does not need to *find*
merchant learning — it is automatic, and invisible-magic is arguably the correct design. But it is
a **premium value story that is currently invisible**, and "the app gets sharper the more you use
it" is a retention argument the product makes nowhere. (The retired `tutorial.page2.headline` —
"Gets sharper with every transaction" — was the only place it was ever said, and 1.3 deletes it.)

*Proposal:* a **single** one-shot `InlineHintBubble`, fired **once ever**, at the first moment the
user *corrects* a suggested category — i.e. the first time learning actually happens. Not on save,
not on first launch. One sentence: this merchant will be remembered.

*Why this passes the attention test:* it fires at most once in a lifetime, at the exact moment the
claim becomes true, and it explains a behaviour the user is about to observe anyway. Everything
else on this list is a signpost; this is the only one where the user genuinely does not know a
thing is happening.

*Cost:* one new key ×5, one `InlineHintBubble` site, one persisted "shown" flag. Uses the existing
mechanism at a third site.

*The `usage.ever.*` flags already exist* for the receipt pre-test instrument, and the correct
marking order is documented there (§1.1 — mark *after* the save, never before). **Reuse that
pattern; do not invent a second flag convention.**

---

### What I am explicitly NOT proposing

- **No fourth coachmark step.** Three is right. Every addition is paid for by every new user.
- **No onboarding page about privacy, the widget, or Siri.** First-run should end at the first
  successful save, which is what `FirstWinView` already does.
- **No hint for splits.** Shipped and working. Leave it.
- **No hint for the mic or the alerts screen.** §0 — both already handle it.
- **No re-teaching of anything `LearnAndTipsView` covers well.** Eight articles already say most of
  this; the deficit is routing, which is what proposals 1, 2 and 4 fix.

**Net attention added across all six: two one-shot bubbles (one of them optional), one Settings
row, one section footer, and one always-on chart affordance that replaces an absence.**
That is not a tutorial.

---

## GROUP 3 — the verified defects

### 3.1 Month-end recurrence drift — both halves

Two changes, and the second is a **product decision I should not take alone**.

**Half A — the math.** Clamp the *anchor's* day-of-month into each target month, never the previous
result's. `RecurrenceType.nextDate(after:)` (`:84–86`) cannot do this: its signature receives only
the previous date and has structurally lost the anchor. Needs an anchor-aware call —
`nextDate(after:anchor:)` or an occurrence-index form (`date(forOccurrence:from:anchor:)`) —
with `nextDueDate` (`RecurrenceService.swift:133–136`) passing the anchor through. Target
behaviour, per the brief: Jan 31 → Feb 28 → **Mar 31**; Feb 29 2024 → Feb 28 2025/26/27 →
**Feb 29 2028**.

**Half B — already-drifted series: re-anchor, or leave?** Re-anchoring changes dates on rows a user
has already seen. **My recommendation: fix forward only — new anchors get correct math, existing
drifted series keep their current day.** A subscription silently moving from the 28th back to the
31st is a second unexplained change, and the user cannot tell it from the first bug. But this is
your call, and it is the reason the brief made it a separate decision.

**Anchor source.** The brief says take it from `canonicalTemplate(among:)`, not an arbitrary row.
Correct under sync — but twins are **unreachable without sync** (verified 7/7, 2026-08-10), and
sync is not in 1.0.5. Route through `canonicalTemplate` anyway: it costs nothing today and is
free correctness later.

**Tests:** one per cadence, plus Feb-29-returns-in-2028, plus a drift-does-not-accumulate case
over ≥14 months. **Do not assert process-locale strings** (recorded rule). Run via
`scripts/run-tests.sh`, and derive the suite list from the file — `grep -nE '@Suite|^struct '` —
not from the filename.

**Confirm before building:** Half B.

### 3.2 The quadratic `save()` — **RECOMMEND Option 3. Option 2 is off the table, and here is why.**

You asked specifically what batch delete would do to `.cascade` on splits. **The answer is that we
cannot reach that question, because the bulk API does not function on this container at all.**

**`delete(model:)` throws on this container. Proven, and it already cost a silent failure.**
`LargeDatasetDebugSeed.swift:93–104` records it:

```
NSCocoaErrorDomain 134060 — "Entity named:TransactionSplit not found for relationship named:category"
```

The production container is **multi-configuration** (`syncedConfig` + `localConfig`,
`SharedModelContainer.swift:256–266`), and `delete(model:)` takes no configuration, so it cannot
resolve an entity spanning two stores. It threw on **every call** from 2026-08-04 to 2026-08-08,
and both call sites caught it and `print`ed to a channel xcodebuild does not capture.

**And if that were fixed, the `.cascade` question is genuinely unknown and would fail silently.**
`Transaction.splits` is `@Relationship(deleteRule: .cascade, inverse: \TransactionSplit.parent)`
(`Transaction.swift:75–76`). Whether a SwiftData store-level delete honours a cascade rule is not
answerable from the documentation with the confidence a ship decision needs. Orphaned
`TransactionSplit` rows would be **invisible to aggregation** — `CategoryAttribution` derives from
the parent — so the failure mode is a silently growing set of unreachable rows. **Note the existing
measurement cannot answer it: splits are `nil` in every seeded case.**

Third strike: a store-level delete does not update the in-memory graph, and `DuplicateReviewView`
holds a `@Query` over exactly the rows being deleted. That is the R3 dangling-reference class this
project has already paid for.

**RECOMMEND Option 3 — rebuild each affected collection once, then delete.**

```swift
let doomed = Set(rows.map(\.persistentModelID))
for cat in affectedCategories {
    cat.transactions = cat.transactions?.filter { !doomed.contains($0.persistentModelID) }
}
// and the same for every affected Source
for tx in rows { modelContext.delete(tx) }
try modelContext.save()
```

O(deleted × collection) → O(categories × collection) = O(table). It lands the delete in **E's
condition** — nothing left to maintain — which is the state E measured at 720 ms. Stays one
transaction. Keeps `.cascade` honest. Leaves no stale in-memory state. Touches no delete rules.

**⚠️ Two corrections to the target you set.**

1. **`Source.transactions` must be detached too.** Every seeded row in the measurement had
   `source == nil` and no splits. `Source.transactions` is a second to-many with an explicit
   inverse — same maintenance, same shape. **So 49.2 s at 8k is a LOWER BOUND for the shipped app,
   not the number**, and a fix that nulls only `category` will not reach the floor on real data.
2. **720 ms is E's floor, not the expected result.** Realistic expectation is **≈0.7–1.2 s at 8k**:
   E's floor plus one linear pass over the affected collections. D is the sanity check — at 400
   categories D still came in ≈1.2 s rather than at the floor, so thinning the collection alone
   does not reach 720 ms. Nulling does. Option 3 nulls.

**Explicitly rejected — Option 1** (`tx.category = nil` per row before deleting): predicted **no
effect or worse**. It performs the same identity-removal from the same large collection, just at
assignment time. Cheap to falsify with the existing harness if you want it on the record.

**Re-measurement must seed both `source` and splits**, or it will reproduce the gap that made the
first number a lower bound. Both call sites — `TransactionResetService.reset` and the
`deleteAll` path — need the fix; measure each separately, as the existing harness already does.

**Confirm before building:** that Option 3 is the approach, and that re-seeding with sources +
splits is accepted as part of the work (it changes the measurement runtime materially — the last
run was 496 s for 2 tests).

### 3.3 `SeedService:214` — the last silent site worth doing

Category migration failure, invisible in Release, `print`-only. Same class as B3, which was fixed.
Route to `persistenceLog.error` with the `NSError` domain/code/userInfo, compiled in **both**
configurations — the shape already used at `SharedModelContainer.swift:337–339`.

`SeedService:29` and `:92` are the same file and cost one line each; take all three.

**Deliberately NOT in this pass, and named so the omission is explicit:** `DemoSeeder` (B6, six
sites) and the four §3.2 sites (`TransactionsView:213`, `DuplicateReviewView:184`,
`AddCategorySheet:287`, `GeneralSettingView:499`). B6 is demo/screenshot-only. The four already
show the user an alert — the gap is root-causability from a TestFlight report, not user deception.
Mechanical whenever they are wanted.

### 3.4 ReverseTrial — the persisted monotonic watermark

Agreed on placement: before sync, because `AppCapability.iCloudSync` is `requiresPremium`
(`FreeTierLimits.swift:93`) and this gate decides it.

**Shape:** a persisted "latest date this install has ever seen", advanced on every launch and
foreground, with `isActive` comparing against `max(now, watermark)` rather than raw `now`.

**Four decisions I need before building — this is not a one-liner and the file says so
(`ReverseTrial.swift:82–85`):**

1. **Where it is stored.** `ReverseTrialStore` is already an injected protocol (`:25–32`) — the
   watermark belongs there, keeping the math pure and testable. But the production store is App
   Group `UserDefaults` (`:118–128`), which a reinstall clears. **Same trade-off already decided
   for `reverseTrialStartDate` (`:113–117`): Keychain survives deletion but would silently deny a
   legitimate device restore.** Recommend **matching the existing decision** — App Group, not
   Keychain — so the two cannot disagree.
2. **What advances it.** Launch and foreground are the natural hooks (`RootView` already calls
   `access.refresh()` on `.active`, `:84`, `:98`). Confirm nothing else should.
3. **How large a backward jump is tolerated.** A device crossing time zones or correcting NTP drift
   moves backward by seconds legitimately. A strict `max()` is correct and needs no tolerance — but
   confirm we are not trying to be clever here.
4. **Reinstall semantics.** Cleared watermark + cleared start date = a fresh trial. That is the
   **existing accepted abuse ceiling** ("one extra fortnight", `:113–117`), and the watermark does
   not change it. Confirm that stays accepted.

**Scope discipline:** this is a *gate* fix. It must not become a sync-readiness project. No stored
value crosses a store boundary, and there is no schema change.

**Confirm before building:** decisions 1–4.

---

## Proposed execution order

Sequenced so nothing is done twice, and so the two string passes collapse into one.

| Step | Work | Blocked on |
|---|---|---|
| 1 | **1.1** App Store ID | — *(ready now)* |
| 2 | **§0.1** delete the two stale mic claims | — *(ready now, zero behaviour change)* |
| 3 | **3.3** `SeedService` ×3 | — *(ready now)* |
| 4 | **1.2** remove "Restart onboarding" + dead `requestReplay()` + vestigial `RootView` reads | your call: remove vs fix |
| 5 | **1.3** delete 55 string entries + update the baseline test | after 4 (same strings pass) |
| 6 | **G2** the agreed discoverability set | your selection; +5 keys folds into step 5's arithmetic |
| 7 | **3.1** recurrence drift | your call on Half B |
| 8 | **3.2** quadratic save + re-measurement | approach confirmed; longest task |
| 9 | **3.4** ReverseTrial watermark | decisions 1–4 |

Steps 1–3 need no decision from you and can start immediately.

## Open decisions, collected

1. **1.2** — remove the button, or fix it? *(recommend remove)*
2. **1.3** — take the 3 extra `tutorial.*` orphans too? *(recommend yes; 55 entries, baseline → 754)*
3. **G2** — which of the six, and is the chart affordance (§3) in or deferred? *(it is the only one touching the crash surface)*
4. **G2 #5** — shake-to-undo: give undo a visible home, or cut the teaching and keep the gesture undocumented?
5. **3.1** — re-anchor already-drifted series, or fix forward only? *(recommend forward only)*
6. **3.2** — Option 3 confirmed, and re-seeding with sources + splits accepted?
7. **3.4** — the four watermark decisions.

---

## Recorded this pass (documentation only, no code)

- `DESIGN_ICLOUD_SYNC_1_0_4.md §2.1` — count corrected from "five" (listing four) to the verified
  **ten** live keys, with `privacy.claim.no_cloud_account` and `privacy.claim.no_data_uploaded`
  added, the true-under-sync set separated out, and `tutorial.page3.bullet1` reclassified as dead.
- `FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md §C` — MVP scope struck and replaced with the verified
  three-item delta (annual/custom period scope · period-over-period comparison · a PDF that carries
  the analysis), with the four already-shipped bullets mapped to the screens that ship them and the
  `ImageRenderer` cost warning attached.

---

## FIRST ITEM AFTER 1.0.5 SHIPS — collapse the CSV import orchestration onto the actor

**Decided 2026-08-13. Explicitly out of 1.0.5, explicitly first after it.** Recorded here with its
reason attached, because an item deferred without one drifts until somebody re-derives it from
scratch — and the last person to look at this code will not be the next one.

**The change.** Delete `CSVImportService.importMappedCSV` and `importCSV`; retarget their tests at
`CSVImportActor.importMappedData` / `importData`.

**Why it is not in 1.0.5.** The user-facing harm is already gone: partial-state disclosure shipped in
this release (`PartialImportFailure` → `data.import.partial.format`), so an import that stops
mid-file now says how many rows landed and that re-importing is safe. What remains is correctness
hygiene with a real migration cost — **13 tests become `async` and must construct a `@ModelActor` off
the MainActor** (`CSVImportActor.swift:10–15`: it adopts the executor of whatever builds it, so a test
that builds it on the main actor silently tests the wrong path and proves nothing). A polish release
is the wrong place to absorb that.

**Why it must not drift, stated as the standing cost of leaving it:**

> **While two orchestrations exist, the next person edits the wrong one, and every future CSV test
> exercises the copy the app never runs.**

That is not a prediction. It is the current state: `CSVImportActor` has **zero** test references
today, and the 13 tests that look like import coverage all sit on the unshipped half. The duplication
is faithful *today* only because someone has been maintaining both by hand; the one place that
discipline already lapsed is the batched save, and that lapse inverted the failure semantics of the
whole import.

**Sequencing constraint.** This must land **before** any further import work. Tier-3 (PDF/OCR
statement import) is sketched against the same service, and adding a third caller on the
untested-orchestration side would set the duplication in concrete.

**Commission the migration, do not just perform it.** Before trusting the retargeted tests, construct
the actor on the MainActor **deliberately** and confirm the new tests can tell the difference — the
same negative control used to commission `run-tests.sh` exit-1 and exit-3 as a pair. A migration that
moves 13 tests onto a path where they silently measure nothing would convert real coverage into
theatre, which is worse than the duplication it removes.

**What to assert once collapsed, in priority order:**
1. A save failure mid-import: what is committed, what the user is told, and what a retry does.
2. Batch-boundary correctness at exactly 99, 100 and 101 rows.
3. `Task.isCancelled` behaviour — neither loop honours it today, so a cancelled import runs to
   completion. Fix and assert together.

Full working: `AUDIT_CSV_IMPORT_DUPLICATION_2026-08-13.md`.
