# AUDIT — do the tests guarding gates, money and identity actually discriminate?

**Date:** 2026-08-08 · **Method:** manual mutation testing. For each invariant: write the
WRONG implementation, run only the suites that claim to guard it, record whether they go red,
revert. **No production code was changed by this audit** — every mutation was reverted and the
tree verified clean after each batch.

**Origin.** `clockMovedBackwardsStaysActive` passes with and without a clock clamp in
`ReverseTrial.isActive`. It never discriminated. A test that passes under both the correct and
the incorrect implementation pins nothing, and reads as coverage. This sweep asks how far that
shape spreads.

**Deliverable is the list. Nothing here is fixed.**

---

## 0. Result

13 mutations across 3 categories. **One live non-discriminating test. One unreachable branch.
One inconclusive.** The rest discriminate.

| # | Mutation | Category | Verdict |
|---|---|---|---|
| G1 | `canAdd`: `currentCount < limit` → `<=` (cap lets one extra through) | gate | **RED** ×3 |
| G2 | `canAdd`: premium bypass removed | gate | **RED** ×2 |
| G3 | `canAdd`: uncapped default `!requiresPremium` → `true` | gate | GREEN — **unreachable**, see §2 |
| G4 | `isPremium`: drops the reverse-trial term | gate | **RED** ×2 |
| G5 | `isActive`: `now <` → `now <=` (active exactly at expiry) | gate | **RED** ×1 |
| G6 | `isAllowed`: every paid feature becomes free | gate | **RED** ×2 |
| G7 | `duration`: 14-day trial silently runs 15 days | gate | **RED** ×4 |
| G8 | `.csvImport` moves to the free tier | gate | **INCONCLUSIVE**, see §3 |
| M1 | `CategoryAttribution`: over-sum truncation removed | money | **RED** ×2 |
| M2 | `SafeToSpend.remainingCents`: sign flipped | money | **RED** ×13 |
| M3 | `Money.format`: 10× scale error | money | **RED** ×2 |
| I1 | CSV UUID dedup disabled (re-import duplicates everything) | identity | **RED** ×2 |
| I2 | `notificationID`: twins no longer share one identifier | identity | **GREEN ×88** ← the finding |

The money and identity invariants are in good shape. `M2` is the strongest result in the sweep:
13 tests across 3 suites catch a sign flip, and the catch is concentrated in
`ProactiveAlertPolicyTests`, which is where the number reaches a user.

---

## 1. THE FINDING — `I2`: the twin notification identifier is load-bearing and pinned by nothing

`RecurrenceService.notificationID(for:)` carries this comment at its only call site:

> Keyed by `uuid`, which means TWINS SHARE ONE IDENTIFIER — and that is load-bearing, not an
> oversight.

Replace it with `UUID()` so twins each get their own identifier — destroying exactly the
property the comment calls load-bearing — and **88 tests across five suites pass**:
`RecurrenceTwinCollapseTests`, `RecurrencePromptResolutionTests`, `RecurrenceEditTests`,
`RecurrenceWatermarkOrderingTests`, `RecurrencePeriodLabelTests`.

**Why it is untestable as written, and why that is the same shape as F3.** `notificationID` is
`private` and reachable only through `scheduleNotification` / `cancelNotification`, both of
which call `UNUserNotificationCenter.current()` directly. There is no seam, so no unit test can
observe the identifier. `RecurrenceTwinCollapseTests` tests twin collapse in the STORE, which
is a different property from twins sharing one *notification*.

The consequence if it regresses: a user with twin templates gets two reminders for one charge,
and cancelling resolves only one of them. Silent — nobody reports a duplicate reminder as a bug
against the identifier.

**Fix shape (not applied):** the same extraction already used for
`RecurrenceService.notificationContent` in 9b9d8c5 — make the identifier internal, or route
scheduling through the existing `NotificationScheduling` protocol that
`ProactiveAlertScheduler` already defines, and assert both twins produce one identifier.

---

## 2. `G3` — GREEN, but it is dead code rather than a test gap

`AccessLogic.canAdd`'s uncapped branch (`guard let limit = … else { return !requiresPremium }`)
can be flipped to `return true` with 72 tests still passing. That branch is **unreachable in
production**: `canAdd` has exactly three call sites (`CapGate:29`, `:36`,
`CategoriesSourcesView:143`, `:147`) and every one passes `.addAccountBeyondFreeCap` or
`.addCustomCategoryBeyondFreeCap` — both of which have a `freeLimit`, so the `guard` never
falls through.

The gate that actually decides uncapped premium features is `AccessManager.isAllowed`, and that
one **is** pinned — `G6` is RED. So this is not a hole in the free/paid line; it is an untested
defensive branch. Deleting it is more honest than testing it.

---

## 3. `G8` — inconclusive, and my classifier lied about it

Reported RED in 4 seconds with zero named failing tests. That is a compile failure, not a
caught mutation: my edit removed a `case` label and left the `switch` malformed. The driver
classified any `** TEST FAILED **` as RED, and a build failure prints exactly that.

**Not counted as a pass.** The free/paid line's membership (`AppCapability.requiresPremium`)
therefore remains unmeasured by this sweep. `CapabilityMatrixTests` is named "The free/paid
line" and is the suite that should catch it; whether it does is still an open question.

---

## 4. The sweep audited itself, and failed the first time

`G5` and `G7` were both GREEN on the first run — a trial silently running 15 days, caught by
nothing across 42 tests. That would have been the headline finding. **It was false.**

The tests that guard trial arithmetic live in a suite called `ReverseTrialMathTests`, inside
`AccessManagerTests.swift`. I passed `-only-testing` a list of suite names that did not include
it. `xcodebuild` does not warn when an `-only-testing` filter matches nothing relevant — it
just runs fewer tests and reports success.

Re-run with the correct list: `G5` RED (`exactlyAtExpiryIsOver`), `G7` RED ×4 (including
`daysRemainingCountsDown`, which asserts against the literal `14`).

So the audit reproduced, in its own harness, the exact defect it was written to find: a green
result that pins nothing because the thing that would have failed was never run. **Rule for any
future sweep: derive the suite list from the file that contains the code's tests, never from the
filename.**

Note also that `AccessManagerTests.swift` contains nine `@Suite`s with names unrelated to the
filename. `-only-testing:FinanceTrackerTests/AccessManagerTests` does not run most of that file.

---

## 5. What was NOT swept

Stated so the coverage of this audit is not overclaimed:

- **Identity:** `transactionIdentity` (the day-granular content heuristic), `DeletedModelIdentifier`,
  `ImportDuplicateFlag`'s badge semantics.
- **Money:** `Money.parseCents` (only `format` was mutated), the QuickAdd amount tokenizer,
  CSV decimal-convention handling, `PaceMetric`.
- **Gates:** `AppCapability.requiresPremium` membership (§3), `CapGate`'s paywall-raising
  behaviour, `AccessManager`'s Combine wiring.

Each is a candidate for a second sweep. The method costs roughly 3 minutes per mutation.

---

## 6. The dimension this sweep was missing — added 2026-08-13

This audit asked, of every test: **"does it discriminate a wrong implementation?"** That is a
necessary question and it is not a sufficient one. It never asked:

> **"Does any live call site reach the code this test covers?"**

A test can pass the discrimination bar perfectly and still be worthless, because it is a test of
something that is not the product. `requestReplay()` was the worked example: a **passing**,
**discriminating** test on a path the app never took.

The follow-up sweep is `AUDIT_TEST_REACHABILITY_2026-08-13.md` — 6 real findings, the worst being
that **the shipping column-mapped CSV import orchestration has no test that reaches it.**

### 6.1 The blind spot in the reachability rule itself — read this before automating it

The obvious implementation of the new dimension is *"flag production symbols with zero production
callers."* **That rule silently passes the second-worst finding in the report.**

`CSVImportService.importCSV` **has** production callers, so a zero-callers rule clears it. Its only
callers are `DuplicateReviewDebugSeed.swift:47,48` — **a DEBUG-only QA seam.** The path a user's build
executes is `CSVImportActor.importData`. It was found by hand, not by the sweep.

> **A reachability rule that counts debug-only callers as reachable will keep missing exactly this
> shape** — and this shape is worse than a dead function, because the symbol looks alive, has real
> callers, has real tests, and none of it ships.

**The question is not "is it called?" It is "is it called on a path a user's build can execute?"**
Any automation of this dimension must treat callers inside `#if DEBUG`, test targets, QA seams and
`--launch-argument`-gated code as **non-callers**, and must resolve that recursively: a release caller
that is itself only reachable from DEBUG code is also not a caller.

**Two further traps, both paid for once already:**

- **Trailing-closure calls are invisible to a `name(` pattern.** `SaveActionGate.submit` came back as
  a candidate because all five real call sites are `saveGate.submit { … }`. An unverified run of the
  script would have reported a **live double-submit guard** as dead code — the sweep would have
  argued for deleting money-protecting logic. Hand-verify every candidate.
- **Some symbols are unreachable from the app on purpose and are correct.**
  `LocalizationProbe.*` exists inside the app module precisely so tests measure the app's bundle
  rather than the test bundle's missing `.lproj`. A sweep that "fixes" those breaks the localization
  premise tests. See §4 of the reachability audit for the full keep-list.
