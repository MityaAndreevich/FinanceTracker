# STATE — the one page where status lives

**Derived 2026-09-12 from the sources, at HEAD `537e220`. Updated 2026-09-21 at HEAD `83da3ce`
(Phase 0 of `BRIEF_MASTER_2026-09-21.md`) — §8 lists every row that changed and why.** No row was
written from memory, including mine.

> **2026-09-21: the shipped version is no longer an inference.** `itunes.apple.com/lookup?id=6784424678`
> (queried 2026-09-21) returns `version 1.0.5`, `currentVersionReleaseDate 2026-09-12T18:22:22Z`.
> Every "inferred" warning below about 1.0.4 b8 is left in place as history and **superseded by §8.1**.

**Counts used below, each with the command that produced it** (run 2026-09-12) — because a count is a
separate claim from the thing it counts (rule 4):

| number | value | command |
|---|---|---|
| markdown documents in `outputs/` | **115** (112 before this pass added three) | `ls outputs/*.md \| wc -l` |
| entries in `outputs/` including data files | **127** | `ls outputs/ \| wc -l` |
| of those carrying a status/verdict/decision header | **25** | the sweep in §5 step 1, piped to `wc -l` |
| `outputs/` documents citing the pre-test | **5** (excluding this file and the register) | `grep -rln DECISION_RECEIPT_INPUT_PRETEST outputs/*.md` |

---

## THE RULES THIS FILE IMPOSES

1. **If a decision is not in STATE.md, the decision does not exist.** A conclusion carried in a
   session, a chat message, or a person's head is not a decision. It is a recollection, and this
   project has now watched recollection invent a veto and resolve an open test.
2. **A status line must cite where it was verified — file AND line.** No status from memory, ever.
   Not the founder's, not Claude's, not a previous session's. A pointer a reader cannot open is not
   evidence; it is a claim, and this project has a rule about claims.
3. **The 115 documents in `outputs/` are the evidence archive. They no longer carry AUTHORITATIVE
   status.** Read precisely: their status headers were **not** stripped and are still there, several
   of them stale — §4.2 and §4.3 are two proven cases. What changed is **precedence**, not the files.
   Where a document's header contradicts this file, **this file wins**, and the contradiction gets a
   row in §4 rather than a silent edit to either.
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

### RESULT — run 2026-09-12, same day, and it found real defects

**Run as registered:** a session with no context, permitted to open this file and nothing else — no
git, no grep, no following a citation.

**All three answered, all three immediately.** The stopwatch clause passed.

**And it failed in ways worth recording, because a test that only ever passes is not a test.** Nine
repairs were made to this file as a result; four mattered:

| what it found | why it mattered | repaired |
|---|---|---|
| The Q3 table's middle column **changed subject halfway down** — rows 1–3 answered about the *fix*, rows 4–6 about the *defect*, under one header | A reader taking the header literally reads row 1 as *"not in build 8 ⇒ not reachable"* — **the exact inversion of the truth**, in the section built to pass this test | Split into two columns, `defect present?` and `fix present?` |
| §3 said the window *"has been open for some weeks"* | That is **a duration computed from a date §1 marks NOT RECORDED ANYWHERE** — a plausible unsourced number, in the file whose whole purpose is stopping those | Deleted, and the deletion is now documented in §3 so it cannot come back |
| §7 said to harvest the suite count from the next run — with no caveat that an **exit-4 truncated run** would bake a short total in permanently | Following this file's own instruction would have **disarmed the guard, silently and forever** | §7 now forbids harvesting from an exit-4 run, in a box |
| §0's citation to the pre-test used a path that **does not resolve from this repo** | §4.5 names precisely that as a cause of the 2026-09-08 error — and §0 reproduced it | §0 now leads with the sibling-repo path and a warning |

It also found that §0's Q1 named one blocker where §2 named two, and that *"both preconditions are
met"* contradicted §2's own enumeration of three. Both fixed above.

**What this does not establish.** §0 was written to answer these three questions, so passing proves
§0 exists — not that this file carries status in general.

### RUN 2 — same day, with a FOURTH question the file was not built for

*"I am about to run the full suite and then start work on iCloud sync. What must I not get wrong,
and what must I do first?"*

**Content: passed. Retrieval: failed.** Everything needed was present and correct — including the
single most decision-relevant fact, that **sync was withdrawn as a demand signal and nobody asked
for it** (§4.4). But answering required assembling **nine** locations: §1, §7, S1, L1–L3, V3, E1, P1,
A1 and §4.4. Well over a minute.

> **The diagnosis is structural: this file is organised by ITEM, and Q4 is a question about an
> ACTION.** The three registered questions are item-shaped, which is why §0 works for them and only
> them. **A reader arriving with a task, rather than with a question about one item, is not served.**
> That is recorded as a known limitation, not repaired — repairing it means an action-shaped index,
> and that should be built when a second action-shaped question appears, not guessed at now.

**Run 2 also found three defects run 1 missed, and one claim run 1's own repair log overstated:**

| what it found | repaired |
|---|---|
| §7 said *"fix **or exclude** D1's test and run again"* — excluding removes the only coverage of a user-reachable process `abort()`, **and then sanctions harvesting the count from that run**, baking a lowered baseline in through the front door | §7 now bars harvesting from any filtered run, and bars standing exclusion of D1 |
| §5's own recipe used `&& echo yes \|\| echo NO` — a missing tag, bad SHA or wrong cwd exits non-zero and prints a confident **"NO"**. The *"reports success while doing nothing"* class, installed in the verification recipe | Replaced with a three-outcome form that prints `ERR` on failure |
| §7 gave exit 4 and 5 but not **exit 2 and exit 3**, and said nothing about the run not finishing — three attempts on 2026-09-12 were killed in the compile phase | All four exit codes tabled; the erase rule and the OOM record added, both cited to `scripts/run-tests.sh` |
| Run 1's repair log claimed *"both fixed above"* about the preconditions — **§0 was fixed and row R1 still read "Both preconditions are MET"** | R1 corrected. **The log was wrong, and that is recorded here rather than edited away** |

Unsourced counts found in both runs (*"124 documents"*, *"roughly twenty"*, *"~100"*, *"at least six"*,
*"1114 is the arithmetic answer"*) are now counted or cited — see the table at the top of this file.
Three of those numbers were wrong: it is **115** documents, **25** with status headers, and **five**
citing the pre-test.

**Re-run this test against a new question whenever one is asked twice.**

---

## 0. THE THREE ANSWERS

**Q1 — Family / shared access: OPEN. No decision has been taken.**
`outputs/RESEARCH_FAMILY_ACCESS_2026-08-12.md:3` — *"**Status: RESEARCH ONLY. No design, no code,
no decision taken.**"*

**Two blockers, not one:**
1. **SwiftData cannot use the CloudKit shared database.** `:302` — *"SwiftData does not support the
   shared database — and this is the veto"*; `:388` — *"**But both still sit behind §3.2's veto.**
   Expressible in CloudKit ≠ available in SwiftData."* This reaches the **feature**, not only the
   sharing shapes: the one candidate that gives privacy *and* fits CloudKit (`:382`) is still behind it.
2. **It sits behind private sync**, which is itself blocked on two unbuilt prerequisites — `:414`:
   *"behind private sync, which is itself behind two unbuilt prerequisites (the rollback ladder and
   the recurrence watermark)"*. See rows **S1** and **L1–L3**.

**Where a careful reader could land on `decided-skip` instead, and why this file does not.** The
research document **recommends** refusing it in the 1.0.x line (`:412`), and
`outputs/FEATURE_PREP_BACKLOG.md:32` renders the feature name itself struck through. Against that:
`:412` sits under a heading written in the conditional — *"WHAT I WOULD BUILD, AND WHAT I WOULD
REFUSE"* (`:399`) — `:419` says *"That is judgement, not evidence"*, and the header at `:3` is the
document's own status line. **This file reads `:3` as governing, and records the disagreement rather
than burying it — §4.1.** A reader who wants the other reading should go argue with §4.1, not
discover the conflict later.

**Q2 — Receipt-input pre-test: NOT RESOLVED. It is registered and unread.**

⚠️ **The governing document is NOT in this repository.** Its path is
`../budget-crab-internal/working-docs/DECISION_RECEIPT_INPUT_PRETEST.md` — a **sibling repo**, one
level above this working tree. Every citation below is to that file. **Five** `outputs/` documents
cite it as though it were local (counted — §4.5); from inside this repo those are all dead links.

`:4` — *"**Status:** registered, not yet resolved."* The §5 results table (`:199–212`) is **empty**.

**What would resolve it,** in order:
1. **Record T0** = the date 1.0.4 became available on the App Store (`:103`). **It is not in this
   repo** — App Store Connect has it.
2. Read **N / S / S6** at T0+90 and T0+180 against the thresholds at `:143–145` (BUILD) and `:153`
   (KILL), band rule at `:184–187`.

**Of the three gating conditions, two are met and one is blank** — R1a and R1b shipped in 1.0.4
build 8 (verified against the tag, §2); **R1c, T0 itself, is UNRECORDED.** The clock started when
1.0.4 became available and nobody wrote the date down. **Row R1 and §3 are the actionable finding on
this item.**

**Q3 — Defects reachable by a user in the currently shipped version.**

> **SUPERSEDED 2026-09-21 — read §8.1 instead.** The shipped version is **1.0.5 build 10**, a
> recorded fact (App Store lookup). The table below answered for 1.0.4 b8 and is kept as history.

The currently shipped version *was* **1.0.4 build 8** — ⚠️ **this was an INFERENCE, not a recorded
fact, and every answer below rests on it.** No document states which version is available; the
inference is that 1.0.5 b10 is *in review* and a real App Store user is on 1.0.4 b8. **Confirm it in
App Store Connect before acting on this table** — the same visit settles R1c. Full statement in §1.
1.0.5 build 10 is in review. So
**every fix that landed in build 9 or build 10 is NOT yet in users' hands.** Build 10 contains build
9's work (`v1.0.5-build9` is an ancestor of `v1.0.5-build10`, checked 2026-09-12), so "fixed in
build 9" and "fixed in build 10" are equally out of reach today.

**Read the two middle columns separately — they answer different questions.** `defect present?` is
about the bug; `fix present?` is about the patch. They are deliberately not merged, because merging
them is how a reader concludes the opposite of the truth.

| defect | **defect present in 1.0.4 b8?** | **fix present in 1.0.4 b8?** | reachable by a user today |
|---|---|---|---|
| Migration floor strands 1.0.0-era stores | **YES** | **NO** — fix `8c748b7` lands build 9 | **YES — happening now.** Live in the field since 1.0.3 became available 2026-07-29 (`BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:98`). Terminal: the user's only escape was delete-and-reinstall, which discards the ledger |
| Import amount-cap asymmetry / aggregate overflow | **YES** | **NO** — `1b6be14`, `c2461b3` land build 10 | **YES, but needs adversarial input** — a hand-made or malformed CSV. *"Not claimed that any user has hit this"* (`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:234`). Consequence is a **process trap — a crash — on the dashboard's first render** |
| PDF export clips amounts | **YES** | **NO** — `f7dde93` lands build 10 | **YES — already reported by a real user.** Silent: the amount is wrong on the page, with no error |
| `VoiceInputService` teardown `abort()` | **YES** | **NO — never fixed, in any build** | **YES on the code's reading** — *"reachable by opening Quick Entry and closing it"* (`DEFECT_VOICE_INPUT_DEINIT_ABORT.md:135`). **The caveat is about manifestation, not reachability:** `:176` — *"Not claimed that this has ever crashed a user's device."* Consequence is a **process `abort()` — a crash with no recovery** |
| 14 remaining overflow expressions (`AnalyticsSeries` et al.) | **YES** | **NO — never fixed** | **YES** — *"Analytics still **traps** on a ledger the dashboard has just told the user is otherwise fine"* (`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md:202`). "Traps" = **crashes the process** |
| V2 migration sentinel disconnects the rollback ladder | **YES** | n/a — not a fix, a prerequisite | **NO — latent.** Fires only when a V2→V3 migration runs; V3 has not shipped (`DEFECT_V2_MIGRATION_SENTINEL.md:26`) |

**Is this list complete? NO, and the gap is knowable.** These six are the *filed* defects plus the
overflow thread. `outputs/DEFECT_REGISTER.md` §3.1 carries **five more that are reachable in build 8
and were never filed anywhere** — including a dead "Rate the app" link and a Settings button that
does nothing behind a destructive confirmation alert. **Anyone answering this question for real must
read §3.1 of the register, not just this table.** And per §6, neither file can see a defect nobody
wrote down.

Register (regression-test columns, ~30 unfiled defects): `outputs/DEFECT_REGISTER.md`.
Money-touching surfaces with **zero tests**: `outputs/COVERAGE_MATRIX.md`.

---

## 1. SHIPPED-VERSION FACTS (everything in Q3 depends on these)

⚠️ **The first row is an INFERENCE, not a recorded fact, and everything in Q3 rests on it.**
No document in `outputs/` states which version is currently available. The inference is: 1.0.5 b10
is *in review* (so not available), and a real App Store user is on 1.0.4 b8 (so it was released).
Both halves are cited below. **It is not proof that 1.0.4 b8 is the latest available build** — only
App Store Connect can settle that, and it would settle R1c in the same visit. **Anyone acting on Q3
should confirm it there first.**

| fact | value | evidence |
|---|---|---|
| Currently available on the App Store | **1.0.5 build 10** — **recorded 2026-09-21** (supersedes the 1.0.4 b8 inference that stood here from 2026-09-12) | `itunes.apple.com/lookup?id=6784424678` → `version: 1.0.5`, `currentVersionReleaseDate: 2026-09-12T18:22:22Z` (queried 2026-09-21). The lookup carries no build number; **build 10** is the founder's statement, `BRIEF_MASTER_2026-09-21.md:83`, and the only 1.0.5 build ever uploaded per `ARCHITECTURE.md` "Shipped so far" |
| 1.0.5 available | **2026-09-12** | same lookup, `currentVersionReleaseDate` |
| Build 10 contains build 9 | yes | `git merge-base --is-ancestor v1.0.5-build9 v1.0.5-build10` → 0, checked 2026-09-12 |
| In review | 1.0.5 build 10 | `PLAN_TUTORIAL_AND_HELP.md:170`; `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:204` |
| Working tree version | 1.0.5 (10) | `FinanceTracker.xcodeproj/project.pbxproj:477`, `:466` |
| 1.0.0 released | 2026-07-10 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:101` |
| 1.0.3 available | 2026-07-29 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:98` |
| **1.0.4 available** | **STILL NOT RECORDED** — the public lookup exposes only the *current* version's date, so 2026-09-21 did not settle it | see row R1 — this blank is load-bearing; App Store Connect's version history has it |
| Suite constant | `EXPECTED_TOTAL_RUN=1113` — **further behind after 2026-09-21**: four test files were added (§8.5); by how much is deliberately not computed | `scripts/run-tests.sh:192` |

---

## 2. THE TABLE

`status ∈ decided-build · decided-skip · open · blocked · awaiting-measurement`
Evidence is the document **and line** that holds the detail, never a summary of it.

### Features and programmes

| id | item | status | blocked by | evidence |
|---|---|---|---|---|
| **F1** | **Family / shared ledger** | **decided-build** — founder's decision 2026-09-21, target 1.2, **design first, no code before approval** (`BRIEF_MASTER_2026-09-21.md:287–288`: *"Measured demand was 0.04–0.14% of 4,904 competitor reviews. Dmitry has decided to build it anyway"*; `:300–303` design doc then STOP). Model fixed by the brief: candidate 5, a separate shared ledger (`:282–286`). Was **open** until 2026-09-21 | SwiftData cannot use the CloudKit shared database; and it sits behind private sync, which has two unbuilt prerequisites of its own | `RESEARCH_FAMILY_ACCESS_2026-08-12.md:3` (status) · `:302–321` (the veto) · `:382` (candidate 5 is the only model that gives privacy AND fits CloudKit) · `:388` (candidate 5 is still behind the veto) · `:412–415` (recommends refusing it in the 1.0.x line) · `:419` (*"That is judgement, not evidence"*) |
| **R1** | **Receipt / screenshot OCR** | **decided-build** — founder's decision 2026-09-21, target 1.0.7, design doc first (`BRIEF_MASTER_2026-09-21.md:177–178`: *"Dmitry has DECIDED to build this; the pre-test was not resolved and must not be described as resolved"*). **The pre-test remains NOT RESOLVED** — the decision overrides it, it does not answer it; T0 is still blank (R1c). Was **awaiting-measurement** until 2026-09-21 | Nothing external. **Of the three gating conditions, R1a and R1b are MET and R1c (T0) is UNRECORDED** — what is missing is that nobody wrote the date down | pre-test `:4` (registered, not resolved) · `:103` (`T0 = ____________`, still blank) · `:199–212` (empty results table) · preconditions verified below |
| **S1** | **iCloud sync (private CloudKit)** | **decided-build**, target 1.1, **design first with family in view** (`BRIEF_MASTER_2026-09-21.md:273–279`, `:300–303`); the technical blockers in the next column are unchanged and are what the design must resolve | (a) the rollback ladder — see L1–L3; (b) the recurrence watermark must move into the synced model | `DESIGN_ICLOUD_SYNC_1_0_4.md:3` (*"**Status: DESIGN ONLY.**"*) · `:539–540` (*"a prerequisite, not an option"*) · `PLAN_RECURRENCE_SYNC_IDENTITY.md:36` (step 3 = **REVIEW-BLOCKED — no code**) · `FEATURE_PREP_BACKLOG.md:179` |
| **V3** | **V3 schema (8 frozen attributes)** | **blocked** | D3 (the sentinel defect) is a prerequisite of *shipping* V3, not only of drilling it; and there is no real V2 store to drill against | `DESIGN_V3_SCHEMA_FREEZE.md:3` (*"no code written yet"*) · `:166–170` (what is needed first) · `DEFECT_V2_MIGRATION_SENTINEL.md:26` · `AUDIT_V3_ROLLBACK_READINESS.md:122` (§6, no real V2 store on this machine) |
| **RP1** | **Reports** | **decided-build**, target 1.0.6. **Design written 2026-09-21 — `outputs/DESIGN_REPORTS_1_0_6.md`, AWAITING APPROVAL, no code**; five open items listed in its §13 (`BRIEF_MASTER_2026-09-21.md:129–163`). Must fix D5's `AnalyticsSeries` overflow under it (`:152–155`) | nothing technical; it needs no schema change | `FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md:46` (*"The verified delta is exactly THREE things. Build these, not a Reports tab."*) · `:48–65` (the three) · `:69` (*"NOT in 1.0.5"*) · `PROPOSAL_1_0_5_SCOPE.md:5` |
| **T1** | **Re-playable tutorial + annotated help** | **decided-build**, target 1.0.7, as a three-layer user guide; design doc `outputs/DESIGN_USER_GUIDE.md` first then STOP (`BRIEF_MASTER_2026-09-21.md:204–268`) | not scheduled against any release | `PLAN_TUTORIAL_AND_HELP.md:10–12` (*"Nothing here is designed yet. Nothing here is scheduled."*) · `:170` |
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
| **B1** | **Permanent bootstrap logging** | ⚠️ **NOT AN ITEM YET — no source document exists.** Do not count this as scheduled work; it has no case written down | — | **Nothing in `outputs/` proposes it.** Greps for `permanent bootstrap logging`, `permanent logging`, `BootstrapLog`, `bootstrap logging` over `*.md` and `*.swift` return zero. The nearest real text is explicitly temporary: `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:149–151` — *"`LAUNCHPROBE` instrumentation added to `LaunchGateView` in the 1.0.4 worktree only (log-only, no behaviour change)"*. `grep -rn LAUNCHPROBE --include=*.swift` returns **zero** — it is not in the tree. `LaunchGateView.swift` carries exactly one log line, at `:438`. **This item exists only because it was named out loud. It is recorded here so it stops living in someone's head — but it has no case written down, and writing one is the next action.** |

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

> **The measurement window is open, and the file that governs it still reads
> `T0 = ____________`.**

**How long it has been open is NOT stated here, deliberately.** The obvious sentence — *"it has been
open for some weeks"* — was written into an earlier draft of this file and removed. It is a duration
computed from a date §1 marks **NOT RECORDED ANYWHERE**, which makes it exactly the kind of
plausible, unsourced number the citation protocol exists to stop. **The elapsed time is unknown
until someone reads the availability date off App Store Connect.**

Two consequences, both narrow and neither a licence to act:

1. **The first look may already be due or overdue.** It is not computable from anything in this repo,
   because the availability date is not in this repo. Get it from App Store Connect and write it into
   the pre-test's `:103` and `:118`.

   **Why this is not barred by `:214` ("Do not edit §4 after data starts arriving").** `:103` and
   `:118` are in **§3 and §5**, not §4. **No threshold moves.** The ban is on §4, and §4 is untouched.

   **The honest hazard, which is real and is not resolved by that distinction.** You cannot establish
   whether mails have already arrived, *because you do not know T0* — and `:125` makes T0 the
   boundary that decides which mails count. **A T0 recorded late is still the correct T0** (it is a
   fact about the App Store, not about us), but anyone recording it should note in §5 that it was
   backfilled and on what date, so a future reader can see that the boundary was set after the window
   opened rather than before. **Record the backfill; do not quietly date it.**
2. **Nothing about §4 may move.** `:214` — *"**Do not edit §4 after data starts arriving.**"* — and
   `:306` — *"**An open amendment window is not a reason to amend.**"* Recording a missing T0 is
   bookkeeping. Touching a threshold is not, and §8.3 gives the two-part test that would have to pass
   first. Both must hold; neither does.

**What this row is NOT.** It is not evidence about receipt OCR in either direction. The council's
2026-07-19 kill stands until the instrument reads (`:162`). This row is about a blank field, not
about a feature.

---

### ⚠️ APPLY §4.2 AND §4.3 TO S1 AND V3 BEFORE ACTING ON THEM

The evidence for **S1** is `DESIGN_ICLOUD_SYNC_1_0_4.md:3`, a **status header** — and §4.2 and §4.3
below prove that status headers in `outputs/` go stale while the body moves on, while §6.3 notes
that quiet staleness *"presents no seam to catch."* **The rule this file states undermines its own
citation for the largest item on the roadmap, and honesty requires saying so rather than exempting
it.**

**So S1's header was checked against the code, not only re-read.** `grep -rn "cloudKitDatabase"
--include=*.swift` returns **8 hits, none of them `.private(…)`** — and the one that matters is the
app's own synced store:

```swift
// FinanceTracker/Data/SharedModelContainer.swift:258
"synced", schema: syncedSchema, url: store, cloudKitDatabase: .none
```

**`DESIGN_ICLOUD_SYNC_1_0_4.md:3` is corroborated by the tree, so S1 is a re-verified status and not
merely a re-read one.** Checked 2026-09-12.

**V3 and A1 have NOT had this treatment.** `DESIGN_V3_SCHEMA_FREEZE.md:3` and
`DESIGN_AUTOPOST_RECURRENCE_1_0_4.md:3` are re-read headers only. Do the equivalent check before
acting on either — it is cheap, and it is the difference between a header and a fact.

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

**Naming rule, from here on:** write **`demand-signal safe-to-spend`** and **`backlog-row sync`**.
Do not write a bare `#7` or `#9` in either system again — the fix for an overloaded identifier is to
stop using it, not to annotate it.

- **`demand-signal safe-to-spend` status: open, n=1, explicitly not re-scored.** `:112` — *"**One data
  point. Not a re-score, not a roadmap item.**"* · `:130` — *"**It is not confirmation of 'safe to
  spend'.** He asked for a *savings balance* — a stock, a net position — not for a per-month
  discretionary remainder, which is a flow."*

### 4.5 The receipt pre-test is not in this repository

`DECISION_RECEIPT_INPUT_PRETEST.md` is cited by **five documents in `outputs/`** — counted, not
estimated: `FEATURE_PREP_BACKLOG.md:6`, `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md:4`,
`DECISION_RELEASE_SHAPE_1_0_4.md:81` and `:94`, `REVIEW_PRIVACY_POLICY_CORRECTION_2026-08-03.md:114`,
`RESEARCH_SYNTHESIS_2026-07-02.md` — each as though it were a sibling file. **It is not in this
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
#
#    ⚠️ DO NOT use `... && echo yes || echo NO`. An earlier draft of this file did,
#    and it is the "reports success while doing nothing" class installed in the
#    verification recipe itself: a missing tag, a bad SHA or the wrong cwd exits
#    non-zero and prints a confident "NO". Distinguish the three outcomes:
case "$(git merge-base --is-ancestor "$C" "$TAG"; echo $?)" in
  0) echo "IN $TAG" ;;
  1) echo "NOT in $TAG" ;;
  *) echo "CHECK FAILED — bad SHA, missing tag, or wrong cwd. This is not an answer." ;;
esac

# 3. Whether a precondition really shipped — read the TAG, not HEAD.
git show v1.0.4-build8:FinanceTracker/Views/TransactionDetailView.swift

# 4. The pre-test lives in a DIFFERENT REPO. See §4.5.
cat ../budget-crab-internal/working-docs/DECISION_RECEIPT_INPUT_PRETEST.md
```

### The recorded output behind every build claim in §0 and §2

Rule 2 forbids a pointer a reader cannot open. A `git merge-base` result asserted with no output is
exactly that, so here it is — **run on 2026-09-12, reproducible with the loop below.**

```
commit     what it fixes                      1.0.4-b8   1.0.5-b9   1.0.5-b10
8c748b7    migration floor (pre-V1 lift)         NO         yes        yes
1b6be14    reject unrepresentable amounts        NO         NO         yes
c2461b3    4 regressions + 25th overflow site    NO         NO         yes
f7dde93    PDF amount column sizing              NO         NO         yes
15b646b    usage.ever.* ordering (R1b)           yes        yes        yes
```

```bash
# Three outcomes, never two — see the warning in step 2 above.
anc() { git merge-base --is-ancestor "$1" "$2"; case $? in 0) echo yes;; 1) echo NO;; *) echo ERR;; esac; }
for c in 8c748b7 1b6be14 c2461b3 f7dde93 15b646b; do
  printf "%s  b8=%s b9=%s b10=%s\n" "$c" \
    "$(anc $c v1.0.4-build8)" "$(anc $c v1.0.5-build9)" "$(anc $c v1.0.5-build10)"
done
```
**Any `ERR` invalidates the whole row.** The table above was produced with this form and contains
none.

**Read the `15b646b` row against the others**: it is the only fix already in users' hands, and it is
the instrument correction — not any of the three defect fixes.

---

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
2. **Documents with no status line are under-represented.** Of **115** markdown files in `outputs/`,
   the sweep in §5 step 1 found an explicit status/verdict/decision header in **25** — counted, not
   estimated. **The other 90 were read only where a required item pointed into them.** **A decision sitting in the body of
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
`scripts/run-tests.sh:177–178`, **the constant comes from the OBSERVED count and never from
arithmetic.** The +1 is sourced, not guessed: `:174–175` names the test that was added
(`ShippedStoreShapeTests.test_v1_0_5_build10_storeOpens`) and `:190–192` records the scoped run that
proves it real — `executed=9`, *"was 8 before the change"*. `:181` calls 1114 *"the arithmetic answer
and it is probably right; 'probably right' is exactly the currency this constant exists to refuse."*
**Exit 5 is the guard working.**

### ⚠️ BUT: never harvest the count from a truncated run

**These two facts interact, and the interaction is a trap.** A full run can still lose ~415 tests to
the `VoiceInputService` abort (`DEFECT_REGISTER.md` D1; `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:195`) —
44 suites, 415 `@Test` functions — and
`run-tests.sh` exits **4** on that — *"(44 suites, 415 `@Test` functions)"*,
`DEFECT_VOICE_INPUT_DEINIT_ABORT.md:195–196`.

> **If you take the count from a run that exited 4, you bake a truncated total into
> `EXPECTED_TOTAL_RUN` permanently, and the guard silently stops guarding — forever, and with no
> trace.** That is the "reports success while doing nothing" class, installed by following this
> section's own instruction.

**The rule, stated so it cannot be got wrong:**

> **Harvest the count ONLY from a FULL run that exited 5 or 0, with NOTHING excluded.**
>
> **Three ways to get a number that is not a number:**
> 1. **exit 4** — the run was truncated. Not a number.
> 2. **a run with `-skip-testing` or `-only-testing`** — including one that excludes D1's test.
>    Harvesting from it bakes a permanently lowered baseline in **through the front door**, which is
>    the same trap as (1) with the guard's consent. Not a number.
> 3. **exit 2 or exit 3** — see below. Not a number.
>
> **And do not "just exclude D1's test" as a habit.** It is the only coverage of a defect this file's
> own Q3 table calls user-reachable, a process `abort()`, and never fixed in any build. Excluding it
> for one diagnostic run is fine; excluding it standing is how D1 stops being visible at all.

### The other two exit codes, and the run that does not finish

§7 named exit 4 and 5. **There are four**, all documented at `scripts/run-tests.sh:20–27`:

| exit | meaning | why it exists |
|---|---|---|
| **2** | **ZERO tests executed** — *"the silent no-op; never a pass"* (`:20`) | `xcodebuild -only-testing` prints `** TEST SUCCEEDED **` when the filter matches nothing |
| **3** | the build failed, or its status could not be read (`:21`) | a compile failure had been scored as a caught mutation |
| **4** | FEWER tests than declared (`:23`) | D1's abort |
| **5** | MORE tests than declared (`:27`) | the expected case right now |

**Two things that will bite before you ever see an exit code:**

- **ERASE THE SIMULATOR FIRST.** `scripts/run-tests.sh:161` — several UI suites pass from an erased
  simulator and fail from a dirty one. **A clean worktree is not a clean simulator**; both trees
  launch into the same app container.
- **The run may not finish on this machine.** `scripts/run-tests.sh:180–182` records that three
  attempts on 2026-09-12 were **killed by the OS in the compile phase, none reaching a single test**,
  on a 16 GB machine with 7.7 GB of 9.2 GB swap consumed by unrelated processes. Reuse
  `-derivedDataPath` so a retry skips the compile.

**`scripts/run-tests.sh:171–192` is the authoritative version of this entire section** — it carries
the derivation of 1114, why the constant was deliberately left one low, and the scoped evidence that
the added test is real rather than a phantom +1. **Read it before the run; this section is a
pointer, not a substitute.**

**Never pipe `run-tests.sh`** — a pipe replaces its exit code with the tail's, discarding all four.

---

## 8. PHASE 0 — 2026-09-21, HEAD `83da3ce`

Brief: `outputs/BRIEF_MASTER_2026-09-21.md` (Phase 0 at `:89–127`). Each row cites the commit or
file that establishes it. Release cut proposed by the brief (`:317–321`): 1.0.6 = Phase 0 + Reports;
1.0.7 = scanning + guide; 1.1 = sync; 1.2 = family.

### 8.1 The shipped version, and Q3 re-answered against it

**1.0.5 build 10 is live** (§1, recorded). Tag `v1.0.5-build10` re-created on the same commit
`8c98982` with an "approved and released" message and force-pushed 2026-09-21; the old tag object
`443bbfb` is superseded by `787cbe7` (`git ls-remote --tags origin v1.0.5-build10`). Documents
quoting `443bbfb` (`ARCHITECTURE.md:392`, `StoreFixtures/StoreV1_0_5_BUILD10/MANIFEST.md:24`,
`GO_LIVE_CHECKLIST.md:39`, `scripts/capture-store-fixture.sh:99`) describe the earlier object and
are correct as history.

| defect | present in 1.0.5 b10? | reachable by a user today | evidence |
|---|---|---|---|
| D3 migration floor | **NO** — fixed | no | `8c748b7` ∈ `v1.0.5-build10` (§5 table) |
| D2 import cap / aggregate overflow on the recovery journey | **NO** — fixed | no | `1b6be14`, `c2461b3` ∈ tag (§5 table) |
| D10 PDF clips amounts | **NO** — fixed | no | `f7dde93` ∈ tag (§5 table) |
| D7 `idTBD` store link | **NO** — fixed | no | `git show v1.0.5-build10:FinanceTracker/Views/Settings/AboutView.swift` `:59` = `id6784424678`. Regression test added 2026-09-21: `AppStoreLinkTests` (`8e52013`), commissioned red with the competitor ID |
| D8 "Restart onboarding" no-op | **NO** — removed | no | `git grep restartOnboarding v1.0.5-build10 -- FinanceTracker` → 0 hits |
| D9 month-end recurrence drift | **NO** — fixed | no | `anchor: Date` present in tag's `RecurrenceType.swift`; `RecurrenceMonthEndDriftTests` exists |
| D11 rewound clock revives trial | **NO** — fixed | no | tag's `ReverseTrial.swift:58` *"never earlier than the…"*; `AccessManagerTests.swift:143` *"A rewound clock can no longer revive an expired trial"* |
| **D1 VoiceInputService teardown `abort()`** | **YES** | **YES on the code's reading** — never fixed | `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:135`. Founder's device run n≈5–7, no crash — *"bounds a rate, it does not prove simulator-only"* (`BRIEF_MASTER_2026-09-21.md:122–124`). **Stays filed** per brief §0.5 |
| **D5 14 overflow expressions (`AnalyticsSeries` et al.)** | **YES** | **YES** — Analytics traps on an unrepresentable amount | `DEFECT_REGISTER.md` D5, re-counted 2026-09-12. **Scheduled: fixed under Reports (RP1)** |
| **D46 music does not resume after voice input** | **YES** | **YES — every voice entry while audio plays** | founder's device, `BRIEF_MASTER_2026-09-21.md:95–98`. **Fixed in the tree `b3ca3ef`, NOT released, device confirmation PENDING** (§8.2) |
| D4 V2 sentinel | YES, latent | no (fires on V2→V3) | unchanged |

**So the §3.1 question ("still reachable?") answers NO for all five**, D7–D11. None needs a 1.0.6
action beyond the D7 test already added.

### 8.2 D46 — the voice fix, and what is NOT yet established

`b3ca3ef`: `AVAudioSession` now lives only in `FinanceTracker/Services/VoiceAudioSessionController.swift`.
Activation errors propagate; deactivation is retried (100 ms, 250 ms, 500 ms, 1 s) and a final
failure is logged as a `fault`; the activation call no longer passes `.notifyOthersOnDeactivation`.
Guarded by `AudioSessionCallSiteGuardTests` (any other file referencing `AVAudioSession`, or a
`try?` on one inside the controller, fails the suite) and `VoiceAudioSessionControllerTests` (retry
contract). Both observed red under mutants before the fix was restored.

**NOT established: that the swallowed error is the mechanism.** The brief asked for a device
confirmation first (`:104`); no device run with music has happened. The Debug build at `b3ca3ef` is
installed on the paired iPhone 14 Pro (`9B2EADBE-…`). The run is: play music → Quick Entry → dictate
one entry → close → Console.app, subsystem `com.dmitrylogachev.budgetcrab`, category `VoiceAudio`.
Three lines decide it: `othersPlayingAtActivate=true`, then either `deactivated attempts=N` (N>1
confirms "busy") or `deactivate GAVE UP`, then `othersPlayingAfterRelease=true|false`. **Until that
run, D46 is "fixed by construction", which this project does not accept as fixed.**

**Option B, proposed, not chosen** (brief `:109–111`): category `.playAndRecord` with
`[.duckOthers, .defaultToSpeaker]` so music ducks instead of stopping. Cost: the ducked music is
audible to the mic, and `requiresOnDeviceRecognition` models have no noise model for it — a
recognition-accuracy risk with no measurement behind it. Product decision; Dmitry's call.

### 8.3 D1 stays filed — brief §0.5

Nothing in `b3ca3ef` touches `VoiceInputService.deinit`. The three device tests in
`DEFECT_VOICE_INPUT_DEINIT_ABORT.md` §8.4 stay specified and unrun.

### 8.4 TSV export — `COVERAGE_MATRIX.md` row 1 closed

`83da3ce`: `TSVExportServiceTests`, 10 tests. Against the code as shipped, **one was red**
(filename `FinanceTracker_All.tsv` → now `BudgetCrab_All.tsv`); the date-formatter pin could not
compile before the seam existed, so it was commissioned by mutation with two others in one run
(locale `.current`, escaping pass-through, `ru_RU` amounts) — **5 of 10 red, each the test written
for its mutant**. Fixes forced: date formatter pinned to `en_US_POSIX`/Gregorian (a Thai-region
device wrote Buddhist-era years); private decimal formatter replaced by `Money.plainDecimalString`.

Filed, not fixed — `DEFECT_REGISTER.md` **D47**: a split transaction exports as ONE row under its
parent category, so category totals computed in Excel disagree with Analytics for anyone who splits.
Recorded, not a defect: the importer cannot read TSV (sees one column, recognises no header) — the
test pins that so it cannot start being mis-imported silently.

### 8.5 The suite constant

Four test files added today (`VoiceAudioSessionControllerTests`, `AppStoreLinkTests`,
`TSVExportServiceTests`, plus the guard suite inside the first). `EXPECTED_TOTAL_RUN` was **not**
touched: §7's rule stands, the next full run exits 5 and prints the number. **No full run was made
today** — every run was `-only-testing`, so no count from today is admissible.

### 8.6 Contradictions this pass adds to §4

- **4.6** `GO_LIVE_CHECKLIST.md:5` — *"BUILD 10 — CLOSED. Submitted to App Review, awaiting
  verdict."* — is stale: the verdict is in (§1). Not edited there; status lives here.
- **4.7** `DEFECT_REGISTER.md` header and every *"NOT RELEASED"* cell for a build-9/10 fix were
  written for 1.0.4 b8 as current. The register's header now carries the same supersession note as
  this file; the per-row cells were updated for D2, D3, D7–D11 and left as history elsewhere.

### 8.7 Research-instrument finding: notebook `e4a8bc88` is mostly dead pages

Asked fresh (2026-09-21, `--new`, negative control passed) about demand for reports in Budget Crab's
market, notebook `e4a8bc88` (*"FinanceTracker: Market & Pricing Analysis"*) answered: *"The notebook
sources consist primarily of HTTP error/404 pages and the RevenueCat State of Subscription Apps 2026
report"*. `MONETIZATION_FREE_PAID_SPEC.md` cites this notebook. **Any claim attributed to it should be
re-verified against the review corpus or the other notebooks before reuse.** Archived histories of
the four notebooks queried today are in `outputs/notebook_history/`.

Reports design evidence and the demand count from the review corpus (1.08% mentions, 0.22% explicit
asks, N = 4,904) are in `DESIGN_REPORTS_1_0_6.md` §0.
