# STATE — the one page where status lives

**Derived 2026-09-12 from the sources, at HEAD `537e220`. Updated 2026-09-21 at HEAD `83da3ce`
(Phase 0 of `BRIEF_MASTER_2026-09-21.md`) — §8 lists every row that changed and why. Updated
2026-09-22: rule 5 (one authority per kind of fact) and §4.9, after the register and this file
drifted on D46.** No row was written from memory, including mine.

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
5. **ONE authority per kind of fact — added 2026-09-22 after §4.9.** Rule 1 says status lives here
   and nowhere else, and this project then built `DEFECT_REGISTER.md` as a second home for defect
   status. The two drifted on the first update. So, from here on:
   - **`DEFECT_REGISTER.md` is authoritative for DEFECT-level facts** — severity, reachability, which
     shipped versions carry it, regression test, open / fixed / released.
   - **This file is authoritative for PROGRAMME status** — decisions, what each release carries,
     what is blocked. **A defect is mentioned here only as a pointer: `DEFECT_REGISTER.md` + row id,
     plus the programme fact (which release carries the fix).** Never a restated status sentence.
   - A status sentence about a defect in this file that disagrees with the register is a drift; the
     register wins and the drift gets a §4 entry.

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

> **SUPERSEDED — read `DEFECT_REGISTER.md` instead** (rule 5, 2026-09-22): reachability is a
> defect-level fact and the register owns it. §8.1 lists the pointers. The shipped version is
> **1.0.5 build 10**, a recorded fact (App Store lookup). The table below answered for 1.0.4 b8 on
> 2026-09-12 and is kept as history only.

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
| Currently available on the App Store | **1.0.6 build 11, recorded 2026-10-11**: the lookup returns `version 1.0.6`, `currentVersionReleaseDate 2026-10-08T18:15:45Z` (us + ru); build 11 is the only 1.0.6 build uploaded (§11). *Previously:* **1.0.5 build 10**, **recorded 2026-09-21** (supersedes the 1.0.4 b8 inference that stood here from 2026-09-12) | `itunes.apple.com/lookup?id=6784424678` → `version: 1.0.5`, `currentVersionReleaseDate: 2026-09-12T18:22:22Z` (queried 2026-09-21). The lookup carries no build number; **build 10** is the founder's statement, `BRIEF_MASTER_2026-09-21.md:83`, and the only 1.0.5 build ever uploaded per `ARCHITECTURE.md` "Shipped so far" |
| 1.0.5 available | **2026-09-12** | same lookup, `currentVersionReleaseDate` |
| Build 10 contains build 9 | yes | `git merge-base --is-ancestor v1.0.5-build9 v1.0.5-build10` → 0, checked 2026-09-12 |
| In review | 1.0.5 build 10 | `PLAN_TUTORIAL_AND_HELP.md:170`; `DEFECT_VOICE_INPUT_DEINIT_ABORT.md:204` |
| Working tree version | 1.0.5 (10) | `FinanceTracker.xcodeproj/project.pbxproj:477`, `:466` |
| 1.0.0 released | 2026-07-10 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:101` |
| 1.0.3 available | 2026-07-29 | `BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md:98` |
| **1.0.4 available** | **STILL NOT RECORDED** — the public lookup exposes only the *current* version's date, so 2026-09-21 did not settle it | see row R1 — this blank is load-bearing; App Store Connect's version history has it |
| Suite constant | `EXPECTED_TOTAL_RUN=1184` — **observed 2026-09-21** (§9.1), no longer stale | `scripts/run-tests.sh:180` |

---

## 2. THE TABLE

`status ∈ decided-build · decided-skip · open · blocked · awaiting-measurement`
Evidence is the document **and line** that holds the detail, never a summary of it.

### Features and programmes

| id | item | status | blocked by | evidence |
|---|---|---|---|---|
| **F1** | **Family / shared ledger** | **decided-build** — founder's decision 2026-09-21, target 1.2, **design first, no code before approval** (`BRIEF_MASTER_2026-09-21.md:287–288`: *"Measured demand was 0.04–0.14% of 4,904 competitor reviews. Dmitry has decided to build it anyway"*; `:300–303` design doc then STOP). Model fixed by the brief: candidate 5, a separate shared ledger (`:282–286`). Was **open** until 2026-09-21 | SwiftData cannot use the CloudKit shared database; and it sits behind private sync, which has two unbuilt prerequisites of its own | `RESEARCH_FAMILY_ACCESS_2026-08-12.md:3` (status) · `:302–321` (the veto) · `:382` (candidate 5 is the only model that gives privacy AND fits CloudKit) · `:388` (candidate 5 is still behind the veto) · `:412–415` (recommends refusing it in the 1.0.x line) · `:419` (*"That is judgement, not evidence"*) |
| **R1** | **Receipt / screenshot OCR** | **APPROVED 2026-09-21 (§10); BUILDING.** In the tree (see §12): the parser, the recogniser, the capture flow, the review sheet, the prefill into the form, the 5/month cap, the no-network guard, the corpus tooling. **NOT shipped, NOT on the paywall** (`unshippedCapabilities`), **corpus not collected, parser NOT frozen, nothing measured.** Design `outputs/DESIGN_RECEIPT_SCAN.md` (five decisions in its §11; the accuracy bar and corpus are pre-registered in its §7 before any parser exists) — founder's decision 2026-09-21, target 1.0.7, design doc first (`BRIEF_MASTER_2026-09-21.md:177–178`: *"Dmitry has DECIDED to build this; the pre-test was not resolved and must not be described as resolved"*). **The pre-test remains NOT RESOLVED** — the decision overrides it, it does not answer it; T0 is still blank (R1c). Was **awaiting-measurement** until 2026-09-21 | Nothing external. **Of the three gating conditions, R1a and R1b are MET and R1c (T0) is UNRECORDED** — what is missing is that nobody wrote the date down | pre-test `:4` (registered, not resolved) · `:103` (`T0 = ____________`, still blank) · `:199–212` (empty results table) · preconditions verified below |
| **S1** | **iCloud sync (private CloudKit)** | **decided-build**, target 1.1, **design first with family in view** (`BRIEF_MASTER_2026-09-21.md:273–279`, `:300–303`); the technical blockers in the next column are unchanged and are what the design must resolve | (a) the rollback ladder — see L1–L3; (b) the recurrence watermark must move into the synced model | `DESIGN_ICLOUD_SYNC_1_0_4.md:3` (*"**Status: DESIGN ONLY.**"*) · `:539–540` (*"a prerequisite, not an option"*) · `PLAN_RECURRENCE_SYNC_IDENTITY.md:36` (step 3 = **REVIEW-BLOCKED — no code**) · `FEATURE_PREP_BACKLOG.md:179` |
| **V3** | **V3 schema (8 frozen attributes)** | **blocked** | D3 (the sentinel defect) is a prerequisite of *shipping* V3, not only of drilling it; and there is no real V2 store to drill against | `DESIGN_V3_SCHEMA_FREEZE.md:3` (*"no code written yet"*) · `:166–170` (what is needed first) · `DEFECT_V2_MIGRATION_SENTINEL.md:26` · `AUDIT_V3_ROLLBACK_READINESS.md:122` (§6, no real V2 store on this machine) |
| **RP1** | **Reports** | **BUILT 2026-09-21 — in the tree, NOT released; see §9** — design approved 2026-09-21: `outputs/DESIGN_REPORTS_1_0_6.md` approach A; decisions: **P1 premium split**, Analytics entry point yes, monthly always on the 1st, transactions table off by default in year/custom PDFs (`BRIEF_MASTER_2026-09-21.md:331–351`). **Condition: D47 ships in 1.0.6** with a split-heavy equality test commissioned red first (`:353–371`). **Premium rationale, founder's words:** *"no source supports any split (NOT IN SOURCES), and a gate is easy to remove later and painful to add — so start gated, revisit on data"* (`:339–341`). Building (`BRIEF_MASTER_2026-09-21.md:129–163`). Must fix D5's `AnalyticsSeries` overflow under it (`:152–155`) | nothing technical; it needs no schema change | `FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md:46` (*"The verified delta is exactly THREE things. Build these, not a Reports tab."*) · `:48–65` (the three) · `:69` (*"NOT in 1.0.5"*) · `PROPOSAL_1_0_5_SCOPE.md:5` |
| **T1** | **Re-playable tutorial + annotated help → the User Guide** | **APPROVED 2026-10-06 — Dmitry decided, with rulings on all seven §14 questions; see §13. Ships in 1.0.7, alone if scanning slips (§13, 14.7). NOT STARTED: waits on the working-tree review (§13.3).** Was: DESIGN WRITTEN 2026-09-22, AWAITING APPROVAL — `outputs/DESIGN_USER_GUIDE.md` (26 cards + the scanning placeholder, walkthrough, Show-me routing, hints, screenshots, tests, 7 decisions in its §14). Founder's 2026-09-22 scope change: design now for everything shipped + Reports; scanning card is a named placeholder until the sealed run. **The brief's "accounts attach to INCOME only" is contradicted by the build** (both directions) — design §2, decision §14.1. Five false shipped teaching strings filed as `DEFECT_REGISTER.md` D50. Was decided-build, target 1.0.7 (`BRIEF_MASTER_2026-09-21.md:204–268`) | approval | `PLAN_TUTORIAL_AND_HELP.md:10–12` (*"Nothing here is designed yet. Nothing here is scheduled."*) · `:170` |
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

### 4.9 STATE.md and DEFECT_REGISTER.md both carried defect status, and drifted — 2026-09-22

**Second occurrence of the class §4.2 and §4.3 describe** (a status written in two places, one
updated, one not) — and this time both places were files this project built *to end that class*.

- **What happened.** On 2026-09-21 the founder confirmed the D46 music fix on device. §8.2 here was
  updated to *"CLOSED — confirmed on device"*. `DEFECT_REGISTER.md` D46 kept *"mechanism NOT yet
  confirmed on device"*. A context-free session on 2026-09-22 read both and found the disagreement.
- **Why it is structural, not a typo.** Rule 1 said status lives here *"and nowhere else"*; the
  register's header said *"Status lives in `outputs/STATE.md`; this file is its defect half"* —
  and then carried a `status` column. Two files each claiming, or deferring, the same fact is a
  design that drifts on the first update, and it did.
- **The sweep, same day.** Beyond D46: §8.4 still said D47 *"Filed, not fixed"* (fixed under Phase 1,
  `c02b8b0`); §9 still said the music device run was pending (§10 had recorded it confirmed); the
  register's own D3, D8 and D41 status cells still said *"NOT RELEASED"* after 1.0.5 b10 was
  recorded live on 09-21. **Six stale status sentences across two files, all in the same direction
  (stale-open).**
- **Repair.** Rule 5 added (one authority per kind of fact); the register carries an AUTHORITY block
  at its top; §8.1's nine-row status table replaced with pointers; §8.2, §8.3, §8.4 and §9 now point
  to register rows; the register's D3, D8 and D46 cells corrected, each noting what it read before.
- **What makes the repeat impossible rather than merely fixed:** a defect status sentence in this
  file is now itself a rule-5 violation, so the next reader who sees one knows it is wrong before
  checking whether it is stale. Pattern, dates: §4.2 (found 09-12), §4.3 (found 09-12), §4.9 (made
  09-21, found 09-22).

### 4.10 The master brief said accounts attach to income only; the build attaches them to both — RESOLVED 2026-10-06

- `BRIEF_MASTER_2026-09-21.md:236–237` — *"accounts (and the fact that they attach to INCOME only —
  say it, do not let users hunt for it)"*.
- The build attaches accounts to income and expenses (`DESIGN_USER_GUIDE.md` §2).
- **Cause, founder's account:** the reviewer read `add.source.expense_disabled_hint` as a statement
  of behaviour. It is an **orphaned string**, present in all five `.strings` files and referenced by
  no code (D50).
- **Resolved by decision, not by picking a side silently:** Dmitry decided 2026-10-06 that the build
  is the truth (§13, 14.1). The brief's line carries a correction note; its verbatim text is kept.

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

**Rewritten 2026-09-22 under rule 5.** This section used to carry a nine-row table restating each
defect's presence and reachability — the same facts the register owns — and that copy is where the
D46 drift lived (§4.9). Now it carries only pointers and the programme fact for each:

| pointer | programme fact (this file's business) |
|---|---|
| `DEFECT_REGISTER.md` **D2, D3, D7, D8, D9, D10, D11** | fixes are in `v1.0.5-build10` (§5 table; D7 regression test `AppStoreLinkTests`, `8e52013`). **No 1.0.6 action** — the brief's §0.3 question is answered by the register's rows |
| `DEFECT_REGISTER.md` **D1** | **stays filed, not fixed**, per brief §0.5 (`BRIEF_MASTER_2026-09-21.md:122–124`) — a founder's decision, which is why it is recorded here |
| `DEFECT_REGISTER.md` **D5** | 12 of 14 sites fixed under RP1 (§9, `f2ae0a9`) — carried by **1.0.6 b11**; the 2 remaining are out of 1.0.6 scope |
| `DEFECT_REGISTER.md` **D46** | fix `b3ca3ef` carried by **1.0.6 b11**; founder's device confirmation is a recorded decision (§10) |
| `DEFECT_REGISTER.md` **D47** | fix `c02b8b0` carried by **1.0.6 b11** — the founder's condition for the release (§2 RP1) |
| `DEFECT_REGISTER.md` **D48, D49** | fixes `cff1dbf` carried by **1.0.6 b11** (D48 partial — the register says which half) |
| `DEFECT_REGISTER.md` **D4** | unchanged; a prerequisite of V3 (row V3, L1–L3) |

For "is it present / reachable / tested" on any of these, open the register row. Do not answer
from this table.

### 8.2 D46 — the voice fix (defect status: `DEFECT_REGISTER.md` D46)

> **Rule 5 (2026-09-22): the status of D46 lives in the register row, not here.** What this
> section keeps is the programme record — what `b3ca3ef` changed, the founder's decision that
> closed the device question (§10), and the Option B proposal. The "CLOSED" paragraph below is the
> one that drifted from the register on 2026-09-21 (§4.9); it is kept as history, not as status.

`b3ca3ef`: `AVAudioSession` now lives only in `FinanceTracker/Services/VoiceAudioSessionController.swift`.
Activation errors propagate; deactivation is retried (100 ms, 250 ms, 500 ms, 1 s) and a final
failure is logged as a `fault`; the activation call no longer passes `.notifyOthersOnDeactivation`.
Guarded by `AudioSessionCallSiteGuardTests` (any other file referencing `AVAudioSession`, or a
`try?` on one inside the controller, fails the suite) and `VoiceAudioSessionControllerTests` (retry
contract). Both observed red under mutants before the fix was restored.

**CLOSED 2026-09-21 — confirmed on device.** Founder, iPhone 14 Pro, Debug build `b3ca3ef`: *"music
resumes by itself after a dictated entry"* (`BRIEF_MASTER_2026-09-21.md`, second addendum). D46 is
FIXED-and-confirmed in the tree, unreleased until 1.0.6. The What's New music sentence ships.
*(Text below is the pre-confirmation record, kept.)* The brief asked for a device
confirmation first (`:104`); at the time of writing no device run with music had happened. The Debug build at `b3ca3ef` is
installed on the paired iPhone 14 Pro (`9B2EADBE-…`). The run is: play music → Quick Entry → dictate
one entry → close → Console.app, subsystem `com.dmitrylogachev.budgetcrab`, category `VoiceAudio`.
Three lines decide it: `othersPlayingAtActivate=true`, then either `deactivated attempts=N` (N>1
confirms "busy") or `deactivate GAVE UP`, then `othersPlayingAfterRelease=true|false`. **Until that
run, D46 is "fixed by construction", which this project does not accept as fixed.**

**Option B — DECLINED 2026-10-06, decided-skip; reopen only on user evidence (§13).** Was: proposed, not chosen (brief `:109–111`): category `.playAndRecord` with
`[.duckOthers, .defaultToSpeaker]` so music ducks instead of stopping. Cost: the ducked music is
audible to the mic, and `requiresOnDeviceRecognition` models have no noise model for it — a
recognition-accuracy risk with no measurement behind it. Product decision; Dmitry's call.

### 8.3 D1 stays filed — brief §0.5 (defect status: `DEFECT_REGISTER.md` D1)

Founder's decision, not a status: nothing in `b3ca3ef` touches `VoiceInputService.deinit`, and the
three device tests in `DEFECT_VOICE_INPUT_DEINIT_ABORT.md` §8.4 stay specified and unrun.

### 8.4 TSV export — `COVERAGE_MATRIX.md` row 1 closed

`83da3ce`: `TSVExportServiceTests`, 10 tests. Against the code as shipped, **one was red**
(filename `FinanceTracker_All.tsv` → now `BudgetCrab_All.tsv`); the date-formatter pin could not
compile before the seam existed, so it was commissioned by mutation with two others in one run
(locale `.current`, escaping pass-through, `ru_RU` amounts) — **5 of 10 red, each the test written
for its mutant**. Fixes forced: date formatter pinned to `en_US_POSIX`/Gregorian (a Thai-region
device wrote Buddhist-era years); private decimal formatter replaced by `Money.plainDecimalString`.

Filed that day as `DEFECT_REGISTER.md` **D47** (a split exports as one row under its parent
category) — status in the register; programme fact: it became the founder's condition for 1.0.6 and
was fixed under Phase 1 (§9, `c02b8b0`). *(This paragraph read "Filed, not fixed" until 2026-09-22
— a second stale status sentence found by the §4.9 sweep.)* Recorded, not a defect: the importer
cannot read TSV (sees one column, recognises no header) — the test pins that so it cannot start
being mis-imported silently.

### 8.5 The suite constant

Four test files added today (`VoiceAudioSessionControllerTests`, `AppStoreLinkTests`,
`TSVExportServiceTests`, plus the guard suite inside the first). `EXPECTED_TOTAL_RUN` was **not**
touched: §7's rule stands, the next full run exits 5 and prints the number. **No full run was made
today** — every run was `-only-testing`, so no count from today is admissible.

### 8.6 Contradictions this pass adds to §4

- **4.6** `GO_LIVE_CHECKLIST.md:5` — *"BUILD 10 — CLOSED. Submitted to App Review, awaiting
  verdict."* — is stale: the verdict is in (§1). Not edited there; status lives here.
- **4.8** `GO_LIVE_CHECKLIST.md:32–34` calls `test_savingThreeConsecutiveTransactions_…`
  *deterministic* and lists two known reds. §9.2's observations table supersedes it: three tests,
  all intermittent. Not edited there; status lives here.
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

### 8.8 The free/paid line rests on a weak source — filed, not a blocker

Founder's instruction 2026-09-21 (`BRIEF_MASTER_2026-09-21.md:342–344`): `MONETIZATION_FREE_PAID_SPEC.md`
cites notebook `e4a8bc88`, which §8.7 found to be mostly 404 pages, so **the free/paid line as a whole
rests on a weak source.** Not a blocker for 1.0.6. Next action when monetization is next revisited:
re-derive each `e4a8bc88`-attributed claim in that spec from the review corpus or the other notebooks.

---

## 9. PHASE 1 — REPORTS, BUILT 2026-09-21

Design `DESIGN_REPORTS_1_0_6.md` (approach A, approved with four decisions and one condition,
`BRIEF_MASTER_2026-09-21.md:331–`). Every row cites the commit; the red-then-green evidence for each
guard is in that commit's message and, where the red was a crash, in `outputs/crash_harvest/2026-09-21/`.

| commit | what | red observed as |
|---|---|---|
| `4840af2` | week / month / year / custom, previous period, closed-period rule, ASCII identity | 17 pure tests (new type; no prior behaviour to be red against) |
| `f2ae0a9` | **D5: 12 of 14 overflow sites closed** — `AnalyticsSeries`, the one `CategoryBreakdown` fold (replaces three copies), Breakdown/CategoryDetail/DaySpending guards, `TotalsUnavailableCard` extracted | plain-`+` mutants → *"Restarting after unexpected exit, crash, or test timeout"*, `.ips`: *Swift runtime failure: arithmetic overflow* |
| `984542d` | `ReportSnapshot` / `ReportBuilder` (pure, sums nothing itself), `LedgerAggregator.reportInput` off main, **`ReportEqualityCanaryTests`** on the split-heavy fixture: report == MonthTotals == CategoryBreakdown == AnalyticsSeries.pulse/horizon, week == month slice | a last-day-dropping mutant fails 2 of 7 |
| `c02b8b0` | **D47 closed (the founder's condition)**: TSV one row per attributed part, `Split` + `Transaction ID` appended, first eight columns unchanged | `TSVSplitEqualityTests` on today's file: Food 12 700 / Home 5 000 / Health 3 000 vs 9 400 / 6 500 / 4 800 |
| `cff1dbf` | `ReportsView` (Settings row + Analytics toolbar), `ReportsSettingsView`, notifications (policy, scheduler, refresher hook BEFORE the aggregate guard, `AppCapability.scheduledReports`, paywall row), **first `UNUserNotificationCenterDelegate`**, tap → sheet, Siri last-month/this-year → report, `ReportPDFRenderer`, 51 strings ×5 | policy/scheduler/frozen-language tests 31/31 |
| `c03c4b8` | **PDF pixels**: 7 process locales × 7 currencies, ink-diff 0 on every money cell, unavailable page, 120-row year on page 2 through the 1.0.5 allocator | font-fit disabled → USD cell 23 px narrower than its reference |
| `a6a47e9` | **Journey** `PoisonedAnalyticsJourneyTests`: Analytics ×3 → Reports ×3 → PDF, from an erased simulator | five-site mutant → app leaves the foreground on Analytics. A two-site mutant did NOT fail it (the guarded day-net sum bailed first) — recorded |
| `547b85e` | usage summary: `Reports` appended as the LAST line (lines 1–8 keep the decision file's positions) | — |
| `f73e871` | crash-report harvest before the erase, `crashReporterKey` redacted | — |

**What is NOT done, stated plainly:**
- **No version bump.** `MARKETING_VERSION` is still 1.0.5 / build 10. The bump, tag, release branch
  and store fixture happen at submission per `ARCHITECTURE.md` "Releases".
- ~~**The music-fix device run is still pending** (§8.2).~~ Superseded by §10 (confirmed; What's New
  Variant A) — *a third stale status sentence found by the §4.9 sweep, 2026-09-22.*
- **D5's two remaining sites** are out of 1.0.6 scope — which sites and whether they are open:
  `DEFECT_REGISTER.md` D5. The dashboard card's deleted sentence stays deleted until that row closes.
- **The safe-to-spend alert's own tap** is out of 1.0.6 scope — `DEFECT_REGISTER.md` D48.
- **`e4a8bc88`** (the market notebook) is still mostly 404 pages (§8.7).
- The existing `PDFExportRenderTests` / `PDFExportLayoutTests` were **not modified**; the draw helpers
  they pin were opened from `private` to `internal` so the report renderer composes them.

### 9.1 The full suite — SEE THE ROW BELOW; do not read a count from anywhere else

**Run 2026-09-21, erased simulator, unfiltered, `-derivedDataPath build/FullSuiteDD`, HEAD `f73e871`:**

```
executed=1181 passed=1176 failed=5 skipped=3
count: executed+skipped=1184 expected=1113 Δ=+71 → exit 5 (the designed path)
```

`EXPECTED_TOTAL_RUN` set to **1184** from that run (`scripts/run-tests.sh:180`), the 2026-09-12
stale-on-purpose note discharged. The run took ~55 min; `detachForBulkDelete removes the quadratic…`
alone took 682 s while swap peaked at 14.4 of 15.3 GB — memory, not code (`project_full_suite_oom_on_this_mac`).

**The five reds, against the known-failure baseline** (`GO_LIVE_CHECKLIST.md` §0: two known —
`test_editAfterQuickAddInsert_stillOpensEditor` flaky, `test_savingThreeConsecutiveTransactions_…`
deterministic):

| test | verdict |
|---|---|
| `CapabilityMatrixTests` "Every capability is classified" | **mine** — `.scheduledReports` missing from the test's premium list; fixed, 3/3 |
| `LedgerAggregatorTests.burstOfScheduleRefreshCallsCoalescesToExactlyOnePass` / `passesSeparatedInTimeEachRun` | **mine** — the tests counted `removePending` calls as a proxy for refresh passes, and each pass now also removes the two report identifiers; the spy now counts the alert's own identifier. Coalescing itself unchanged; fixed, 3/3 |
| `EditAtScaleReproTests.test_seededRowTap_opensEditor` | ~~not in the baseline~~ — **WRONG, corrected 2026-09-21 (§9.2):** it is red 5/6 in the 2026-08-14 six-run matrix and only absent from GO_LIVE §0's two-name list. Message *"Transactions list never showed rows"*; **passes alone from an erased simulator** (1/1). Residue class, suspected |
| `test_editAfterQuickAddInsert_stillOpensEditor` | known flaky — in the baseline |
| *(absent)* `test_savingThreeConsecutiveTransactions_…` | the baseline's deterministic red **PASSED** this run. Not investigated; noted so the baseline can be re-derived |

**No second full run was made after the two test-only fixes**: they add no tests (count unchanged
at 1184) and each was re-run scoped and green. A reader who wants the whole-suite confirmation runs
it; the constant is already the observed number.

### 9.2 The UI-suite baseline, restated: "deterministic" is falsified — all three are INTERMITTENT

**Correction.** §9.1 first said `test_seededRowTap_opensEditor` was *"not in the baseline"*. It is: the
2026-08-14 six-run matrix (`BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:112–135`) has it red in
5 of 6 runs. It was absent only from `GO_LIVE_CHECKLIST.md:32–34`, which names two tests and calls
one of them *deterministic*. Both tests that document calls deterministic have since passed at least
once, so the label is retired here. **No `outputs/` document dated 2026-08-26 names any of the three**
(`grep -rn seededRowTap outputs/` → the 08-14 brief and this file only); the 2026-08-26 run on record
is the truncated `executed=563` one (`scripts/run-tests.sh:36`).

**Observations — every full or UI-target run on record, oldest first.** R = red, G = green.

| run | date | tree | `seededRowTap` | `editAfterQuickAddInsert` | `savingThreeConsecutive` | source |
|---|---|---|---|---|---|---|
| full ×2 | 2026-08-13/14 | working | G, R | R, R | R, R | `BRIEF_UI_SHARED_CONTAINER_RESIDUE_2026-08-14.md:24–29` |
| UI target W1 | 2026-08-14 | working | G | R | R | `:118` |
| C1 | 2026-08-14 | clean `051f493` | R | R | R | `:119` |
| W2 | 2026-08-14 | working | R | R | R | `:120` |
| C2 | 2026-08-14 | clean | R | R | R | `:121` |
| W3 | 2026-08-14 | working | R | R | R | `:122` |
| C3 | 2026-08-14 | clean | R | R | R | `:123` |
| build-10 confirming run | 2026-09-02 | `8c98982` | **G** | R | R | `GO_LIVE_CHECKLIST.md:25–34`; tag `v1.0.5-build10` message |
| Phase 1 full run | 2026-09-21 | `f73e871` | R | R | **G** | §9.1 |
| scoped, erased | 2026-09-21 | `f73e871` | G (1/1) | — | — | §9.1 |
| full, after the D33 fix | 2026-10-11 | `9584969` | R | **G** | R | §13.6 (machine NOT quiet: concurrent FocusCrab suite) |
| full, CLEAN rerun | 2026-10-11 | `c0da729` | R | R | R | §13.6 (machine quiet; swap 4.6 GB used at start) |
| full, rebooted + one simulator | 2026-10-12 | `9754f74` | R | R | R | §13.8 (quiet; swap 0 at start, peak 13.9 GB at 02:29 in the unit phase, 3.2–4.3 GB through the UI phase) |
| UI target only, failure diagnostics on | 2026-10-12 | `8c281a8` | **G** | R | **G** | §13.9 (swap 2.7 GB residue at start, flat; swap-outs 0 at the red; FocusCrab test run overlapped 03:43–03:45) |

Tallies over the nine unfiltered rows: `seededRowTap` **7 R / 2 G**, `editAfterQuickAddInsert`
**9 R / 0 G** (its "flaky" label is the generous one — on record it has never passed in a full run;
it passes in isolation, `:31`), `savingThreeConsecutive` **8 R / 1 G**. **All three: INTERMITTENT.**

**Suspected shared cause — suspected, not established:** the `wipeLedger` DEBUG launch seam. Every
message is a missing-rows message (*"demo seed missing"*, *"list never showed rows"*, *"Save button
missing for entry #1"*), each class passes in isolation, and the mechanism the 08-14 brief traced —
the first non-scale launch after a scale-seeding class wiping 8 000 rows on the main thread while
the demo seed writes (`:89–98`, D33/D44) — fits all three. It has not been shown to be the cause of
`savingThreeConsecutive`'s "Save button missing".

**LEADING CANDIDATE FOR THE RESIDUAL REDS, 2026-10-12: memory exhaustion from leftover simulators.**
This is measured, not hypothesised. `xcrun simctl list devices booted` showed **six** booted
simulators: iPhone SE (iOS 18.6); iPhone 17 Pro, 17 Pro Max and Air, plus iPad mini (iOS 26.5);
and Apple Watch Ultra 3. CoreSimulator processes summed to **21.5 GB RSS** on a 16 GB M1. RSS
double-counts shared pages, but the order of magnitude holds. Swap was **13.2 GB**. Dmitry shut
them all down and rebooted. The machine rules that followed live in **`~/.claude/CLAUDE.md`**,
which is their only home (`ARCHITECTURE.md` explains why they exist). The mechanism fits the
messages: a launch that cannot finish seeding inside its timeout under swap fails as *"demo seed
missing"* or *"never showed rows"*.

**What this does NOT yet show, written down before the rerun:**

- §13.6 records **no booted device in either set at the start and at the end** of the clean
  rerun (`c0da729`). So the six simulators are **not shown to have been booted during that run**.
  They may have been booted after 22:34, or the check may have missed them. The record cannot say
  which.
- What the record does show is memory pressure in that run, from some source: swap was 4.6 GB at
  the start and 6.1 GB at the end.
- The candidate is therefore *memory pressure*. Leftover simulators are its measured mechanism on
  2026-10-12, not a mechanism proven for 2026-10-11.

**Test:** one full run on the rebooted machine, all simulators shut down, with swap and
`pgrep xcodebuild` / `Simulator` recorded at start and at end. If the three reds vanish, D33's
remaining cause was memory exhaustion, and D33 closes on that evidence. If they survive at low
swap, memory is ruled out and the time-boxed investigation goes ahead. Result: §13.8.

**Consequence, written down:** these three cover **opening the editor, editing after a quick add,
and saving consecutive entries** — the most money-critical UI paths in the app. While they are
intermittent, **a real regression on those paths is indistinguishable from flake in a full run.**
The `wipeLedger` remedy (W1/D33 — off the main thread, or the seam redesigned so a scale class
cannot bleed into the next launch) is therefore the **FIRST item after 1.0.6 ships**. Not in 1.0.6:
Reports touches none of those paths, and the release run's baseline for these three is
"intermittent", read against this table, not against a two-name list.

### 9.2b HYPOTHESIS, 2026-09-24: the three intermittent tests and field report D51 may share a cause

**Not a conclusion.** `DEFECT_REGISTER.md` D51 (TestFlight, 1.0.6 b11, iPhone 13, iOS 26.6.1): on
Analytics, once, the controls above the title stopped responding; a relaunch cleared it. The three
tests above have been attributed to the DEBUG `wipeLedger` seam for a month; a second, independent
sighting of a tap-yields-nothing shape on a **real device in a Release build** means *"test
flakiness"* is no longer the working assumption. The register's D33 row now says its classification
may have been wrong, and what confirms / refutes the shared cause. **Caveat recorded there too: the
tests fail on ABSENT rows / buttons; Elena's control was VISIBLE and dead — same family, different
observable.** Investigation and the reproduction result: §9.4.

### 9.3 Release-candidate rule (founder, 2026-09-21)

The full suite runs on the **exact commit that is archived**, after the version bump, from an
erased simulator, and its count must equal **1184 plus whatever is added** after `52ecdc1`. Scoped
re-runs are evidence for the change they cover, never for the archive. If memory kills the run, that
is reported; nothing is archived on scoped runs.

### 9.4 D51 — the TestFlight report, and the investigation record

**Received 2026-09-24** via TestFlight screenshot feedback. Elena Logacheva, iPhone 13, iOS 26.6.1,
Europe/Moscow, 2026-09-24 12:00, 1.0.6 (11). Verbatim:

> «Один раз был сбой в разделе Аналитика (как на фото). В этот момент всё что стояло над словом
> «Аналитика» вообще никак не реагировало, а что под словом «Аналитика» работало. После выхода из
> программы и входа через минут 20 всё заработало. Проверку повторила в течение дня 3 раза — сбоев
> не было. Всё остальное работает без замечаний.»

Screenshot: Trends (Horizon), Combined, April 2026, +0,00 ₽ — the sticky month tooltip was up.

**Founder's investigation order** (2026-09-24): (1) present/dismiss the Reports sheet from the
Analytics toolbar repeatedly — swipe, button, during a data reload — hit-test probe, not eyeballing;
(2) every other sheet/overlay reachable from Analytics in 1.0.6; (3) whether the report path presents
from a view whose lifetime outlives the sheet. **Reproduce first; an unreproduced report stays open.**
Three follow-up questions are out to Elena (opened a report just before? interruption? did scrolling
revive it?) — **nothing concludes before they arrive.**

**Phase 1 evidence, read at HEAD `553f85c`:**
- Above the title there is exactly one control: the toolbar `analytics_open_report` button
  (`AnalyticsView.swift:136–146`) presenting `ReportsScreen` via `.sheet(isPresented:)` (`:147`).
- Sheets/overlays reachable from Analytics: the Reports sheet (`:147`); the Horizon month sheet
  `.sheet(item: $detailMonth)` (`AnalyticsHorizonView.swift:69–72`, since 1.0.3); the Pulse day sheet;
  inside Reports, the paywall sheet (`ReportsView.swift:120`) and a pushed settings screen. Over the
  whole TabView: `EdgeSwipeHintView` — **cleared**, it is `.allowsHitTesting(false)`
  (`SwipeNavigation.swift:174`); the coach-mark overlay renders only during a coach-mark phase
  (`ContentView.swift:72–86`).
- A second presenter of the same `ReportsScreen` exists on the TabView (`ContentView.swift:187`,
  notification / Siri). Noted; not implicated by the report.
- Nothing in the 1.0.6 diff to `AnalyticsView` / `ContentView` / `Views/Analytics/` beyond `cff1dbf`
  (the toolbar button + sheet) and `f2ae0a9` (overflow guards) — `git log v1.0.5-build10..v1.0.6-build11`.
- Known class, web (Apple developer forums 131404, 685163, 692338): a toolbar button dead after a
  swipe-dismissed sheet in NavigationStack/TabView, revived by scrolling. Old threads; iOS 26
  status unknown from sources. **Elena's third question (scrolling) is the discriminator.**

**Reproduction attempt 1 — 2026-09-24, iPhone 17 Pro / iOS 26.5 simulator, ERASED before each run,
Debug build at `553f85c` + the probe, `AnalyticsToolbarAfterSheetProbeTests`, via `run-tests.sh`
(scoped; executed counts printed, so no zero-test pass):**

| variant | cycles | result |
|---|---|---|
| Reports sheet → dismissed by **swipe** → toolbar probe | 8 | passed, 8/8 presented |
| Reports sheet → dismissed by **Done** → probe | 8 | passed |
| Reports sheet → swipe-dismiss **interrupted by Home**, 2 s background, reactivate → probe | 8 | passed |
| Horizon: scrub → month tooltip → **month sheet** → swipe-dismiss → probe | 8 | passed (run 2; run 1 failed at cycle 2 on a **test-scaffolding** defect — the scrub was anchored on the hint text, which the sticky tooltip replaces; timing is consistent with cycle 1 having completed the probe) |
| Horizon: sticky tooltip **up** (the screenshot state) → Reports sheet → swipe-dismiss → probe | 8 | passed; the tooltip survived every cycle |

Probe = `isHittable`, then a tap that must **present** the Reports screen (`reports_kind_picker`);
on a miss it would have recorded window count, a scroll-revive attempt and the accessibility tree.
**No miss occurred. NOT REPRODUCED. D51 stays OPEN.**

**What this attempt did NOT exercise, stated so it is not read as clearance:**
- a **data reload while a sheet is up** (founder's item 1c) — no in-app path changes the ledger
  under a presented sheet without new code; the closest existing trigger (foreground refreshers on
  reactivation) was covered by variant 3 only;
- **iOS 26.6.1 on a device**, a **Release** build, an iPhone 13 — the simulator is 26.5 / Debug;
- a real **interruption** (incoming call, Face ID prompt, a system alert) mid-transition;
- the two-presenter case: a **report notification tap while the toolbar's Reports sheet is up**
  (`ContentView.swift:187` vs `AnalyticsView.swift:147`) — SwiftUI would refuse the second
  presentation and `pendingReport` would stay set; that stalls the *notification* route, not the
  toolbar, so it does not explain Elena's report, but it is a sibling of the same class and is noted.

**Item 3 (view lifetime) — answered from code, no:** `AnalyticsHorizonView` is built structurally in
`switch screen` with no `.id` (`AnalyticsView.swift:170–191`), so `recompute()` keeps its identity
and its `detailMonth` / sticky state; both `ReportsScreen` presenters hang off long-lived views.

**Next, in order:** Elena's three answers (the scrolling one is the discriminator for the known
SwiftUI class); if "yes, just opened a report" or "yes, an interruption", add the interruption
variant on a **device** build; if the 26.6.1 runtime becomes available in Xcode, re-run all five
there. The probe file stays in the tree as a probe (its header says so); it is not a guard and it
does not enter the known-failure baseline.

---

## 10. DECISIONS RECEIVED 2026-09-21 (second addendum to the brief)

Recorded here so they exist (rule 1). Source: `BRIEF_MASTER_2026-09-21.md`, addendum "TWO DECISIONS
ARRIVED", appended verbatim below the Phase 1 approval.

| item | decision |
|---|---|
| D46 music fix | **confirmed on device** (§8.2 closed) |
| What's New 1.0.6 | **Variant A, with two changes**: markers stripped; the share/reminder sentence states the free/premium line truthfully — verified against `ReportsView.exportCapability` and `AppCapability.requiresPremium` before finalising. Final text: `ASC_WHATS_NEW_1_0_6.md` (FINAL) |
| 1.0.6 release pass | bump to build 11 → full run on THAT commit, erased simulator, count 1184 + additions, reds read against §9.2's three INTERMITTENT tests → archive → `-exportArchive` upload → tag `v1.0.6-build11` + `release/1.0.6` → store fixture → `ShippedStoreShapeTests` → report. **No submission** — Dmitry does that |
| R1 receipt scanning | **approach A APPROVED.** Premium **S1** (5 free scans/month, then paywall). Attachment **deferred to 1.0.8**. Real paper photographs: **Dmitry supplies** — en and ru first, es-MX/pt-BR/uk as available; a locale without ≥ 10 REAL paper photos is **uncertified for paper** and ships paper scanning with the permanent "check the amount" line; screenshots certified separately, collectable for all five. Ukrainian: **check `VNRecognizeTextRequest.supportedRecognitionLanguages()` at the deployment target in code**; if `uk` is missing, recognise with ru + en and **measure** the uk corpus against the same bar — the measurement decides. **HELD-OUT SET:** the frozen corpus is split by SHA-deterministic assignment BEFORE any parser work into a DEV half (tune against) and a SEALED half (run ONCE after the parser is frozen; record the parser commit). A sealed miss is reported, never tuned-and-re-run; a new sealed set is collected instead. Parser, capture flow and unit tests may be built before the corpus exists |
| Next | collection guide for Dmitry (one page) → Phase 2 build |

---

## 11. 1.0.6 (BUILD 11) — LIVE 2026-10-08 (uploaded 2026-09-21, submitted ~2026-10-01)

| fact | value | evidence |
|---|---|---|
| release commit | `3473c5c` (`chore(release): bump to 1.0.6 (build 11)`) | `git rev-parse v1.0.6-build11^{commit}` |
| full suite ON that commit, erased simulator, unfiltered | `executed=1181 passed=1178 failed=3 skipped=3`; `executed+skipped=1184 expected=1184 Δ=+0`; **exit 1** | tag message; the run's bundle is session-local |
| the three reds | exactly `seededRowTap`, `editAfterQuickAddInsert`, `savingThreeConsecutive` — §9.2's three INTERMITTENT tests; **nothing else red** | tag message |
| archive | `build/BudgetCrab-1.0.6-11.xcarchive`, built from a clean worktree at `3473c5c`; app and widget Info.plists read **1.0.6 / 11** | `plutil -p` on both, 2026-09-21 |
| upload | `xcodebuild -exportArchive` with a copy of `ExportOptions.plist` whose ONLY difference is `destination = upload` (`manageAppVersionAndBuildNumber` false); *"Upload succeeded"*, no sign-in prompted | xcodebuild output 21:31:36 |
| tag / branch | `v1.0.6-build11` (annotated, on `3473c5c`), `release/1.0.6` — both pushed | `git ls-remote --tags origin` |
| store fixture | `StoreFixtures/StoreV1_0_6_BUILD11` from the tagged commit: 33 transactions, sum 635473, 13 categories, 3 sources; `ShippedStoreShapeTests.test_v1_0_6_build11_storeOpens` added, 10/10 | `MANIFEST.md`, commit `3473c5c` recorded there |
| **submitted for review** | *(as of 2026-09-21)* **NO — Dmitry does that in App Store Connect.** What's New to paste: `ASC_WHATS_NEW_1_0_6.md` (FINAL) | — |
| tag message to amend on approval | "approved and released" + date, `git tag -f -a`, force-push the tag (`ARCHITECTURE.md` Releases) | — |
| **submitted** | **around 2026-10-01 — Dmitry's statement**, received 2026-10-06; not otherwise recorded (no ASC access from here) | founder's brief of 2026-10-06, item 4a |
| **live?** | **YES: 1.0.6 is live, released 2026-10-08T18:15:45Z. Recorded 2026-10-11 from the lookup** (us and ru storefronts both return `version 1.0.6`, `currentVersionReleaseDate 2026-10-08T18:15:45Z`). Tag `v1.0.6-build11` re-created 2026-10-11 on the same commit `3473c5c` with an "approved and released" message carrying that date, and force-pushed. Tag object `a16ee1a` supersedes `dbce5fa` (`git ls-remote --tags origin v1.0.6-build11`). Register rows D5, D46–D49 were moved to RELEASED in the same pass, each fix commit checked as an ancestor of the tag. *Was "NO as of 2026-10-07", from the query below:* | `itunes.apple.com/lookup?id=6784424678&country=us` (queried 2026-10-07) → `version 1.0.5`, `currentVersionReleaseDate 2026-09-12T18:22:22Z`. The lookup is one storefront and can lag a release by hours; re-query before acting |

---

## 12. PHASE 2 — RECEIPT SCANNING, BUILD IN PROGRESS (2026-09-21)

| commit | what | red observed as |
|---|---|---|
| `054ef9f` | `ReceiptParser` (pure, keyword-ranked, never largest-number) + 23 tests | largest-number mutant: 10 of 23 red |
| `a8ad92e`, `1930853` | `ReceiptRecognizer` (Vision, app language first), `ReceiptScanQuota` (5/month, S1), `AppCapability.receiptScan` (counted cap, in `unshippedCapabilities` — no paywall row until it ships), `ReceiptScanButton` in Quick Entry and the form, `DocumentCameraView`, `PhotosPicker`, `ReceiptReviewSheet` (two shapes, no Save), `AddTransactionPrefill` gains `date`/`note`/`origin`, usage signal after save, camera usage string ×5, 17 strings ×5 | `NoNetworkInScanModuleTests`: red with a planted `URLSession` |
| `a8ad92e` | `ReceiptCorpusTests`: frozen-manifest check, SHA-parity DEV/SEALED split, reporter table, §7.3 bar; SEALED only under `RECEIPT_SEALED_RUN=1` with `RECEIPT_PARSER_COMMIT` | skips visibly until `FinanceTrackerTests/Fixtures/Receipts/manifest.csv` exists |

**Facts established in code, not assumed:** Vision here lists `en-US ru-RU es-ES pt-BR uk-UA` —
**Spanish is `es-ES` (no `es-MX` model)** and **`uk-UA` IS supported** on this SDK
(`VisionLanguageSupportTests`, which re-asks on every run and reports the answer). On an iOS 17
device the runtime asks again and falls back to ru + en for uk if absent.

| `423f020` | **Journey + cap UI tests** through the REAL recogniser (`--scan-fixture-text`, DEBUG-only seam registered in `ReleaseDebugAffordanceTests`; Release binary checked directly: argument 0 / symbol 0, Debug dylib 1 / 27, unrelated literal present in both as control). Journey: scan → 6.04 not the 5.59 subtotal → prefilled form → saved → second scan shows the learned category. Cap: 5th works, 6th meets the paywall (presence), last month's count ignored. Two defects found and fixed: the prefill handed through a separate `@State` read as nil by the sheet closure (now carried in the sheet item); quota writes persisting across UI tests. es-MX corpus cells labelled "recognised es-ES" | dropped-amount mutant → red at the prefill wait |

**What has NOT happened:** no corpus (Dmitry supplies paper; `RECEIPT_CORPUS_COLLECTION_GUIDE.md`),
no freeze, no split, no measurement, no paywall row, no What's New. The
scanner is reachable in a Debug build; **it must not ship until the sealed half has been run once
and reported** — and the paywall row and `unshippedCapabilities` move in that same commit.

---

## 13. DECISIONS RECEIVED 2026-10-06 — Dmitry decided, 2026-10-06

Source: the founder's brief of 2026-10-06, relayed from the review conversation. Recorded here
because they were made in that conversation and had not reached the repo (rule 1). Each reason is
the one given with the decision.

### 13.1 `DESIGN_USER_GUIDE.md` — APPROVED, with rulings on its §14

| § | Dmitry decided, 2026-10-06 | reason given |
|---|---|---|
| 14.1 | **Accounts attach to BOTH income and expenses. The build is the truth.** Delete `add.source.expense_disabled_hint` in all five locales with D50's batch. Record the incident in `ARCHITECTURE.md` next to the comment rule. Sweep for other orphaned strings that assert behaviour. Correct the master brief's line (done as a correction note, §4.10) | the brief's "income only" came from reading an orphaned string as behaviour; *"a UI string can go stale exactly like a comment"* |
| 14.2 | **YES**: the Guide absorbs the six help articles; "Set up Widget & Siri" is dropped | *"Two homes for help drift exactly as two homes for status did"* (§4.9) |
| 14.3 | **Per-locale screenshots, under a size budget.** Compress hard. **If the delta exceeds ~10 MB, come back with options instead of shipping it.** Note: the design's own estimate is ~10–16 MB (`DESIGN_USER_GUIDE.md:781`), so the budget is expected to bind | the app is ~5.8 MB and the funnel is already thin |
| 14.4 | **SHOW walkthrough step 3 without a budget.** The sample figures must be **unmistakably marked as an example** | *"a number that looks like the user's own data is a false claim"* (§2.8) |
| 14.5 | **YES**: fix C1–C5 (`DEFECT_REGISTER.md` D50) in the same release | — |
| 14.6 | **THREE hints, not seven:** the monthly budget, a category limit, the Guide itself. Add more only when measurement shows what users fail to find | these are the three the pre-registered acceptance test turns on |
| 14.7 | **YES**: the Guide ships alone in 1.0.7 if scanning slips | *"the only engineering item that touches conversion rather than traffic"* |

### 13.2 D46 Option B — DECLINED, decided-skip

Option A (music resumes after dictation) shipped in 1.0.6 b11 and was confirmed on device (§10).
**Reason:** the complaint was *"music does not come back"*, not *"music stops"*. Ducking would leave
music audible to the microphone during on-device recognition, an unmeasured accuracy risk with no
complaint behind it. **Reopen only on user evidence.** Defect status: `DEFECT_REGISTER.md` D46.

### 13.3 Unexplained working-tree changes to the test gate — HOLD released 2026-10-11 (approved)

**No commit, no revert and no suite run until Dmitry has reviewed the report.** Reason: *"An
unreviewed change to the test gate invalidates every verdict that runs through it."*

Report delivered 2026-10-07, **awaiting review**:
- `scripts/run-tests.sh`: 3 lines added after `cd "$REPO_ROOT"`, `trap 'scripts/sim-clone-cleanup.sh' EXIT`. mtime 2026-10-04 16:45:27.
- `scripts/sim-clone-cleanup.sh`: new file, mtime 16:47:04.
- **Origin:** a Claude session started in `~` (transcript `~/.claude/projects/-Users-dmitrylogachevusa/ca862344-….jsonl`), running Dmitry's 2026-10-04 "Disk is full" brief. Its PREVENTION item asked for a cleanup step in the test scripts of FocusCrab, FinanceTracker and ybg-ios. The session applied the change at 23:45:26Z and rewrote the script's `find` at 23:47:03Z, matching both mtimes. That session's verification run was in **ybg-ios, not FinanceTracker**.
- **CROSS-PROJECT (recorded at Dmitry's instruction, 2026-10-11):** the cleanup does not know which project made a clone. When FinanceTracker's gate exits, it deletes **every** project's clones in the testing device set, as long as no `xcodebuild` is running at that moment. It also deletes every `$TMPDIR/Deleting-*` folder older than 30 minutes. Acceptable, but it must be known: a FocusCrab or ybg-ios run that has just finished loses its clones to a FinanceTracker run, and the reverse is also true.
- **APPROVED 2026-10-11 (Dmitry), with one change made in review:** the trap uses an **absolute** path, `"$REPO_ROOT/scripts/sim-clone-cleanup.sh"`. A relative path would turn into a silent no-op after any later `cd`.
- **The first full run after this commit is the trap's first run in this repo.** That run's report must say so.
- **Effect on exit codes:** a bash EXIT trap does not change the exit status. Checked 2026-10-07 for exit codes 0, 1, 3, 4 and 5 with a failing trap, and for exit 4 with a missing trap target: each code is preserved.

### 13.4 Order of work, as given

(a) App Store lookup: **1.0.6 not live on 2026-10-07** (§11), tag not amended → (b) working-tree
report (§13.3) → (c) if 1.0.6 is live: D33/`wipeLedger`, **time-boxed**, starting with a size estimate.
If it is more than a bounded piece of work, report it and interleave it with the Guide → (d) build
the Guide. Stop with the acceptance-test run, the screenshot size delta, and What's New in five
languages.

**Unblocked 2026-10-11:** 1.0.6 is live (§11) and the gate change is approved (§13.3). Order: tag amend → D33 size estimate → Guide.

### 13.5 Still with Dmitry. Do NOT mark any of these resolved without his material

Receipt photos (R1) · Elena's three D51 answers (`DEFECT_REGISTER.md` D51) · T0, the 1.0.4 live
date from ASC version history (R1c) · the ASC product-ID list (`DEFECT_REGISTER.md` D22). He is
sending screenshots for the last two.

### 13.6 D33 / `wipeLedger`, time-boxed (2026-10-11)

**Size estimate: bounded.** The code change is one function plus its guard. The cost that is not
bounded is evidence: only full runs can show whether the three intermittent tests (§9.2) are cured.
**Code done:** red 50 070 ms against a pre-registered 5 s budget → green. Defect status:
`DEFECT_REGISTER.md` D33. **Programme fact: NOT yet verified against the UI suite.** The next full run
from an erased simulator is the first evidence, and it is also the first run of the cleanup trap in
this repo (§13.3). Read its three tests against §9.2's table, never against a two-name list.

**THE RUN, 2026-10-11 16:42–17:50, erased simulator, unfiltered, HEAD `9584969`:**

```
executed=1223 passed=1218 failed=5 skipped=5
count: executed+skipped=1228 expected=1184 Δ=+44 → exit 5 (the designed path)
```

- **Count.** `EXPECTED_TOTAL_RUN` set to **1228** from this run (`chore(test)` commit). The +44 are
  the tests committed between `f73e871` and `9584969`.
- **Two reds were MINE, not the tree's.** `LocaleCompletenessTests` `testAllLocalizedKeysExist` and
  `testNoMissingLocalizationKeys` scan the SOURCE TREE at run time, not the build. They read the
  uncommitted Guide step-1 file I was writing during the run. Its storage keys
  (`guide.walkthrough.outcome` …) have the shape of localization keys. **This was a contamination
  of the run by working-tree edits, and it is a rule for this file now: no source edits during a
  full run either, not only no commits.** The keys were renamed out of that shape before step 1
  was committed.
- **The three intermittent tests:** `seededRowTap` R (*"Transactions list never showed rows"*, 164 s,
  inside its own scale class). `editAfterQuickAddInsert` **G**: the first green in a full run on
  record (0 of 9 before). `savingThreeConsecutive` R (*"Save button missing for entry #1"*).
- **A FOURTH test with the same message:** `EditPresentationReproTests.test_editPopBack_thenEditAgain_opensEditor`
  R, *"no rows (demo seed missing)"*. It is not in the table above. **No scale class ran before it**
  (the preceding class, `EditPresentationInterleavedTests`, seeds nothing large), so `wipeLedger`
  cannot explain it.
- **The mechanism's own cases.** The first non-scale launch after a scale class happened 4 times:
  `DuplicateReviewFlow` after `BulkDeleteStall` (G), `editAfterQuickAddInsert` after `EditAtScale` (G),
  `MonetizationGateFlow` after `MainThreadHangScale` (G), and `savingThree` after
  `SearchRecomputationRegression` (R).
- **Confound.** Another project's `xcodebuild` (FocusCrab) was running at the start and at the end of
  this run. Under that load a red is weak evidence and a green is strong evidence.
- **VERDICT: D33's cost is fixed; the UI tests are NOT cured.** Three of four post-scale launches now
  pass, against a history of near-universal red. But "missing rows" persists, including once with no
  scale class in front of it. So the seam was A cause, not THE cause. The remaining cause is
  unidentified. Open in `DEFECT_REGISTER.md` D33.
- **The trap's first run here.** It exited with the script's own status (`exit=5` recorded after the
  trap), which is the property the review required. It had nothing observable to clean: the testing
  device set was empty and there were no `Deleting-*` folders. This suite runs with parallel testing
  off, so it makes no clones. And with FocusCrab's `xcodebuild` alive at exit, the `pgrep` guard
  would have skipped the delete anyway. **Not observed doing a deletion.**

**Decided 2026-10-11, on review of the run above (overrides the "NOT cured" verdict's reading):**
the residual reds are **not yet evidence of a second cause**. The run was contaminated: another
project's suite was running on this machine, and "demo seed missing" is what a launch looks like
when it does not finish seeding inside its timeout under swap. The new red with no scale class in
front of it is consistent with that too. **No open-ended investigation.** Instead:

1. **ONE CLEAN RERUN.** Erased simulator, unfiltered, nothing else running, checked by `pgrep`
   for xcodebuild AND Simulator at start and at end, both checks in the report. Run it at the
   Guide's first natural commit point. No source edits during it.
   - Reds survive → a second cause exists. Open a time-boxed investigation, plan reported first.
   - Reds vanish → record the 2026-10-11 reds as contamination by a concurrent suite. D33
     closes on the clean run.
   - Either way, add the run to §9.2's table.
2. **Rule: one full test run per machine, across projects.** Recorded in `ARCHITECTURE.md`
   ("One full test run per machine") and in `run-tests.sh`'s header. The wrapper now warns at
   start and prints a `── machine:` verdict line. It warns, never refuses. **Commissioned:** a
   fake `xcodebuild … test` process → warning at start, "NOT QUIET … at start and end" in the
   verdict. With none → "machine: quiet".
3. **Cleanup trap commissioned (negative control for the destructive step).** In a scratch dir:
   `Deleting-OLD` (mtime 09:00, holding a `uchg` file that a plain `rm` refused),
   `Deleting-NEW` (fresh) and `Other-OLD` (09:00). The script (via the new `SIM_CLONE_TMPDIR`
   seam) exited 0 and removed **only `Deleting-OLD`**, flagged file included. The other two
   survived. The testing device set was empty before, so the `simctl delete all` branch had
   nothing to remove.

**THE CLEAN RERUN, 2026-10-11 21:32–22:34, erased simulator, unfiltered, HEAD `c0da729`:**

```
executed=1237 passed=1233 failed=4 skipped=5
machine: quiet (no other xcodebuild test run at start or at end)
count: executed+skipped=1242 expected=1228 Δ=+14 → exit 5 (the designed path)
```

- **Machine checks.** At start and at end: no other `xcodebuild`, no `Simulator.app`, no booted device
  in either set. **Caveat:** "quiet" here means no other test run. It does not mean low memory. Swap
  was 4.6 of 6 GB used before the run and 6.1 of 7 GB at the end.
- **Count.** `EXPECTED_TOTAL_RUN` set to **1242** from this run. The +14 are today's step-1 and
  Settings-stack tests.
- **The intermittent tests all stayed red:**
  - `seededRowTap`: *"never showed rows"*, 161 s, inside its own scale class.
  - `editAfterQuickAddInsert`: *"no rows (demo seed missing)"*. It was green in the contaminated run.
  - `savingThreeConsecutive`: *"Save button missing for entry #1"*.
- `editPopBack_thenEditAgain` passed. Its red in the contaminated run is consistent with
  contamination.
- **Post-scale first launches:** `DuplicateReviewFlow` after `BulkDeleteStall` G,
  `editAfterQuickAddInsert` after `EditAtScale` **R**, `MonetizationGateFlow` after
  `MainThreadHangScale` G, `savingThree` after `SearchRecomputationRegression` **R**.
- **VERDICT under the 2026-10-11 rule: the residual reds survive a clean run, so a second cause
  exists.** D33's cost fix stands (guard green, 15 s), but it is not sufficient. Per the decision, a
  time-boxed investigation plan is reported to Dmitry **before** any of it is spent. D33 stays OPEN.
- **One unrelated new red:** `VoiceAudioSessionControllerTests` "a busy session is retried until it
  releases". The outcome and call count were right (3 attempts), but the recorded `sleeps` read back
  `[]`. It is first seen red here and not investigated. Register D52.

### 13.7 Guide step 2 — the R1 guard, written before the Settings stack is touched (2026-10-11)

`FinanceTrackerUITests/SettingsStackDeepPopTests`, two tests:
- **(a)** Settings → Learn & Tips → article → back → back → General opens. 3 cycles.
- **(b)** Same depth, leave the tab, come back. Settings is at its root and General opens.
  3 cycles.

All runs below were on a quiet machine (the wrapper's `── machine:` line).

| variant | (a) | (b) |
|---|---|---|
| today's code | G | G |
| mutant 1: bound `NavigationPath`, `.id` reset kept | **G** | — (not yet written) |
| mutant 2: the exact pre-fb9c075 shape (bound path, reset by assigning the path, no `.id`) | R, *"Test crashed with signal term"* at the FIRST Settings open, no crash report | **R**, *"returning to Settings did not land on its root"* |
| mutant 3: General's row opens the wrong screen | **R**, the R1 assertion's own message | — |

**What this does and does not show:**
- **R1 itself did not reproduce on iOS 26.5.** Mutant 1 stays green, and mutant 2's (a) died
  before any deep pop. So (a) is commissioned only against "General does not open" (mutant 3),
  not against the June mechanism.
- **(b) is commissioned against a real failure of the old shape:** assigning a fresh path does not
  pop screens pushed by destination links. That is exactly the failure the conversion must not
  bring back.
- Mutant 2's SIGTERM is unexplained and was not chased. It is not R1, and that shape is not being
  re-introduced.

### 13.8 D33 decider — full run on a rebooted machine, one simulator (2026-10-12)

**THE RUN, 2026-10-12 02:08–03:09, HEAD `9754f74`, erased iPhone 17 Pro, unfiltered:**

```
executed=1237 passed=1233 failed=4 skipped=5
machine: quiet (no other xcodebuild test run at start or at end)
count: executed+skipped=1242 expected=1242 Δ=+0 → exit 1 (real reds)
```

**Machine checks.** Before the run (02:08:53): the machine had been rebooted, swap was **0**, there
was no `xcodebuild`, no `Simulator.app`, and no booted device in either set. After the run
(03:09:53) there was no `xcodebuild`, no `Simulator.app` and no booted device, and swap was 1.86 GB.
Swap, booted devices and `xcodebuild` processes were sampled every 2 min. Booted devices: 0 at the
first sample, then 1 throughout.

**One open item in the quiet check:** the **02:45 sample counted 2 `xcodebuild` processes**. Every
other sample counted 1. The sampler did not record arguments, so this sample cannot tell our run's
own child process from another project's run. At 02:45 `EditAtScaleReproTests` was running, and it
is the class `seededRowTap` belongs to. **Not resolved.**

**The intermittent tests:**

- `seededRowTap` (`EditAtScaleReproTests`, started 02:43:48): **R**, *"Transactions list never
  showed rows"*.
- `editAfterQuickAddInsert` (`EditPresentationInterleavedTests`, 02:48:36): **R**, *"no rows (demo
  seed missing)"*.
- `savingThreeConsecutive` (`SecondTransactionCrashTests`, 03:03:32): **R**, *"Save button missing
  for entry #1"*.
- `editPopBack_thenEditAgain`: **G**.

**A fourth red, new on record:** `AnalyticsToolbarAfterSheetProbeTests.test_reportsSheet_
backgroundedDuringSwipeDismiss_toolbarKeepsPresenting` failed with *"the Reports entry point is
missing from Analytics"*. That message is the probe's PRECONDITION failing: the element was absent.
It is **not** D51's observable, which is a visible control that does not respond, so it is **not a
reproduction of D51**. It was the first UI class to run (02:36:12), straight after the unit phase.
Not investigated. `VoiceAudioSessionControllerTests` (D52) passed.

**Swap series** (`sysctl vm.swapusage`, used, sampled every 2 min):

| time | 02:09 | 02:15 | 02:17 | 02:21 | 02:27 | **02:29** | 02:31 | 02:35 | 02:43 | 02:51 | 03:01 | 03:09 | end 03:09:53 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| GB | 0 | 4.3 | 4.9 | 10.2 | 6.2 | **13.9** | 4.7 | 4.3 | 3.5 | 3.4 | 3.3 | 3.2 | 1.9 |

The samples not shown in the table lie between their neighbours. Phases, from the result bundle:
the unit tests ran from about 02:10 to 02:36, and the UI tests from 02:36:12 to about 03:09.

- **The peak (02:29) fell in the unit phase.** The bundle cannot say which class was running then.
  Only 4 of 153 unit classes carry timestamps, and Swift Testing runs suites concurrently, so it may
  not have been one class. The longest unit tests are the bulk-delete scale measurements: 689 s,
  319 s and 290 s, out of 1 509 s of summed unit-test time. They are the likely occupants of
  02:21–02:29. **That is not shown.**
- **During the UI phase, where all four reds happened,** swap used was 3.2–4.3 GB and falling
  slowly. Swap used is residue: these samples do not show whether paging was happening at the
  moment of each red, because pageouts were not sampled.

**[DROPPED by founder 2026-10-16: the laptop decision is no longer pending (§13.11).]** **MEASUREMENT FOR DMITRY: is a 16 GB M1 enough for this workload?** This is **the suite WITH the scale measurements**. The number that decides the laptop question is the peak of a full run AFTER the bulk-delete benchmarks are split out (§13.9 proposal), and it is not yet measured. Conditions: freshly rebooted,
one simulator, quiet machine, a full run of this suite. **Peak swap used was 13.9 GB, well above
~8 GB.** Swap total grew to 15 GB at that sample. These are 2-minute samples, so the true peak was
at least this high and may have been higher. Through the UI phase it stayed at 3–4 GB. That is all
the series shows.

**VERDICT under the rule set 2026-10-11: the three reds survive on a quiet, rebooted machine with one
simulator, so a second cause exists, and D33 does NOT close.** The leftover-simulator mechanism is
ruled out for these reds: none were booted. *Memory pressure as such* is **not** ruled out. The run
made 13.9 GB of swap by itself, and pageouts at the moment of each red were not measured. Per the
decision, a time-boxed investigation plan goes to Dmitry before any of it is spent. D33 stays OPEN.

### 13.9 Failure diagnostics, then the UI target alone (2026-10-12)

**What the recordings already showed.** Xcode recorded the screen for all four reds of the §13.8 run,
and those recordings sit in its bundle. In every one, the app is on the **Dashboard with data on
screen**, and nothing covers it: no paywall, rating prompt, tour or What's New sheet. Each test
had just tapped a **tab-bar button**:

- `seededRowTap` and `editAfterQuickAddInsert` tapped Transactions.
- `savingThree` tapped `+`. Its typing landed in the Dashboard's Quick-add field because the
  QuickEntry sheet never opened, which is why its Save button was "missing".
- The D51 probe tapped Analytics.

In all four the screen never changed. Every failure message names an absent element ("no rows",
"demo seed missing", "Save button missing", "Reports entry point missing"). That absence is the
consequence. The shared observable is **a tab-bar tap after launch that does not take effect**.

**Diagnostics shipped (`8c281a8`).** Every UI failure now attaches the following, once per test:

- a full-screen screenshot;
- the app's hierarchy and SpringBoard's;
- the launch timeline (`LaunchTimeline`, DEBUG): seeding finished at +X s, and the failure came
  at +Y s.

It is wired in through `NSPrincipalClass`, so no test class opts in. It was commissioned with a
deliberate red: one set of four attachments for two failures, and the timeline's pid matched the
app. A sampler (`scripts/machine-sampler.sh`, `0057b83`) logs per-interval swap-ins and swap-outs
and names every `xcodebuild`.

**THE RUN, 2026-10-12 03:39–04:14, `-only-testing:FinanceTrackerUITests`, erased iPhone 17 Pro:**

```
executed=64 passed=63 failed=1 skipped=0
```

- `seededRowTap` **G**, `savingThreeConsecutive` **G**, D51 probe **G**, `editPopBack` **G**.
- `editAfterQuickAddInsert` **R**, *"no rows (demo seed missing)"*. The app launched at 03:52:03.
  The diagnostics show:
  - **Launch timeline:** seeding was done at **+3.14 s** (33 rows), and the failure came at
    **+19.55 s**. So the seed was not missing.
  - **Screenshot:** the Dashboard, with data loaded and rows visible. Nothing covers the screen.
  - **Hierarchy:** the tab bar is present, **`Dashboard` is `Selected`** and `Transactions` is
    not. The test had tapped Transactions and waited 15 s.
- **Memory at the red:** swap-outs were **0** in the samples on both sides of it (03:51:44,
  03:52:14, 03:52:44). Swap-ins were 969, 1 773 and 238 pages, which is the residue being read
  back. **The machine was not paging out when this test went red**, so memory pressure does not
  explain it. Swap used was 2.7 GB at the start (residue from earlier runs, not a reboot) and
  2.27 GB at the end, and it never rose. The run's only swap-out burst came at 03:59:18 (13 061
  pages, ~204 MB), and no test failed then.
- **NOT QUIET for about a minute.** The sampler caught **FocusCrab's `xcodebuild … test`** alive
  at 03:43:36 and 03:44:08, with a second simulator booted until 03:45:09. The wrapper reported
  "quiet" because it checks only the start and the end. No red came in that window. The
  unexplained `xcb=2` at 02:45 in §13.8 has the same shape, but whose process it was is **not
  shown**.
- **Reading the three greens:** they are one observation. All three have passed before in full runs
  (see the table in §9.2), so their greens do not by themselves show that the unit phase's memory
  caused their earlier reds.

**Where this leaves D33.** On this evidence the residual cause is **a tap on the tab bar after
launch that the app does not act on**. It is not missing data, not a covering modal, and not
paging. **It is not explained yet. Stopped here as instructed.** Possibly the same family as D51:
a bar control that does not respond to a tap, in a Release build on a device.

**PROPOSAL, not implemented: take the bulk-delete benchmarks out of the default full run.**

1. **The tests.** `BulkDeleteFixMeasurementTests` (689 s), `BulkDeleteCostMeasurementTests` (its
   `deleteAll` test, 319 s, plus `reset`, 76 s, which comes with the suite) and
   `BulkDeleteQuadraticMechanismTests` (290 s). Together that is **~1 374 s**, about 91% of the
   unit phase's 1 509 s of summed test time. They are the likely source of the 13.9 GB peak, but
   that is **not shown**.
2. **Correction to the premise.** They are not all pure benchmarks. `BulkDeleteFixMeasurementTests`
   **guards the D33 fix**: it asserts `saveSpeedup > 5.0`, that splits cascade, and that no
   orphans survive. What stays in the default run after the move:
   - `PurgeCostMeasurementTests` (12.7 s) guards `detachForBulkDelete` on the `wipeLedger` path at
     8k rows, with a 5 s budget.
   - `TransactionDeleteServiceTests` covers orphaned splits at small scale.
   - **Nothing** guards the cost of `DuplicateReviewService.deleteAll` or `reset` at scale.
3. **Mechanism: a condition trait, not `-skip-testing`.** Each suite gets
   `.enabled(if: ProcessInfo.processInfo.environment["RUN_SCALE_TESTS"] == "1")`. Disabled tests
   are reported as **skipped**, so the gate's `executed+skipped` **stays at 1242**: executed drops
   1237 → 1233 and skipped rises 5 → 9. `EXPECTED_TOTAL_RUN` does not move, and a deleted suite
   still shows up as a count drop. A `-skip-testing` approach would need
   `EXPECTED_SKIPPED`/constant changes in two places.
4. **`scripts/run-scale-tests.sh`.** It sets `TEST_RUNNER_RUN_SCALE_TESTS=1` and runs
   `run-tests.sh -only-testing:` for the three suites. It follows the same exit contract (0 / 1 /
   2 / 3) and expects **4 executed and 0 skipped**, so a scale run that silently skips counts as
   exit 2, not a pass. It prints each test's measured seconds and the swap peak from
   `machine-sampler.sh`.
5. **Release rule.** Any release whose diff touches deletion (`TransactionDeleteService`,
   `DuplicateReviewService`, `TransactionResetService`, `LargeDatasetDebugSeed`, or the
   `Transaction`/`Category`/split relationships) must run `run-scale-tests.sh` green before
   archiving. This goes in `GO_LIVE_CHECKLIST.md` and the release section of `ARCHITECTURE.md`.
6. **[DROPPED by founder 2026-10-16 (§13.11).]** **The laptop number.** Do one full run after the split, on a rebooted, quiet machine with one
   simulator, and record its peak swap here as **"the suite without scale measurements"**. That
   number, not the 13.9 GB, decides the question.


### 13.10 Scale split + tab-tap instrumentation (2026-10-14) — ready for the post-split full run

Branch `test/d33-scale-split-and-tab-tap` (pushed): `516489a`, `dae221b`, `411bc2a`. Rulings: the
split is APPROVED on one condition, that the correctness half stays in the default gate. D33 is
treated as a real defect (a tab tap not acted on), diagnose only: no retries, no longer waits, no
tap-until-selected.

**A1 — small-N correctness, default gate.** `BulkDeleteCorrectnessTests` (3 tests, 50 rows, 17
parents with 2 splits each, half flagged; every count read from a FRESH context on the on-disk
store):
- `deleteAllCascades`: the deleted rows' splits go, the survivors' splits stay, 0 orphans.
- `resetCascades`: 0 rows, 0 splits, 0 orphans.
- `wipeLedgerCascades`: the same, for the launch seam.

Before this, no small-N test checked the split cascade on any of the three paths.
`ImportDuplicateFlagTests.testDeleteAllRemovesEveryFlaggedRowAndLeavesTheOriginals`
(`ImportDuplicateFlagTests.swift:201`) and `TransactionResetServiceTests.testResetTransactions_success_doesNotShowError`
(`TransactionResetServiceTests.swift:41`) seed no splits. `PurgeCostMeasurementTests` asserts 0
splits after `wipeLedger` (`PurgeCostMeasurementTests.swift:102`), but only at 8k rows and only for
`wipeLedger`; it stays in the default gate.

**A2 — commissioned both ways.**
- RED on scratch `fe49fc8` (local, never merged): `Transaction.splits` `.cascade` → `.nullify`,
  plus `wipeLedger`'s explicit split-delete loop removed. `executed=3 failed=3`:
  - *"18 splits belonged to deleted rows; 0 were removed"*, *"18 orphaned splits survived deleteAll"*
  - *"34 of 34 splits survived reset"*, *"34 orphaned splits survived reset"*
  - *"34 of 34 splits survived wipeLedger"*, *"34 orphaned splits survived wipeLedger"*
- GREEN on `516489a`: `executed=3 passed=3`, exit 0.

**A3 — the gate.** `FinanceTrackerTests/ScaleTestGate.swift` defines the `.scaleMeasurement`
trait, which the three scale suites now carry:

```swift
static var isEnabled: Bool { ProcessInfo.processInfo.environment["RUN_SCALE_TESTS"] == "1" }
static var scaleMeasurement: Self { .enabled(if: ScaleTestGate.isEnabled, "Scale benchmark: …") }
```

How the variable reaches the test process, `scripts/run-scale-tests.sh`:

```bash
TEST_RUNNER_RUN_SCALE_TESTS=1 "$REPO_ROOT/scripts/run-tests.sh" "${SUITES[@]}"
```

`man xcodebuild`: *"TEST_RUNNER_<VAR> Set an environment variable whose name is prefixed with
TEST_RUNNER_ to have that variable passed, with its prefix stripped, to all test runner processes
launched during a test action."*

**A4 — `run-scale-tests.sh`.**
- NEGATIVE, observed: a temporary copy with only the `TEST_RUNNER_` assignment removed exited
  **2**, with `executed=0 skipped=4`. All 4 tests were listed `Skipped` with 0.0 s, and the
  script printed *"ZERO scale tests executed (4 skipped). RUN_SCALE_TESTS did not reach the test
  process. This is a silent no-op, NOT a pass."*
- POSITIVE: waits for C3.
- Fixed during commissioning: the per-test seconds now come from `durationInSeconds`. The
  `duration` string is locale-formatted (`"0,089s"`).
- The script refuses to start when another xcodebuild is alive.
- `run-tests.sh` gained `RESULT_BUNDLE` so the wrapper can read the bundle.

**A5.** ARCHITECTURE.md → Releases → "A release that touches deletion needs a green scale run".
It gives the path list and the `git diff` that decides whether the rule applies. A green run on
the archived commit is recorded in §11. `GO_LIVE_CHECKLIST.md` §3 points there and does not
restate the rule.

**A6.** `EXPECTED_TOTAL_RUN` is still **1242**, stale on purpose: +3 tests from A1, and the gate
moves 4 tests from executed to skipped. The new value comes from C3's observed count, then gets
re-checked with `CHECK_BUNDLE`.

**B1 — honest failure.** `FinanceTrackerUITests/TabBarNavigation.swift`, `app.tapTab(_:)`. There
was no shared helper; the 5 affected files now route every tab tap through this one.
- One tap, then the target must be `Selected` within 2 s. For "+" the Quick Add sheet must be up
  instead (new identifier `quickEntry.close`).
- Otherwise it attaches a screenshot, the hierarchy and the tap facts, then fails with
  *"tab tap ignored: '<current>' still selected after tapping '<target>' (#n) …; seed rows=<n>"*.
- It never taps twice.
- `savingThree` used to accept ANY text field as the Quick Add input, so an ignored "+" passed
  the Dashboard's own field off as the sheet. That is why it failed later, as "Save button
  missing".

Commissioned:
- Scratch `033a6a6` (the tab bar's binding write dropped) stayed **GREEN**. The surprise: with
  SwiftUI's `selectedTab` never written (no onChange line), UIKit still switched to Transactions
  on screen. **So an ignored tab tap is NOT "the binding write was dropped".**
- Scratch `baff82f` (onChange reverts every switch to Transactions) went **RED** with *"tab tap
  ignored: 'Dashboard' still selected after tapping 'Transactions' (#1); expected 'Transactions'
  Selected within 2 s; seed rows=33"*. The app's log named the revert:
  `selection-write 0→1 at TabView selection binding (tab bar)` → `selection-onChange 0→1` →
  `selection-write 1→0 at FinanceTracker/ContentView.swift:212`.

**B2 — in-app diagnostics.** `FinanceTracker/Shared/TabTapDiagnostics.swift`: DEBUG only, inert
without `--d33-tap-diagnostics`, os_log only, no network, no user data.
- (a) `UIWindow.sendEvent` is exchanged for a logging pass-through: every touch-began in any app
  window, with the window, its level, and the `hitTest` view plus two superviews.
- (b) Every tab-selection write goes through `selectTab(_:)` (call site `#fileID:#line`) or a
  logging binding (the tab bar's own write), plus the net onChange.
- (c) The test logs its tap time, frame, `isHittable`, the tab-bar count and the number of
  same-label buttons.
- All lines share wall-clock `t=` stamps. Read them with `xcrun simctl spawn <udid> log show
  --predicate 'category == "D33TabTap"'`. The simulator must be booted again first, because the
  run-tests.sh trap shuts it down.

**B3 — cheap reproduction: NO REPRO IN ISOLATION.** The 4 affected tests (`seededRowTap`,
`editAfterQuickAddInsert`, `savingThreeConsecutive`, the D51 probe
`test_reportsSheet_backgroundedDuringSwipeDismiss_…`) were run with `-test-iterations 10
-run-tests-until-failure` on one erased iPhone 17 Pro, 19:57:32–20:35:29.
- **40 of 40 repetitions passed** (per-test Repetition 1–10 in the bundle), exit 0.
- Machine quiet: xcb=1 in every 30 s sample, no Simulator.app.
- Swap was 1 246 MB at the start and 3 494 MB at the end. It peaked at 3 726 MB at 20:14:54, the
  only sample with swap-outs (17 680 pages).
- From the log:
  - 70 test taps, 70 `reached=true`, 0 `reached=false`, 0 "selection lagged".
  - Every tap had `tabBars=1`, `sameLabelButtons=1` and `isHittable=true`.
  - All 70 tab-bar touch-begans hit `_UITabButton`.
  - The 40 reverting writes are all `ContentView.swift:214`, the by-design "+" restore. The "+"
    taps are 3 per `savingThree` and 1 per `editAfterQuickAddInsert`, × 10.

**B4 — classification: E (no repro)** for all 40. Per the brief, this points at load or ordering.
In §13.8 and §13.9 the reds came only inside the full or UI-target run. No fix is proposed.

**What C3 adds.** B2 is live in the five affected files, so a D33 red in the full run will carry
its own A/B/C/D evidence.

**C2: ready for the post-split full run; it needs a reboot.**

**C3 — the post-split full run (2026-10-15 23:05:17 → 23:44, `a928b39`, erased iPhone 17 Pro).**
Run on a NON-CLEAN machine, by ruling (§13.11): the clean-machine condition was lifted.

Starting conditions:
- Not rebooted since 2026-10-11 23:55.
- Swap used 1 733 MB, load average 1.20.
- Open: Safari, Mail, ChatGPT, Messages, PDF Reader Pro, Claude, Xcode, Terminal, plus 4 `claude` CLI processes.

Result: **exit 5** (stale count). `executed=1236 passed=1235 failed=1 skipped=9`, total 1245 vs 1242 expected.
- **EXPECTED_TOTAL_RUN 1242 → 1245** (`816b347`), taken from this run. Re-verified with `CHECK_BUNDLE`: `count … expected=1245 Δ=+0`, exit 1 (the one red below).
- The +3 is `BulkDeleteCorrectnessTests`. The 4 gated scale tests appear as skipped (9 = 5 before + 4).
- **The one red, a NEW failure under §13.11: D52 again** (`VoiceAudioSessionControllerTests` "a busy session is retried until it releases — the field bug"). Message: `VoiceAudioSessionControllerTests.swift:81: Expectation failed: (Array(scripted.sleeps.prefix(2)) → []) == (… → [0.1 seconds, 0.25 seconds])`. This is the identical observable to its first sighting (§13.6). Second observation. Unit test, test-only code, not D33.
- **D33: zero reds.** All five watched UI tests PASSED:
  - `seededRowTap`;
  - `editAfterQuickAddInsert`;
  - `savingThreeConsecutive`;
  - `editPopBack_thenEditAgain`;
  - the D51 probe.

  Nothing to classify per B4; no reopen trigger.
- Swap (30 s sampler): 1 733 MB at the start, **peak 5 235 MB at 23:09:57** (the unit phase), 5 059 MB at the end. Swap-outs occurred in 5 of 76 samples. For comparison, the suite WITH scale measurements peaked at 13.9 GB (§13.8). This number decides nothing now.
- Quietness:
  - 74 of 76 samples had one xcodebuild.
  - **23:41:47–23:42:17 (2 samples): a FocusCrab xcodebuild ran concurrently** (pid 5592 action `?`, then pid 5676 `archive`). This was near the end, in the UI phase.
  - The wrapper's start/end check reported "quiet", and missed it again.

**Scale run, the positive A4 commission (2026-10-15 23:46 → 2026-10-16 00:13).**
- **Exit 0, `executed=4 skipped=0`**, "✓ all 4 scale tests passed".
- Per test:
  - deleteAll 339.2 s;
  - reset 77.4 s;
  - fix measurement 758.9 s;
  - quadratic mechanism 309.9 s.
- **NOT a clean measurement:** another session's FocusCrab test runs started at 23:48, two minutes after this one, and overlapped 44 samples (to 00:10:58), with up to 4 simulators booted.
  - Peak swap 23 666 MB at 00:04:51.
  - Swap was 5 059 MB at the start and 6 725 MB at the end.

  The pass/fail verdict stands, because its assertions are ratios and correctness. The seconds and the peak are contaminated.

Afterwards: `xcrun simctl shutdown all` (0 booted), no xcodebuild running.

### 13.11 Scope ruling — Dmitry decided, 2026-10-15 (effective after C3)

Received while §13.10 was waiting for the reboot and "go". C3 is still to run as briefed; this ruling
applies once it has.

1. **D33 investigation ENDS with C3.** Report C3 and classify any red per B4 (§13.10), then stop.
   - D33 stays OPEN in `DEFECT_REGISTER.md`, reclassified as a **test-infrastructure intermittent**.
     The register row is updated with C3's result, not before.
   - **The gate reads D33's known reds as baseline: "no new failure vs baseline".** `run-tests.sh`
     has no baseline mechanism (exit 1 means "at least one red"), and building one is the
     test-infrastructure work item 4 forbids. So this is a **reading rule, applied by hand**: an
     exit 1 passes the gate only if every failing test is in the known set. Known set: the D33
     tests seen red in full or UI-target runs (§13.6–§13.9): `seededRowTap`,
     `editAfterQuickAddInsert`, `savingThreeConsecutive`, `editPopBack_thenEditAgain`. C3's result
     confirms or amends the list. Any red outside it is a new failure.
   - **Reopen ONLY if** C3's log shows a mechanism a user could hit: bucket B naming a real
     overlay, or bucket C naming a production call site. Then report and wait. Do not fix.
2. **Then resume the User Guide at step 2**: Settings routing, with the "General stops responding"
   regression test written red first. Follow `DESIGN_USER_GUIDE.md` and the §13.1 rulings, in the
   design's order. Commit to a branch after each step and report briefly after each step.
3. **1.0.7 scope:**
   - the User Guide;
   - D50: the false teaching strings C1–C5, and deleting the orphaned
     `add.source.expense_disabled_hint` in all 5 locales (§13.1 row 14.1);
   - the pt-BR/pt-PT and es-MX locale sweeps.

   Receipt scanning joins **only if** the corpus arrives and the sealed run passes. Otherwise it
   moves to **1.0.8** (ruling 14.7: the Guide ships alone).
4. **No more test-infrastructure work unless it blocks a release.**

**Amendment, Dmitry 2026-10-15 (recorded after C3):**
- A listed test's failure is a known red **only if its message is the tapTab "tab tap ignored"
  message**. A listed test failing any other way (an assertion, a crash, a timeout elsewhere) is a
  NEW failure. Otherwise a real edit/save regression would hide behind the list.
- The D51 probe stays OFF the list. If it fails, it is reported as new, with its message and
  attachments.

**Ruling, Dmitry 2026-10-16:** the laptop decision is **dropped by the founder**. The machine counts
as rebooted (2026-10-11). C3's clean-machine condition is lifted: its remaining purposes were the
release gate, EXPECTED_TOTAL_RUN and a D33 classification that is parked either way.

**D33 investigation is now CLOSED per item 1.** C3 had zero D33 reds and no reopen trigger.

### 13.12 Guide step 2 — Show-me routing and its journey test (2026-10-16)

Plan, amendments, as-built differences and commissioning: **`outputs/GUIDE_STEP2_PLAN.md`**.
Branch `feat/guide-step2-routing`, cut from `test/d33-scale-split-and-tab-tap` (which carries `tapTab`
and EXPECTED 1245).

- **One entry point:** `GuideRouter.open(_:)`. In step 2 its only caller is the DEBUG
  `GuideRouteHarness` (`--guide-route-harness`; registered in `ReleaseDebugAffordanceTests`). Step 3's
  Show me button becomes the second caller.
- **`GuideShowMeJourneyTests`:** 22 destinations in 5 families, plus a harness-absence test. Each
  destination is proven by an element on the destination itself, and each journey starts away from
  its target.
  - Green on the real code (class runs 2026-10-16).
  - Every destination seen red: mutant A turned 21 of 22 red. B covered `dashboard` (A's vacuous
    case). C covered `categoryLimits` without its scroll.
- **Limits, stated rather than claimed:**
  - feedback proves the fallback sheet only. Mail is checked on device in the step-6 acceptance.
  - The Data scroll can't be observed on iPhone 17 Pro, because the list fits one screen.
- **R1 guard:** `SettingsStackDeepPopTests` is unchanged by this step and runs in the full suite.
- **Cost (amendment 4):** the class took ≈ 392 s in its isolated green runs. This becomes
  the measured full-run delta after the next full run, which also sets EXPECTED_TOTAL_RUN.
- **Full run 2026-10-16 (`695ee75`):** `executed=1242 passed=1242 failed=0 skipped=9`, exit 5
  (stale count). **EXPECTED_TOTAL_RUN 1245 → 1251**, `CHECK_BUNDLE` Δ+0.
  - The new class costs 381 s.
  - Every sample saw one xcodebuild. Swap peaked at 5.97 GB.
  - D52 passed this time.
- **Step-6 acceptance additions and the step-3 tier rule:** `GUIDE_STEP2_PLAN.md`, last two sections.
- **Merge plan (not executed):** main is at the merge base `a370077`, so both merges are fast-forwards
  with no conflicts. First `test/d33-scale-split-and-tab-tap`: its C3 has zero D33 reds, and its one red
  is D52, NEW under §13.11, so it needs a ruling. Then `feat/guide-step2-routing`.

### 13.13 Receipt corpus: the unit is the RECEIPT, not the image (pre-registration amendment, 2026-10-25)

**This is an amendment made before the freeze, not a change after the fact.** Nothing is frozen, no
`FROZEN.sha256` exists, no split has run, and no corpus image has been opened (checked 2026-10-25:
`FinanceTrackerTests/Fixtures/` does not exist). Dmitry decided this on 2026-10-25.

- **Cause:** Dmitry's first paper receipt arrived as **5 photos of ONE receipt**, shot from different
  angles and crumpled. The split as built (§12, `a8ad92e`) hashed each **file**, so near-duplicate
  shots would have landed in both DEV and SEALED. Sealed content would then have leaked into tuning
  and inflated the sealed score.
- **Rule now:**
  1. `manifest.csv` gains `receipt_id`, shared by every shot of one physical receipt (or one order
     screenshot).
  2. The DEV/SEALED split hashes `receipt_id`: first byte of SHA-256(id), even → DEV.
  3. The bar in `DESIGN_RECEIPT_SCAN.md` §7.3 is judged **per receipt**, on shot `<receipt_id>_a`.
     Variant shots go in a robustness sub-table and are not counted as samples. The 10-per-cell and
     100 minimums count receipts.
- **Primary shot (Claude's choice, open to Dmitry before the freeze):** `_a` is the shot taken first,
  by the guide's photographing rules, before any parse. It is chosen at collection time, not by how
  it scans. For the 5 photos already sent, Dmitry names which one is `_a` before the freeze.
- **Residual risk, stated:** a person chooses the `receipt_id` string, and that string decides the
  half. The guide therefore says to number ids in collection order and never rename one after the
  manifest is written. The freeze then pins every id.
- **Changed:** `RECEIPT_CORPUS_COLLECTION_GUIDE.md` (naming, manifest, split, reporting) and
  `DESIGN_RECEIPT_SCAN.md` §7 (amendment block plus §7.1, §7.2 and §7.4).
  `ReceiptCorpusTests` now checks:
  - the manifest header must contain `receipt_id`, so an old manifest is refused rather than read
    shifted by one column;
  - every receipt has exactly one `_a` shot, and all its shots carry the same truth;
  - reports are printed per receipt (gated) and per image (robustness).
- **Commissioning:** `testSplitKeepsEveryShotOfAReceiptInOneHalf`. The fixture is 2 receipt_ids × 3
  shots (`en_paper_01` → SEALED, `ru_paper_02` → DEV). The test asserts that the old per-file rule
  splits **both** receipts, so the fixture keeps discriminating. Seen red and green: see the commit
  body. `testManifestRejectsAReceiptWhoseShotsDisagree` covers the consistency check.
- **Suite count:** +2 tests. Per the standing rule, EXPECTED_TOTAL_RUN is **not** set by arithmetic;
  the next full run exits 5 and prints it.

### 13.14 Receipt corpus intake: halves recorded BEFORE any image is opened (2026-10-27)

A message from Dmitry, 2026-10-27, says 9 ru paper receipts (10 images) are arriving in
`budget-crab-internal/receipt-corpus/`, ids assigned in arrival order and **final**. `ru_paper_02`
has two shots: `_a` is the clear one, `_b` the blurred variant. At the time of recording,
`receipt-corpus/` does not exist and `FinanceTrackerTests/Fixtures/` does not exist, so **no image
can have been opened**. This commit's timestamp is the evidence that the halves came first.

Rule (§13.13): first byte of SHA-256(receipt_id as UTF-8), even → DEV, odd → SEALED. Computed with
`printf '%s' "$id" | shasum -a 256`. The two fixture ids agree with `ReceiptCorpusTests`
(`en_paper_01` → SEALED, `ru_paper_02` → DEV).

| receipt_id | byte 0 | half | shots |
|---|---|---|---|
| en_paper_01 | `c9` | **SEALED** | already received (5 photos; Dmitry names `_a`) |
| ru_paper_01 | `73` | **SEALED** | 1 |
| ru_paper_02 | `40` | DEV | 2 (`_a` clear, `_b` blurred) |
| ru_paper_03 | `8d` | **SEALED** | 1 |
| ru_paper_04 | `43` | **SEALED** | 1 |
| ru_paper_05 | `99` | **SEALED** | 1 |
| ru_paper_06 | `1e` | DEV | 1 |
| ru_paper_07 | `fe` | DEV | 1 |
| ru_paper_08 | `ae` | DEV | 1 |
| ru_paper_09 | `a9` | **SEALED** | 1 |

ru: 4 DEV / 5 SEALED receipts (5 / 5 images). All: 4 DEV / 6 SEALED receipts. Not frozen. Counts
elsewhere: en paper 1, screenshots 0, non-receipts 0.

**The intake PII check conflicts with the sealed rule.** Card numbers, cashier names and QR codes
can only be confirmed covered by looking at the image. Claude may open the DEV files only. The six
SEALED receipts need a check by someone who will not tune the parser (Dmitry). This is open; it is
not to be resolved by a Claude session opening a SEALED file.

### 13.15 Receipt corpus intake #2: halves recorded BEFORE any image is opened (2026-10-31)

Intake #2 (`INTAKE_2026-10-31.md`): 15 images, 13 new receipt_ids plus `en_paper_01_f` (a sixth shot
of the existing SEALED `en_paper_01`). **Unlike §13.14, the files already exist on disk when this is
recorded**, so the commit timestamp is not, on its own, proof that no image was seen. What is: the half
is a pure function of the id (§13.13 rule, `printf '%s' "$id" | shasum -a 256`, byte 0 even → DEV,
odd → SEALED), no image was opened before this commit, and the ids were assigned by the reviewer in
arrival order. Control: `ru_paper_02` recomputed → `40` → DEV, matching §13.14.

| receipt_id | byte 0 | half | shots |
|---|---|---|---|
| en_paper_01 | `c9` | **SEALED** | +1 (`_f`; now 6) |
| en_paper_02 | `b6` | DEV | 1 |
| en_paper_03 | `fc` | DEV | 1 |
| en_paper_04 | `20` | DEV | 1 (not whole-in-frame → bad set) |
| en_paper_05 | `d6` | DEV | 1 (not whole-in-frame → bad set) |
| en_screenshot_01 | `8d` | **SEALED** | 1 |
| en_screenshot_02 | `8f` | **SEALED** | 1 (medical — never in shared material) |
| en_screenshot_03 | `32` | DEV | 1 (medical — never in shared material) |
| en_screenshot_04 | `d8` | DEV | 1 (medical — never in shared material) |
| en_screenshot_05 | `f3` | **SEALED** | 1 (refund, total_cents −7680) |
| en_screenshot_06 | `f0` | DEV | 1 |
| en_screenshot_07 | `95` | **SEALED** | 1 (medical — never in shared material) |
| en_screenshot_08 | `6d` | **SEALED** | 1 |
| uk_screenshot_01 | `45` | **SEALED** | 2 (`_a` invoice, `_b` LiqPay receipt, same order) |

New: 7 DEV / 6 SEALED receipts (7 / 8 images incl. `en_paper_01_f`). Corpus after intake #2:
23 receipts, 30 images. en paper 5 (4 DEV / 1 SEALED), ru paper 9 (4 / 5), en screenshots 8 (3 / 5),
uk screenshots 1 (0 / 1), non-receipts 0. **Not frozen.** Still missing vs. target: en paper 5/10,
ru paper 9/10, en screenshots 8/10, ru screenshots 0/10, non-receipts 0/5.

The §13.14 SEALED-privacy conflict is closed for intake #2: the reviewer (Cowork, does not tune the
parser) redacted and privacy-checked ALL new files, SEALED included. Claude checks DEV only.
