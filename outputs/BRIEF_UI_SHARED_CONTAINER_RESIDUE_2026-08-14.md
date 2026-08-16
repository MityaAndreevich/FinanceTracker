# UI suite: what carries between classes in the shared container — investigation

**Status: INVESTIGATION. Not a fix, and explicitly NOT a release gate.** Filed as its own item on
2026-08-14 because this is the **third** time non-hermetic shared-container state has produced a
false picture, and the first two were each treated as a one-off.

**Prior instances**
1. `LargeDatasetDebugSeed`'s contamination — 8 000 seeded rows outlived their run, so every later
   test launched against them until someone erased the simulator, which is what made the
   2026-08-03 suite comparison meaningless (`LargeDatasetDebugSeed.swift:20–47`, and the fix it
   documents).
2. **The 25-vs-2 artifact.** ⚠️ Named here as the founder named it; **I could not find its
   write-up in `outputs/`.** Needs a pointer before this list is cited — an unlocatable precedent
   is exactly the kind of claim this project's citation protocol exists to catch.
3. This one.

---

## 1. The symptom

Two full-suite runs of an identical working tree, 2026-08-13/14, `scripts/run-tests.sh`, iPhone 17
Pro, `-parallel-testing-enabled NO`. **The unit target was 1025/1025 both times.** All failures were
in `FinanceTrackerUITests`, and the failing SET changed between runs:

| run | UI result | failed |
|---|---|---|
| 1 | 42 passed, 2 failed | `EditPresentationInterleavedTests.test_editAfterQuickAddInsert_stillOpensEditor` — *"no rows (demo seed missing)"* · `SecondTransactionCrashTests.test_savingThreeConsecutiveTransactions_appStaysAliveAndReturnsToDashboard` — *"Save button missing for entry #1"* |
| 2 | 41 passed, 3 failed | both of the above, **plus** `EditAtScaleReproTests.test_seededRowTap_opensEditor` — *"Transactions list never showed rows"* |

Each failing class **passes in isolation** (`EditPresentationInterleavedTests` 3/3, exit 0;
`SecondTransactionCrashTests` 4/4, exit 0). So the failure is a property of the run, not of the test.

## 2. The order evidence — 2 of 2, not a coincidence

Reconstructed from run 2's execution order. Both failing NON-scale classes are immediately preceded
by a class that seeds 8 000 rows:

```
BulkDeleteStallMeasurementTests   (--seed-large-dataset)   passed
DuplicateReviewFlowTests                                   passed
EditAtScaleReproTests             (--seed-large-dataset)   1 of 5 FAILED
EditPresentationInterleavedTests  (--demo-mode, no scale)  FIRST test FAILED, rest passed
...
SearchRecomputationRegressionTests (--seed-large-dataset)  passed
SecondTransactionCrashTests        (no scale, no demo)     FIRST test FAILED
```

The four scale-seeding classes are `BulkDeleteStallMeasurementTests`, `EditAtScaleReproTests`,
`SearchRecomputationRegressionTests`, `MainThreadHangScaleTests`. Alphabetical class order puts
`EditAtScale…` directly before `EditPresentationInterleaved…`, and `SearchRecomputation…` directly
before `SecondTransactionCrash…`.

**The pattern that names the mechanism: in each case the FIRST test of the following class failed
and its siblings passed.** A one-shot effect, consumed by the first launch after a scale run.

## 3. The mechanism — read from code, matching the symptom on every point

`ContentView.swift`'s launch `.task` runs these in one sequence:

- **line 194–195** — `DemoSeeder.resetAndSeedDemoData(...)` when `--demo-mode`.
- **line 236** — `LargeDatasetDebugSeed.purgeIfLeftOver(...)`.
- **line 240** — `LargeDatasetDebugSeed.seedIfRequested(...)`.

`purgeIfLeftOver` fires when the launch did **not** request scale and the marker
`debug.largeDatasetSeed.applied` is set (`LargeDatasetDebugSeed.swift:75–86`). What it calls is
`wipeLedger` (`:125–133`), and **`wipeLedger` is unconditional**: it fetches every
`TransactionSplit` and every `Transaction` and deletes them.

Two consequences, and they are different failures:

1. **The purge runs AFTER the demo seed, in the same launch.** So on the first `--demo-mode` launch
   following any scale run, the demo rows are written at line 195 and deleted at line 236. The test
   then waits for rows that were seeded and then removed. → *"no rows (demo seed missing)"*.
   The comment at `ContentView.swift:218–232` reasons carefully about the order of the three
   *DEBUG* row-writing seams; the demo seed sits above that block and was not in that analysis.
2. **The purge deletes ~8 000 rows on the main thread, at launch.** Any first assertion in that
   launch races a main-thread delete of a full seeded ledger. → *"Save button missing for entry #1"*
   at an 8 s timeout, in a class that never asked for scale and seeds nothing.

This also covers the `EditAtScaleRepro` failure without the purge: that class DOES request scale, so
`seedIfRequested` resets and rewrites 8 000 rows in the same launch — slow for the same reason, and
its 5 tests split 4-pass / 1-fail across the timeout boundary.

**Why it flickers rather than failing every time:** every symptom is a timeout race against a
delete/insert of 8 000 rows, so it lands on either side of the boundary depending on machine load.
**Why isolation is green:** run one class alone and no scale-seeding class precedes it, so the
marker is never set and the purge never fires.

> ### ✅ MEASURED 2026-08-15 — **45 764 ms.**
>
> `PurgeCostMeasurementTests.test_wipeLedgerCost_at8kRows` runs `wipeLedger`'s body verbatim over a
> categorised 8 000-row store: **45.8 seconds.** (Independently consistent with the 44.7 s measured
> on the structurally identical path in `BRIEF_BULK_DELETE_P1_P2_P3.md`.)
>
> That settles item 2. Every timeout in the affected tests is **8–20 s**, so a launch that triggers
> the purge cannot possibly satisfy them: the app is unresponsive for ~46 s while a to-many inverse
> is maintained row by row. It is not a race that sometimes loses — it is a race that cannot be won,
> and the tests that "pass" are the ones whose launch does not trigger it.
>
> **This is a DEBUG-seam cost. It is identical on every tree**, which is why the same failures appear
> on the working tree and on clean HEAD, and why they are independent of any product diff.

Superseded inference, kept for the record: before the measurement above, this section argued the
cost from the shape of the path (delete loop + one `save()` over a categorised 8 000-row store) and
its match to the symptom, and said so explicitly rather than asserting it. The measurement confirmed
it at 45.8 s.

## 3.1 The attribution measurement (6 runs, 2026-08-14)

Run to decide whether the red pre-existed an uncommitted change, and designed so a single lucky
green could not settle it: **UI target only, 3 runs per tree, interleaved W,C,W,C,W,C**, same
simulator (`iPhone 17 Pro`), **erased before every run in both arms**, one `-only-testing` filter so
order is xcodebuild's default and identical throughout, identical `run-tests.sh` in both arms. The
unit target was not re-run (1025/1025 twice already).

| run | tree | exit | executed | failed | failing set |
|---|---|---|---|---|---|
| W1 | working | 1 | 44 | 4 | editAfterQuickAddInsert · **switchLanguageThenEdit** · **editAmountFromTransactionsList** · savingThreeConsecutive |
| C1 | clean `051f493` | 1 | 44 | 3 | seededRowTap · editAfterQuickAddInsert · savingThreeConsecutive |
| W2 | working | 1 | 44 | 3 | seededRowTap · editAfterQuickAddInsert · savingThreeConsecutive |
| C2 | clean | 1 | 44 | 3 | *(same three)* |
| W3 | working | 1 | 44 | 3 | *(same three)* |
| C3 | clean | 1 | 44 | 3 | *(same three)* |

**Per-test failure rate, working / clean:**

| test | working | clean |
|---|---|---|
| `EditPresentationInterleaved.test_editAfterQuickAddInsert_stillOpensEditor` | 3/3 | 3/3 |
| `SecondTransactionCrash.test_savingThreeConsecutive…` | 3/3 | 3/3 |
| `EditAtScaleRepro.test_seededRowTap_opensEditor` | 2/3 | 3/3 |
| `EditPresentationRepro.test_switchLanguageThenEdit_opensEditor` | 1/3 | 0/3 |
| `EditTransactionFlow.test_editAmountFromTransactionsList…` | 1/3 | 0/3 |

**Six runs red on six, both arms.** The red is not the working tree's doing in any run-level sense.
But two tests failed on the working tree and never on clean HEAD, both in W1, and the pre-registered
rule for this experiment treats *any* such test as attribution found ⇒ **stop, do not commit.** That
is the recorded outcome; the rule was fixed before the data was seen and is not being reinterpreted
after it.

What the data also shows, without softening the above: both outliers carry **this section's exact
signature** — *"General row missing"* and *"no transaction rows in the list (demo seed missing / out
of period)"* — in demo-mode edit classes that follow scale seeders, i.e. a wider spill of the same
one-shot effect rather than a new failure kind. And the noise runs both ways: `seededRowTap` failed
**3/3 on clean and 2/3 on working**, which under a mirrored reading would "attribute" a failure to
the absence of the change. At n=3 per arm the per-test rates are not separable; the run-level result
(6/6 red, same three classes dominating) is the part that is measured.

**The cheap next experiment**, if attribution needs closing: 3 more runs per arm, same protocol,
and ask only whether `switchLanguageThenEdit` or `editAmountFromTransactionsList` ever fails on
clean HEAD. ~90 minutes, and it is the only question the first six runs left open.

## 4. What would settle it

1. **Measure `wipeLedger` at 8 000 rows** on the main thread. If it is sub-second, item 2 above is
   wrong and only the seed-then-purge ordering survives.
2. **Provoke it directly**: run `-only-testing:FinanceTrackerUITests/EditAtScaleReproTests` and
   `-only-testing:FinanceTrackerUITests/EditPresentationInterleavedTests` in ONE invocation, in that
   order. Prediction: the first `EditPresentationInterleaved` test fails and the rest pass. Run the
   second class alone and it is green (already observed, 3/3). ⚠️ Two `-only-testing` filters make
   the zero-tests guard a TOTAL — verify both suites report non-zero on their own first.
3. **Assert the ordering property in code**, not in a comment: the demo seed and the purge cannot
   both be allowed to touch the ledger in one launch with the purge second.

## 5. What it invalidates

Nothing shipped. This is `#if DEBUG` seam behaviour and cannot occur in a Release build. What it
corrupts is **evidence**: any UI-suite result read as a statement about the app when the real cause
was a launch fighting an 8 000-row delete. That includes the two red full-suite runs above, which is
why they were not treated as a verdict on the working tree.

## 6. The standing lesson, since this is the third instance

Each instance was a different seam, and each was fixed locally: the seed reset, the purge added, the
`--reset-accounts` seam added. The recurring part is not any one seam — it is that **UI test classes
share one app container and one `UserDefaults` domain, and every seam that writes to either is a
channel between classes that nothing declares.** The next fix should be the property, not the
instance: state what a launch is allowed to inherit, and enforce it where a test can see it fail.

---

## 7. Outcome (2026-08-15)

**The ordering half is fixed and confirmed fixed.** `LargeDatasetDebugSeed.purgeIfLeftOver` moved to
the TOP of `ContentView`'s launch `.task`, above every seeding path. Measured effect: the
*"no rows (demo seed missing)"* failure — `test_editAfterQuickAddInsert_stillOpensEditor`, which had
failed **3/3 on both trees** across six controlled runs — disappeared from both arms.

**The cost half is measured and NOT fixed: 45.8 s.** Both remaining failures are launches that pay
it — `SecondTransactionCrashTests` (its launch triggers the purge; 8 s timeout) and
`EditAtScaleReproTests.test_seededRowTap` (requests scale, so `seedIfRequested` resets = wipe 8 000 +
insert 8 000 in the same launch). The red is therefore **understood and tree-independent**, which is
what discharged the commit gate.

**Still not fixed, and deliberately not fixed here:** the seam remains slow. Options, none taken yet:
delete rows off the main thread; drop the `Category.transactions` inverse during the wipe (measured
at 44.7 s → 0.72 s on the analogous path in `BRIEF_BULK_DELETE_P1_P2_P3.md`); or have the purge
delete the store FILE rather than walk the object graph. That is its own change with its own
verification, not a rider on a release fix.

**One failure is still unexplained.** `BreakdownOtherExpandTests.test_otherRow_expands_andTailCategoryDrillsDown`
("Breakdown segment missing") failed once, on the working arm, as the FIRST test after an erase —
where no marker exists, so no purge runs and this brief's mechanism cannot apply. It passed 6/6 in
the controlled experiment and every other run. Recorded rather than absorbed: it is one observation,
it is not explained by anything here, and calling it "the same flake" would be exactly the
absorb-into-a-known-cause move this brief exists to argue against.

---

## 8. Correction (2026-08-16): the ordering fix removed one CAUSE, not the SYMPTOM

The pre-submission full-suite run for 1.0.5 failed `test_editAfterQuickAddInsert_stillOpensEditor`
again, with the identical message — *"no rows (demo seed missing)"*. §7 said that failure was fixed.
That claim was true of the runs it was based on and **too strong as stated**, so it is corrected here
rather than left standing.

**The symptom has two causes, and only one was fixed.**

- **Cause A — deletion (FIXED).** The purge ran after the demo seed and deleted it. Removed by moving
  the purge above every seeding path, and the controlled comparison showed exactly that: the failure
  went from 3/3 on both trees to passing on both.
- **Cause B — starvation (NOT fixed, and now the live one).** The purge is 45 764 ms. It now runs
  FIRST, so the demo seed executes *after* it. A test that waits 15 s for rows finds none — not
  because they were deleted, but because a 46-second delete is standing in front of them.

So the reordering changed *why* the rows are missing without changing *whether* the test can see
them, whenever the purge fires on that launch. **The cost remedy is not only what makes the suite
trustworthy — it is the remaining cause of this specific failure.**

Same one-shot signature as always, in the 1.0.5 run: `EditAtScaleReproTests` (5/5 passed, leaving
8 000 rows and the marker set) → `EditPresentationInterleavedTests` **first test failed, both
siblings passed**, the marker having been consumed by that launch.

Why it passed twice after the fix and failed here: those runs were UI-target-only on a freshly erased
simulator; this one ran the full suite on a different device that carried state from the 1.0.5
fixture capture. Which launch pays the purge depends on which class last set the marker and which
non-scale launch consumes it first — i.e. on exactly the shared-container state this brief is about.
Recorded as observed, not resolved.

**Not a release blocker, and here is the basis rather than the assertion:** `LargeDatasetDebugSeed`
is `#if DEBUG`, both call sites are inside `#if DEBUG`, and `--seed-large-dataset` is **absent from
the Release binary's symbols**. No user can reach this path. The unit target was 1036/1036 in the
same run.

---

## 9. The fixture corpus is now a source of the same problem

Recorded 2026-08-16, because the next confusing run should not be diagnosed from scratch.

`scripts/capture-store-fixture.sh` cannot be hermetic — capturing what a binary writes means running
that binary on a real simulator. It therefore does two things this brief has spent a month tracking:

1. **It erases a device chosen by NAME, without asking.** Anything else using that simulator — a
   staged repro, a run in flight — is destroyed silently.
2. **It leaves the device non-pristine**: the old app version installed, an App Group store holding
   the demo seed, and whatever UserDefaults that launch wrote. Any run started afterwards inherits
   all of it.

**This is what separated the two green post-fix UI runs from the red 1.0.5 full-suite run.** The
green ones erased the simulator first, by protocol. The red one ran on the device the 1.0.5 fixture
capture had just left behind, and did not erase.

⚠️ **One correction to how this was described to me, because the difference matters for diagnosis:**
the capture does **not** leave 8 000 rows behind. It leaves a **33-row demo store** plus an installed
app and its defaults; the 8 000 rows in the failing run came from the suite's own scale classes
(`EditAtScaleRepro` and friends), as they always have. The capture's contribution is that the device
was **not pristine and not erased**, which is enough — the marker/store state that decides *which*
launch pays the 46-second purge is exactly what "not pristine" perturbs. Attributing the rows to the
capture would send the next investigator looking for an 8k seed in a script that has none.

**The rule that follows:** erase the simulator before any test run that follows a capture. A green
run on an erased device and a red run on a captured-on device are not the same experiment, and the
difference does not appear anywhere in the output. The same warning is now in the script's header,
where someone about to run it will actually meet it.
