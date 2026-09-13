# STATE — the one page where status lives

**Derived 2026-09-12 from the sources, at HEAD `537e220`.** Every row was re-read today. No row was
written from memory, including mine.

---

## THE RULES THIS FILE IMPOSES

1. **If a decision is not in STATE.md, the decision does not exist.** A conclusion carried in a
   session, a chat message, or a person's head is not a decision. It is a recollection, and this
   project has now watched recollection invent a veto and resolve an open test.
2. **A status line must cite where it was verified — file AND line.** No status from memory, ever.
   Not the founder's, not Claude's, not a previous session's. A pointer a reader cannot open is not
   evidence; it is a claim, and this project has a rule about claims.
3. **The 124 documents in `outputs/` remain the evidence archive. They no longer carry status.**
   Where a document's own header contradicts this file, this file is later and wins — and the
   contradiction gets a row in §4 rather than a silent edit.
4. **A superlative is a separate claim from the thing** (`CLAUDE.md`, citation protocol §5). "Sync is
   blocked" and "sync is the largest item on the roadmap" verify independently.

---

## THE ACCEPTANCE TEST — pre-registered 2026-09-12, BEFORE this file was written

This file exists to fix a failure of memory, so it is testable the way the guards are.

> **ACCEPTANCE:** hand `STATE.md` to a session with NO context and ask three questions. Correct
> answers in **under a minute, reading nothing else**:
>
> 1. Is family / shared access decided or open? What blocks it?
> 2. Has the receipt-input pre-test been resolved? What would resolve it?
> 3. Which defects are reachable by a user in the currently shipped version?
>
> These three are chosen because **all three were answered WRONG from memory in the week of
> 2026-09-08**, with confidence. If the file cannot carry them, it has not solved the problem it was
> written for.

**§0 answers them directly.** That is the design, not a summary: a file that requires reading a
table to answer its own acceptance test has already failed the one-minute clause.

---

## 0. THE THREE ANSWERS

**Q1 — Family / shared access: OPEN. No decision has been taken.**
`RESEARCH_FAMILY_ACCESS_2026-08-12.md:3` — *"**Status: RESEARCH ONLY. No design, no code, no
decision taken.**"*
What blocks it is **architecture, not product**: `:302` — *"SwiftData does not support the shared
database — and this is the veto"*, and `:388` — *"**But both still sit behind §3.2's veto.**
Expressible in CloudKit ≠ available in SwiftData."* The document **recommends** refusing it in the
1.0.x line (`:412`) but §5 is written in the conditional — *"WHAT I WOULD BUILD, AND WHAT I WOULD
REFUSE"* (`:399`) — and the header at `:3` governs. See row F1 and the contradiction at §4.1.

**Q2 — Receipt-input pre-test: NOT RESOLVED. It is registered and unread.**
`budget-crab-internal/working-docs/DECISION_RECEIPT_INPUT_PRETEST.md:4` — *"**Status:** registered,
not yet resolved."* The §5 results table (`:199–212`) is **empty**.
What would resolve it: recording **T0**, then reading N / S / S6 at T0+90 and T0+180 against the
thresholds at `:143–145` and `:153`. **Both preconditions are already met and T0 has passed
unrecorded** — see row R1, which is the actionable finding on this item.

**Q3 — Defects reachable by a user in the currently shipped version.**
The currently shipped version is **1.0.4 build 8**; 1.0.5 build 10 is in review
(`PLAN_TUTORIAL_AND_HELP.md:170` — *"1.0.5 build 10 is in review"*). So **every fix that landed in
build 9 or build 10 is NOT yet in users' hands.** Verified by `git merge-base --is-ancestor` against
tag `v1.0.4-build8` on 2026-09-12:

| defect | in 1.0.4 build 8? | reachable by a user today |
|---|---|---|
| Migration floor strands 1.0.0-era stores | fix `8c748b7` **NOT in build 8** (lands build 9) | **YES — live in the field since 1.0.3 became available 2026-07-29** (`BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:98`) |
| Import amount-cap asymmetry / aggregate overflow | fix `1b6be14`, `c2461b3` **NOT in build 8** (land build 10) | **YES**, via a hand-made or malformed CSV (`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:234`) |
| PDF export clips amounts | fix `f7dde93` **NOT in build 8** (lands build 10) | **YES** |
| `VoiceInputService` teardown `abort()` | never fixed, in any build | **YES on the code's reading** — `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:135`: *"it is reachable by opening Quick Entry and closing it"*; but `:176` — *"Not claimed that this has ever crashed a user's device."* |
| 14 remaining overflow expressions (`AnalyticsSeries` et al.) | never fixed | **YES** — `DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:202` — *"Analytics still traps on a ledger the dashboard has just told the user is otherwise fine."* |
| V2 migration sentinel disconnects the rollback ladder | present in build 8 | **NO — latent.** It fires only when a V2→V3 migration runs, and V3 has not shipped. `DEFECT_V2_MIGRATION_SENTINEL.md:26` |

Full table with regression-test columns, plus 30-odd defects that were described in AUDIT
documents and never filed anywhere: `outputs/DEFECT_REGISTER.md`.
Which money-touching surfaces have **zero tests**: `outputs/COVERAGE_MATRIX.md`.

---

## 1. SHIPPED-VERSION FACTS (everything in Q3 depends on these)

| fact | value | evidence |
|---|---|---|
| Currently available on the App Store | **1.0.4 build 8** | `PLAN_TUTORIAL_AND_HELP.md:20` (a real App Store user is on it), `:170` (1.0.5 b10 is in review) |
| In review | 1.0.5 build 10 | `PLAN_TUTORIAL_AND_HELP.md:170`; `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:204` |
| Working tree version | 1.0.5 (10) | `FinanceTracker.xcodeproj/project.pbxproj:477`, `:466` |
| 1.0.0 released | 2026-07-10 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:101` |
| 1.0.3 available | 2026-07-29 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:98` |
| **1.0.4 available** | **NOT RECORDED ANYWHERE** | see row R1 — this blank is load-bearing |
| Suite constant | `EXPECTED_TOTAL_RUN=1113` | `scripts/run-tests.sh:192` |

---

## 2. THE TABLE

`status ∈ decided-build · decided-skip · open · blocked · awaiting-measurement`
Evidence is the document **and line** that holds the detail, never a summary of it.

### Features and programmes

| id | item | status | blocked by | evidence |
|---|---|---|---|---|
| **F1** | **Family / shared ledger** | **open** — no decision taken | SwiftData cannot use the CloudKit shared database; and it sits behind private sync, which has two unbuilt prerequisites of its own | `RESEARCH_FAMILY_ACCESS_2026-08-12.md:3` (status) · `:302–321` (the veto) · `:382` (candidate 5 is the only model that gives privacy AND fits CloudKit) · `:388` (candidate 5 is still behind the veto) · `:412–415` (recommends refusing it in the 1.0.x line) · `:419` (*"That is judgement, not evidence"*) |
| **R1** | **Receipt / screenshot OCR** | **awaiting-measurement** — and **the clock is running unrecorded** | Nothing. Both preconditions are MET; what is missing is that **T0 was never written down** | pre-test `:4` (registered, not resolved) · `:103` (`T0 = ____________`, still blank) · `:199–212` (empty results table) · preconditions verified below |
| **S1** | **iCloud sync (private CloudKit)** | **blocked** | (a) the rollback ladder — see L1–L3; (b) the recurrence watermark must move into the synced model | `DESIGN_ICLOUD_SYNC_1_0_4.md:3` (*"**Status: DESIGN ONLY.**"*) · `:539–540` (*"a prerequisite, not an option"*) · `PLAN_RECURRENCE_SYNC_IDENTITY.md:36` (step 3 = **REVIEW-BLOCKED — no code**) · `FEATURE_PREP_BACKLOG.md:179` |
| **V3** | **V3 schema (8 frozen attributes)** | **blocked** | D3 (the sentinel defect) is a prerequisite of *shipping* V3, not only of drilling it; and there is no real V2 store to drill against | `DESIGN_V3_SCHEMA_FREEZE.md:3` (*"no code written yet"*) · `:166–170` (what is needed first) · `DEFECT_V2_MIGRATION_SENTINEL.md:26` · `AUDIT_V3_ROLLBACK_READINESS.md:122` (§6, no real V2 store on this machine) |
| **RP1** | **Reports** | **open** — reframed, not scheduled | nothing technical; it needs no schema change | `FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md:46` (*"The verified delta is exactly THREE things. Build these, not a Reports tab."*) · `:48–65` (the three) · `:69` (*"NOT in 1.0.5"*) · `PROPOSAL_1_0_5_SCOPE.md:5` |
| **T1** | **Re-playable tutorial + annotated help** | **open** — evidence and acceptance test written, nothing designed | not scheduled against any release | `PLAN_TUTORIAL_AND_HELP.md:10–12` (*"Nothing here is designed yet. Nothing here is scheduled."*) · `:170` |
| **A1** | **Auto-post recurrence** | **open** — design only | coupled to S1; must ship with the watermark move | `DESIGN_AUTOPOST_RECURRENCE_1_0_4.md:3` · `:644–645` |

### The rollback ladder — `AUDIT_V3_ROLLBACK_READINESS.md` §5

All three are **costed, not applied** — `:96`: *"Three changes, and they are the real prerequisite
the brief was reaching for. Costed, not applied:"*

| id | item | status | blocked by | evidence |
|---|---|---|---|---|
| **L1** | Make the sentinel **version-aware** (`Bool` → schema version) | **open** | nothing — it is the load-bearing change and nothing waits on it | `AUDIT_V3_ROLLBACK_READINESS.md:98–103` · `DEFECT_V2_MIGRATION_SENTINEL.md:30` |
| **L2** | Make the backup **generational** (`Backups/pre-v2` → `pre-v<n>`) | **open** | L1 — *"the other two are consequences"* (`:103`) | `AUDIT_V3_ROLLBACK_READINESS.md:104–106` |
| **L3** | Move the `--fail-migration` seam into the post-open probe every path executes | **open** | L1, though accepted on its own merit | `AUDIT_V3_ROLLBACK_READINESS.md:107–110` · `DEFECT_V2_MIGRATION_SENTINEL.md:33–34` |
| **L0** | *(the reason L1–L3 are not optional)* | — | — | `AUDIT_V3_ROLLBACK_READINESS.md:115–118` — *"these three are a prerequisite of *shipping* V3, not only of drilling it"* · `:12–14` — *"**Nothing in the §10 ladder runs.**"* |

### Engineering items

| id | item | status | blocked by | evidence |
|---|---|---|---|---|
| **C1** | **Collapse CSV import orchestration onto `CSVImportActor`** | **decided-build**, scheduled **first after 1.0.5 ships** | 1.0.5 shipping | `PROPOSAL_1_0_5_SCOPE.md:569` (*"**Decided 2026-08-13. Explicitly out of 1.0.5, explicitly first after it.**"*) · `:575–576` (the change) · `:591` (zero test references) · `:597` (must land before any further import work) |
| **C2** | *(C1's standing cost, re-verified at HEAD 2026-09-12)* | — | — | `AUDIT_TEST_REACHABILITY_2026-08-13.md:24` · re-checked today: `grep -rn CSVImportActor FinanceTrackerTests/` returns **one hit, and it is a comment** (`SaveFailureReachabilityProbe.swift:151`); nine test files exercise `CSVImportService` instead |
| **E1** | **CloudKit field-level encryption** | **open — and no decision has ever been recorded** | nothing; it is simply undecided | `REVIEW_PRIVACY_POLICY_CORRECTION_2026-08-03.md:50–54` — *"`outputs/DESIGN_ICLOUD_SYNC_1_0_4.md` contains **zero** occurrences of `encryptedValues`, `allowsCloudEncryption`, or any encryption-marking decision (grepped)."* · `:45–48` (a field we do not mark is not E2EE even under ADP) |
| **P1** | **Privacy-copy gate** | **blocked** — deliberately; it fires on the sync release | S1 (iCloud sync) | `GO_LIVE_CHECKLIST.md:81` (*"The privacy-copy gate does not fire on build 10. It fires when iCloud sync ships"*) · `:86–99` (the gate, unticked) · `:94–95` (do not reuse today's count of five — it came from a grep) |
| **W1** | **`wipeLedger` main-thread cost** | **open** — investigation, explicitly not a release gate | — | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:3` (*"**Status: INVESTIGATION. Not a fix, and explicitly NOT a release gate.**"*) · `:66` (*"**`wipeLedger` is unconditional**"*) · `FinanceTracker/Views/ContentView.swift:217` (*"`wipeLedger` over 8 000 categorised rows measures 45.8 s"*) · `FinanceTracker/Data/LargeDatasetDebugSeed.swift:125` (DEBUG-only) · measured by `FinanceTrackerTests/PurgeCostMeasurementTests.swift:33` |
| **B1** | **Permanent bootstrap logging** | **open — NO SOURCE DOCUMENT EXISTS** | — | **Nothing in `outputs/` proposes it.** Greps for `permanent bootstrap logging`, `permanent logging`, `BootstrapLog`, `bootstrap logging` over `*.md` and `*.swift` return zero. The nearest real text is explicitly temporary: `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:149–151` — *"`LAUNCHPROBE` instrumentation added to `LaunchGateView` in the 1.0.4 worktree only (log-only, no behaviour change)"*. `grep -rn LAUNCHPROBE --include=*.swift` returns **zero** — it is not in the tree. `LaunchGateView.swift` carries exactly one log line, at `:438`. **This item exists only because it was named out loud. It is recorded here so it stops living in someone's head — but it has no case written down, and writing one is the next action.** |

### Measurement instruments

| id | item | status | blocked by | evidence |
|---|---|---|---|---|
| **R1a** | Split-discoverability precondition, clause (c) | **MET by 1.0.4 build 8** — verified today | — | pre-test `:81` (clause (c)) · `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md:176` (*"record … `Precondition met by version = 1.0.4 · clause (c)`"*) · **verified 2026-09-12**: `git show v1.0.4-build8:FinanceTracker/Views/TransactionDetailView.swift` contains the unconditional split affordance at `:68` (`Label("split.add_part", …)`), identical to HEAD |
| **R1b** | §1.1 usage-signal ordering fix live at T0 | **MET by 1.0.4 build 8** — verified today | — | pre-test `:50`, `:59`, `:63` · **verified 2026-09-12**: `15b646b` *("record usage.ever.* only after the save that earns it")* is an ancestor of tag `v1.0.4-build8` |
| **R1c** | **T0 = the date 1.0.4 became available** | **UNRECORDED** | nothing — it needs App Store Connect and a pen | pre-test `:103` (`T0 = ____________`) · `:125` (*"only mails received **after T0** count"*) · no document in `outputs/` carries a 1.0.4 availability date |

---

## 3. WHAT R1 ACTUALLY MEANS — the one row worth reading twice

The pre-test's own gating conditions are **satisfied**, and have been since 1.0.4 shipped:

- clause (c) discoverability shipped in build 8 (R1a, verified against the tag today);
- the instrument's upward-bias defect was fixed in build 8 (R1b, verified against the tag today);
- 1.0.4 reached real App Store users — one of them wrote in (`PLAN_TUTORIAL_AND_HELP.md:20`).

By `DECISION_RECEIPT_INPUT_PRETEST.md:103`, **T0 is that availability date**, and by `:104` the first
look is T0 + 90 days. Nobody wrote T0 down. So:

> **The measurement window is open, it has been open for some weeks, and the file that governs it
> still reads `T0 = ____________`.**

Two consequences, both narrow and neither a licence to act:

1. **The first look may already be due or overdue.** It is not computable from anything in this repo,
   because the availability date is not in this repo. Get it from App Store Connect and write it into
   the pre-test's `:103` and `:118`. That is the entire action.
2. **Nothing about §4 may move.** `:214` — *"**Do not edit §4 after data starts arriving.**"* — and
   `:306` — *"**An open amendment window is not a reason to amend.**"* Recording a missing T0 is
   bookkeeping. Touching a threshold is not, and §8.3 gives the two-part test that would have to pass
   first. Both must hold; neither does.

**What this row is NOT.** It is not evidence about receipt OCR in either direction. The council's
2026-07-19 kill stands until the instrument reads (`:162`). This row is about a blank field, not
about a feature.

---

## 4. CONTRADICTIONS BETWEEN SOURCES — surfaced, not resolved

This section is the reason the file exists. **Where two documents disagree, both are recorded. No
row here has been silently picked.**

### 4.1 The family backlog row contradicts the family research document

- `FEATURE_PREP_BACKLOG.md:32` renders row 9 as **`~~Couples (CloudKit Shared DB)~~ STRUCK
  2026-08-13`** — the **feature name itself** struck through.
- `RESEARCH_FAMILY_ACCESS_2026-08-12.md:3` says **"No design, no code, no decision taken."**
- The backlog's own explanatory note is titled *"Note on rows 1, 4, 5 — ranks struck 2026-08-13"*
  (`:35`) and states at `:37`: *"**What is struck is the RANK, not the features.**"* **Row 9 is not
  in that note's scope.** Rows 4 and 5 strike only the word "rank"; row 9 strikes the feature name.
- **The effect:** a reader of the backlog sees a killed feature. A reader of the research sees an
  open question with a hard architectural constraint. **Both are in the repo right now.**
- **Not resolved here.** Resolving it is a decision, and a decision belongs in this file only after
  someone takes it. What this row does is stop the next planning pass from taking it by accident.

### 4.2 `DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md` contradicts itself

- `:3` — *"**Status:** open, release hold. Not fixed, nothing touched."*
- `:129` — *"## 7. FIXED IN BUILD 10 — and what the enumeration cost"*
- The header was never updated when §7 was added. **§7 is correct** (verified: `1b6be14` and
  `c2461b3` are ancestors of `v1.0.5-build10`, not of `v1.0.4-build8`). This is the exact failure
  mode STATE.md exists to end: status living inside a research document, at the top, going stale
  while the body moves on.

### 4.3 `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md` is half stale

- `:3` — *"Not yet committed or released."*
- **Committed:** `8c748b7` is an ancestor of `v1.0.5-build9`. **Not released:** build 9 and build 10
  are not the version users have. So the first half is now false and the second is still true —
  which is worse than being wholly wrong, because a reader who spot-checks the first half will
  distrust the second.

### 4.4 "Signal #7" means two different things, and they are inverted

Two live numbering systems collide on exactly the two items this project cares most about:

| | `DEMAND_RESEARCH_AND_ROADMAP_2026-07.md` §1 table (`:17–90`) | `FEATURE_PREP_BACKLOG.md` priority table (`:22–33`) |
|---|---|---|
| **#7** | **"Safe to spend"** — `:97`: *"#7 is the uncomfortable one."* | **iCloud sync** — `:30` |
| **#9** | **iCloud sync** — `:86`: *"**WITHDRAWN — see §1.1.**"* | **Couples / shared** — `:32` |

So *"signal #7"* in the demand roadmap is safe-to-spend; *"row #7"* in the backlog is sync. And
*"#9"* is withdrawn-sync in one and struck-couples in the other. **The commit that added the
2026-09-12 data point is titled "signal #7 gets its first demand-side data point"
(`12a5ad7`) and means safe-to-spend** — `DEMAND_RESEARCH_AND_ROADMAP_2026-07.md:110`. Anyone reading
that subject line against the backlog will conclude a user asked for iCloud sync. **Nobody did.**

- **Signal #7 (safe-to-spend) status: open, n=1, explicitly not re-scored.** `:112` — *"**One data
  point. Not a re-score, not a roadmap item.**"* · `:130` — *"**It is not confirmation of 'safe to
  spend'.** He asked for a *savings balance* — a stock, a net position — not for a per-month
  discretionary remainder, which is a flow."*

### 4.5 The receipt pre-test is not in this repository

`DECISION_RECEIPT_INPUT_PRETEST.md` is cited by **at least six documents in `outputs/`** — e.g.
`FEATURE_PREP_BACKLOG.md:6`, `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md:4`,
`DECISION_RELEASE_SHAPE_1_0_4.md:81`, `:94` — as though it were a sibling file. **It is not in this
repo and has not been since `758691d` (2026-08-04) untracked it**; `.gitignore` carries it under
*"Internal decision records (moved to budget-crab-internal 2026-08-04)"*.

**Its real path is `../budget-crab-internal/working-docs/DECISION_RECEIPT_INPUT_PRETEST.md`** — a
sibling repository, outside this working tree. Every reference in `outputs/` is a dead link from
inside this repo. That is a contributing cause of the 2026-09-08 error: the document that would have
answered the question could not be opened from where the question was asked.

---

## 5. HOW TO RE-DERIVE THIS FILE — so the next reader can check it instead of trusting it

Run these. They are the whole method; there is nothing else behind this file.

```bash
cd /Users/dmitrylogachevusa/Desktop/ProjectsIOS/FinanceTracker

# 1. Every document's own status line — the skeleton.
for f in outputs/*.md; do echo "### $f"; \
  grep -n -i -m6 "^\*\*Status\|^Status:\|^> \*\*Status\|^\*\*Verdict\|^\*\*Decision" "$f"; done

# 2. Which builds contain which fix. This is the ONLY way to answer "reachable today".
#    Do not reason from a commit date; tags are what shipped.
git merge-base --is-ancestor <commit> v1.0.4-build8 && echo "in shipped" || echo "NOT in shipped"

# 3. Whether a precondition really shipped — read the TAG, not HEAD.
git show v1.0.4-build8:FinanceTracker/Views/TransactionDetailView.swift

# 4. The pre-test lives in a DIFFERENT REPO. See §4.5.
cat ../budget-crab-internal/working-docs/DECISION_RECEIPT_INPUT_PRETEST.md
```

**Rule for updating this file:** change a status only after re-running the check that establishes it,
and update the citation in the same edit. A status whose citation was not re-read is a status written
from memory, which is the thing this file was built to stop.

---

## 5b. THE THREE FILES, AND WHAT EACH IS FOR

| file | question it answers | method |
|---|---|---|
| `STATE.md` (this file) | *What is decided, open, or blocked — and where was that verified?* | reads documents |
| `DEFECT_REGISTER.md` | *What is broken, is it reachable, and can it come back silently?* | reads documents, then re-verifies against release tags |
| `COVERAGE_MATRIX.md` | *Which money-touching surfaces have zero tests?* | reads **code**, not documents |

**The third exists because the first two share a blind spot.** A defect nobody wrote down is invisible
to both. `COVERAGE_MATRIX.md` is the only one of the three that can find something no document
mentions — and §6 below is why that matters.

---

## 6. THIS FILE'S OWN BLIND SPOT — stated here rather than discovered later

**STATE.md is an enumeration of documents, and enumeration is the method that has failed most often
in this project.** It failed four times in one day on 2026-09-02
(`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:150–163`), by two different people, using four different
methods — two greps, one inspection, one mis-classification.

Three specific ways this file is wrong right now, in order of likelihood:

1. **A decision that was never written into any document is absent from this file, and its absence
   looks exactly like "no such decision".** Row **B1** is a known instance and is flagged as one:
   "permanent bootstrap logging" has no source document anywhere. There is no reason to think B1 is
   the only one. **This file cannot find what was never written down — it can only make the gap
   visible once someone names the item.**
2. **Documents with no status line are under-represented.** Of 124 files in `outputs/`, the sweep in
   §5 step 1 found an explicit status/verdict/decision line in roughly **twenty**. The remaining
   ~100 were read only where a required item pointed into them. **A decision sitting in the body of
   a brief with no header line is invisible to the method that built this file.**
3. **A status can be stale without contradicting itself,** so §4 catches only the loud cases. §4.2
   and §4.3 were found because the document argued with *itself*. A document that is simply, quietly
   out of date presents no seam to catch.

**The mitigation is not more care.** It is that rules 1 and 2 at the top make the next omission
*cheap to fix* — a missing row is added in one line with one citation — rather than making this pass
exhaustive, which it is not and cannot be.

---

## 7. NOTE FOR WHOEVER RUNS THE FULL SUITE NEXT

**The next full run is expected to exit 5 and print the observed count. That is not a failure.**

`scripts/run-tests.sh:192` sets `EXPECTED_TOTAL_RUN=1113`, deliberately **one low**. 1114 is the
arithmetic answer, and the constant exists to refuse an arithmetic answer: per
`project_full_suite_oom_on_this_mac`, **`EXPECTED_TOTAL_RUN` is never to be set by arithmetic — the
next full run prints the observed number and that number is what goes in.** Exit 5 is the guard
working. Read the printed count, set the constant to it, and move on.

Separately, and unrelated to the count: a full run can still lose ~415 tests to the
`VoiceInputService` abort (row in `DEFECT_REGISTER.md`). `run-tests.sh` now exits 4 on a truncated
run — `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:196`.
