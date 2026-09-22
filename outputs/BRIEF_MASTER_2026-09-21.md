# BUDGET CRAB — MASTER BRIEF, received 2026-09-21

**Status: FOUNDER'S BRIEF, verbatim.** This is the text Dmitry Logachev handed the 2026-09-21
session. It is stored so that every "Dmitry decided X" row in `STATE.md` cites a file and a line
rather than a chat message (STATE.md rules 1–2). Nothing below has been edited; the phase numbers
and headings are his. Status for the items it names lives in `STATE.md`, not here.

---

```
BUDGET CRAB — MASTER BRIEF FOR A FRESH SESSION

You are working for Dmitry Logachev, solo developer of Budget Crab, a
privacy-first iOS personal-finance app (repo: FinanceTracker, path
/Users/dmitrylogachevusa/Desktop/ProjectsIOS/FinanceTracker). Dmitry relays
your reports to a reviewer who checks them against the repo. Claims you make
will be verified. Write reports in English, concise, with evidence.

This brief moves the project from fixes to substantial new features. It is
long because you start with no memory. Read all of it before touching anything.

════════════════════════════════════════════════════════════════════════════
1. READ FIRST — in this order
════════════════════════════════════════════════════════════════════════════

  outputs/STATE.md            the ONLY place project status lives
  outputs/DEFECT_REGISTER.md  every known defect, severity, reachability
  outputs/COVERAGE_MATRIX.md  which money-touching surfaces have zero tests
  ARCHITECTURE.md             rules, incidents, release section
  outputs/GO_LIVE_CHECKLIST.md
  scripts/run-tests.sh        header — how the test gate works and fails

Then, per phase, the documents named in that phase.

════════════════════════════════════════════════════════════════════════════
2. HOUSE RULES — each one was paid for with a real defect
════════════════════════════════════════════════════════════════════════════

 1. Status lives in STATE.md and nowhere else. Update it at the end of every
    task. Never state a status from memory — yours, a previous session's, or
    the reviewer's. Two decisions were recently misreported from memory with
    confidence; the documents said otherwise.
 2. A guard is trusted only after it has been observed RED. Write the test,
    run it against unmodified code, see it fail, then fix.
 3. Enumeration lies. Lists of "all the sites" were wrong four times in one
    day. Prefer a test that walks the real user journey end to end.
 4. Assert PRESENCE, not absence. "The error card is gone" passed while the app
    crashed rendering its replacement.
 5. PDFs and visuals: verify PIXELS. PDFKit text extraction is inadmissible —
    it drops U+2212 and U+2026 and has produced false results three ways.
 6. Money: Int cents, formatted only via Shared/Money.swift, parsed only via
    AmountParsing (which rejects, never defaults). Never `?? 0` on an amount.
    A total that cannot be represented is shown as unavailable — never as a
    plausible wrong number. Money is never truncated in any rendering.
    Accumulate with addingReportingOverflow.
 7. No `try?` on any call whose failure matters: saves, session activation,
    file writes, audio session changes. Silent failure is this codebase's
    most repeated defect class (see outputs/AUDIT_SILENT_SUCCESS_CLASS_*).
 8. UI copy that asserts behaviour is a CLAIM. Verify every such sentence
    against the build before it ships — in-app strings, What's New, support
    replies.
 9. Full test runs: ./scripts/run-tests.sh only, never piped (it masks the
    exit code). Erase the simulator first; crash reports are harvested before
    the erase — keep it that way. EXPECTED_TOTAL_RUN is set from an OBSERVED
    count, never arithmetic. The machine has 16 GB and OOMs under load;
    compile-phase kills are memory, not code.
10. No commits while run-tests.sh is executing — the pre-commit framework
    stashes unstaged files and can swap the script out from under bash.
11. Privacy is the product. All user data stays on device. Speech uses
    requiresOnDeviceRecognition = true — never relax it. No network calls
    carrying user data. Nothing in this brief changes that.
12. Every release: annotated tag v<version>-build<n> on the archived commit,
    branch release/<version>, store fixture captured from that binary, and
    ShippedStoreShapeTests' version list updated. Export options pin
    manageAppVersionAndBuildNumber = false.
13. Never ask for, read or enter credentials. Uploads use Xcode's signed-in
    account via xcodebuild -exportArchive; if that needs a sign-in, stop.

════════════════════════════════════════════════════════════════════════════
3. STATE OF PLAY
════════════════════════════════════════════════════════════════════════════

  • 1.0.5 (build 10) is APPROVED AND LIVE on the App Store.
  • Main, release/1.0.5 and tag v1.0.5-build10 (on 8c98982) are pushed.
  • The next full suite run is expected to exit 5 and print the observed
    count — EXPECTED_TOTAL_RUN is deliberately one low. That is not a failure.

════════════════════════════════════════════════════════════════════════════
PHASE 0 — CLOSE OUT (small; ships in 1.0.6 with Phase 1)
════════════════════════════════════════════════════════════════════════════

0.1 Amend tag v1.0.5-build10: "approved and released", today's date. Push.
    STATE.md: live version is 1.0.5 (10), from the source.

0.2 MUSIC DOES NOT RESUME AFTER VOICE INPUT — confirmed on Dmitry's iPhone.
    Every voice entry while music or a podcast plays leaves it paused; the
    user must press play. (Opening/closing Quick Entry WITHOUT speaking does
    not touch the music.)
    Code: VoiceInputService.swift:321
      try? AVAudioSession.sharedInstance().setActive(false,
                options: .notifyOthersOnDeactivation)
    This is the one call that lets other apps resume, and its failure is
    swallowed. Hypothesis: "session busy" — deactivating before I/O has fully
    stopped. CONFIRM on device first (do/catch + os_log, one run with music).
    Also: line 248 uses .record + .duckOthers — .record cannot mix, so music
    is interrupted instead of ducked; line 249 passes a deactivation option to
    an activation call. Sweep all AVAudioSession calls for try?.
    Fix = option A: deactivate only after I/O has actually stopped; never
    swallow the error. Option B (duck instead of interrupt) is a product
    decision with a recognition-accuracy risk — propose it, do not choose it.

0.3 The five unfiled defects in DEFECT_REGISTER.md §3.1: re-evaluate against
    1.0.5 (10). For each: still reachable? severity as the user experiences
    it; the action sequence that reaches it; fix in 1.0.6 or later. Fix the
    ones that are cheap and user-visible; file the rest precisely.

0.4 TSVExportService: paid whole-ledger export with zero tests. Write them,
    commission each red first: money formatting, locale separators,
    escaping/delimiter collisions in merchant and note, round-trip if the app
    re-imports its own TSV.

0.5 The VoiceInputService deinit abort stays FILED, not fixed. Device test
    n≈5–7 showed no crash — that bounds a rate, it does not prove
    "simulator-only". Leave the three specified device tests specified.

REPORT Phase 0, update STATE.md, then continue to Phase 1's design doc.

════════════════════════════════════════════════════════════════════════════
PHASE 1 — REPORTS (target 1.0.6)
════════════════════════════════════════════════════════════════════════════

WHAT DMITRY WANTS
  • Reports ON DEMAND: choose a period — week, month, year, or a custom
    range — see it in the app, export as PDF (and TSV).
  • AUTOMATIC reports weekly and monthly.

EXISTING GROUND
  PDFExportService (column layout rebuilt and pixel-tested — do not regress
  it; PDFExportRenderTests is the guard), Analytics screens, the weekly
  "safe to spend" alert and ProactiveAlertRefreshScheduler,
  outputs/FEATURE_SPECS_BUDGETS_RECURRING_REPORTS.md. The previously verified
  delta for reports: annual/custom period scope, period-over-period
  comparison, and a PDF that carries the analysis, not only a table.

CONSTRAINTS
  • "Automatic" cannot mean a server or an auto-sent email — there is no
    server and nothing leaves the device. Propose the mechanism. The expected
    shape: a local notification at a user-chosen day/time → tapping it opens
    the report for the period that just closed, generated on open.
    BGTaskScheduler is not guaranteed to run on schedule — do not depend on
    background generation for correctness.
  • Reports sum money across long periods. Every aggregate they use must be
    overflow-safe. AnalyticsSeries is a KNOWN unfixed overflow site (it traps
    on a ledger containing an unrepresentable amount) — fix it here, under
    the rule in §2.6, because reports would inherit it.
  • Every figure in a report must match the same figure elsewhere in the app
    for the same period. Test that equality explicitly.
  • Free vs premium: propose in the design doc. Do not decide.

FIRST DELIVERABLE: outputs/DESIGN_REPORTS_1_0_6.md — screens, periods,
comparison logic, the automatic mechanism, settings, premium proposal, test
plan (render tests in pixels, equality tests, locale × currency matrix), and
the What's New wording. Then STOP for Dmitry's approval.

════════════════════════════════════════════════════════════════════════════
PHASE 2 — RECEIPT AND SCREENSHOT SCANNING (target 1.0.7)
════════════════════════════════════════════════════════════════════════════

WHAT DMITRY WANTS
  Capture a PAPER receipt with the camera, OR pick a SCREENSHOT of an online
  receipt (order confirmation, email, app, website), and get a prefilled
  transaction.

EXISTING GROUND
  outputs/SPEC_PHOTO_INPUT.md (flow, parsing heuristics),
  budget-crab-internal/working-docs/DECISION_RECEIPT_INPUT_PRETEST.md.
  Record in STATE.md that Dmitry has DECIDED to build this; the pre-test was
  not resolved and must not be described as resolved.

CONSTRAINTS
  • 100% on-device: VisionKit document camera for paper, PhotoKit picker for
    screenshots, Vision VNRecognizeTextRequest (.accurate). No network, ever.
    The image never leaves the phone. Attaching it to the transaction is
    optional and OFF by default.
  • Always PREFILL and let the user confirm. Never auto-save a scanned amount.
    Low confidence → recognised text shown as a hint, amount left empty.
  • Online receipts carry Subtotal, Tax, Shipping, Discount and Order Total —
    the parser must pick the grand total, not a subtotal. Paper receipts
    carry "Итого / Total / Importe / Сума / Total" in five locales.
  • Amounts go through AmountParsing. A value it rejects is not prefilled.
  • Merchant learning and save side-effects fire exactly as for manual entry
    (reuse the existing save path).

MEASUREMENT BEFORE SHIPPING — pre-register it in the design doc
  Build a fixture corpus of receipt images: paper and screenshot, all five
  locales (en, ru, es-MX, pt-BR, uk), with the true total for each. Set the
  accuracy bar BEFORE running the parser against it. Report accuracy per
  locale and per type, honestly, including the misses. If a locale is below
  the bar, it ships with that stated or not at all — Dmitry decides.

FIRST DELIVERABLE: outputs/DESIGN_RECEIPT_SCAN.md, then STOP.

════════════════════════════════════════════════════════════════════════════
PHASE 3 — USER GUIDE: HOW TO USE BUDGET CRAB (target 1.0.7)
════════════════════════════════════════════════════════════════════════════

This is a USER-FACING guide to everything a person can do in the app. Not a
developer document, not only a first-launch tour. A proper, complete, in-app
guide that a user can open at any time and learn every feature from.

WHY
  The first App Store user who wrote in asked for a feature two-thirds of which
  already existed. His usage summary said he had used none of it. Writing him a
  reply required reading the localisation files to name the five steps to a
  shipped feature. Users do not have those files. They have a screen.
  Evidence and a pre-registered acceptance test: outputs/PLAN_TUTORIAL_AND_HELP.md.

WHAT TO BUILD — three layers

  1. FIRST-RUN WALKTHROUGH
     Short, skippable, 4–6 screens: add an expense, set a monthly budget, see
     "safe to spend", where to find the Guide. Re-playable from Settings.

  2. THE GUIDE — a "What you can do" section in Settings
     A library of EVERY feature. Each feature gets one card:
       • what it is for, in one sentence a normal person understands
       • step-by-step how to turn it on / use it
       • an annotated screenshot or short animation of the real screen
       • a "SHOW ME" button that takes the user straight to that screen,
         already in the right place
     Group the cards by what the user wants to do, not by our screen structure:
     "Record spending", "Control a budget", "See where money goes",
     "Import and export", "Automate", "On your iPhone".

     Must cover at least, each verified in the current build:
       quick entry, voice input, categories, accounts (and the fact that they
       attach to INCOME only — say it, do not let users hunt for it), monthly
       budget and safe-to-spend, per-category monthly limits, the weekly
       notification, recurring transactions, split transactions, Analytics,
       PDF and TSV export, CSV import and column mapping, duplicate review,
       the widget, Siri shortcuts — plus Reports and Scanning from Phases 1–2.

  3. CONTEXTUAL HINTS ON THE SCREENS THEMSELVES
     The first time a user reaches a screen that has an unused capability, a
     small dismissible hint on that screen. Never more than one at a time.
     Never repeated after dismissal.

RULES
  • Five languages. Every sentence that describes what the app does is a claim
    and must match the build (§2.8) — a support reply was nearly sent with a
    step that does not exist.
  • The Guide is updated in the same release as any feature it describes. A
    feature that ships without its Guide card is not finished.
  • Screenshots are generated from the real app, so they cannot drift from it.
  • ACCEPTANCE (pre-registered): a new user, starting from a fresh install,
    answers "how much am I spending and how much do I have left" and reaches
    the monthly budget and a category limit — without support email, in
    Spanish at least once.

MEASUREMENT (alongside, not a gate)
  Record, on-device only and inside the existing usage summary, whether the
  walkthrough was completed or skipped and which Guide cards were opened. It
  must not delay building the Guide.

FIRST DELIVERABLE: outputs/DESIGN_USER_GUIDE.md — the card list with the text
for every card in English, the grouping, the walkthrough screens, how "Show me"
navigates, how screenshots are produced. Then STOP for Dmitry's approval.

════════════════════════════════════════════════════════════════════════════
PHASES 4–5 — iCLOUD SYNC, THEN FAMILY ACCESS (design together, build in order)
════════════════════════════════════════════════════════════════════════════

WHY THEY ARE COUPLED — read this before designing either
  outputs/RESEARCH_FAMILY_ACCESS_2026-08-12.md §3.2: SwiftData supports ONLY
  the private CloudKit database. Sharing needs NSPersistentCloudKitContainer.
  A family ledger cannot exist without sync. If sync is built on SwiftData's
  private database and family is added afterwards, users' data goes through
  TWO irreversible migrations. So the sync design must decide the storage
  layer WITH family in view.

FAMILY — what the research already settled
  CKShare has no per-record permissions. Per-transaction and per-category
  sharing are vetoed (§4). The only model that is both private and
  expressible in CloudKit is candidate 5: a SEPARATE SHARED LEDGER alongside
  each person's private ledger — the user chooses which ledger an entry goes
  into, the way they choose an account.
  Measured demand was 0.04–0.14% of 4,904 competitor reviews. Dmitry has
  decided to build it anyway; record that in STATE.md as his decision.

SYNC — existing ground
  outputs/DESIGN_ICLOUD_SYNC_1_0_4.md, AUDIT_UUID_UNIQUENESS_SYNC_1_0_4.md,
  PLAN_RECURRENCE_SYNC_IDENTITY.md, DESIGN_V3_SCHEMA_FREEZE.md,
  AUDIT_V3_ROLLBACK_READINESS.md. Current code: SharedModelContainer.swift
  uses cloudKitDatabase: .none.
  Sync is IRREVERSIBLE once records reach CloudKit. The privacy-copy gate in
  GO_LIVE_CHECKLIST.md §0b fires here: every "100% on-device" claim in the
  app, the listing and PRIVACY_POLICY.md is re-read and rewritten before sync
  ships.

FIRST DELIVERABLE: outputs/DESIGN_SYNC_AND_FAMILY.md — one document, storage
layer decision first, migration path for existing users, rollback story,
sharing model, invitation flow, what a family member sees, privacy copy
changes, and a release split. Then STOP. No sync or family code before
Dmitry approves this document.

════════════════════════════════════════════════════════════════════════════
4. HOW TO WORK THROUGH THIS
════════════════════════════════════════════════════════════════════════════

  • One phase at a time. Each feature begins with its design doc and STOPS for
    approval. Do not start the next feature's code on your own momentum.
  • Each phase ends with: tests commissioned red-then-green, a full suite run
    from an erased simulator, comparison against the known-failure baseline in
    STATE.md, STATE.md and DEFECT_REGISTER.md updated.
  • Anything you find that is not in scope: FILE it, keep going. No silent
    scope growth.
  • Proposed release cut (adjust in the design docs if you have reason):
      1.0.6  Phase 0 + Reports
      1.0.7  Receipt/screenshot scanning + User Guide
      1.1    iCloud sync
      1.2    Family access
  • When something is ambiguous and not a product decision: choose, state the
    choice, continue. When it IS a product decision (pricing, what a user
    sees, anything irreversible): propose and stop.

START: Phase 0. Report it before Phase 1's design doc.
```

---

## Addendum — Phase 1 approval, received 2026-09-21 (verbatim)

```
PHASE 1 — APPROVED: approach A, with the decisions below and one condition.

Phase 0 accepted. Verified independently: the deactivation retries run as awaited
sleeps in a MainActor Task (no main-thread block) and a new activation supersedes
a pending retry; the weekly alert is currently premium, so P1 mirrors today.

DECISIONS (§13)
  1. Free/premium: P1. Rationale to record in STATE.md alongside "Dmitry
     decided": no source supports any split (NOT IN SOURCES), and a gate is
     easy to remove later and painful to add — so start gated, revisit on data.
     Also record that MONETIZATION_FREE_PAID_SPEC.md cites notebook e4a8bc88,
     which you found is mostly 404 pages: the free/paid line as a whole rests on
     a weak source. Not a blocker for 1.0.6; file it.
  2. Analytics toolbar entry point: yes.
  3. Monthly report always on the 1st: yes, no picker.
  4. Transactions table in year/custom PDFs: off by default.
  5. Approach A: approved.

THE CONDITION — D47 ships in 1.0.6

You filed D47: a split transaction exports to TSV as ONE row under the parent
category, so category totals in Excel disagree with Analytics for anyone who
splits. Phase 1 extends Excel export to week/year/custom periods. That broadens
an export we already know is wrong. The design's promise — report figures equal
screen figures — holds for the PDF by construction and does NOT hold for TSV.

So:
  • Fix D47 in 1.0.6: export splits so that category totals computed from the
    exported rows equal CategoryAttribution for the same period. Propose the row
    shape (one row per split line with the parent reference is the obvious
    candidate) — it changes a paid file format, so state the change in What's New.
  • The equality tests must include a SPLIT-HEAVY fixture and assert
    TSV-derived category totals == Analytics == report PDF, for the same period.
    Commission it red against today's TSV first — it should fail exactly on D47.
  • Also include the overflow fixture from the 1.0.5 work: a report over a
    ledger with an unrepresentable amount shows the unavailable state, never a
    number.

KEEP AS DESIGNED
  • Notification body carries the period label and NO figures — correct both for
    lock-screen privacy and because the period is not closed at schedule time.
  • No schema change, no Swift Charts, 1.0.5 pixel guards untouched.

PENDING FROM DMITRY: the music check on the Debug build (does music resume after
a dictated entry). Record the result in STATE §8.2 when it arrives; do not wait
for it to start Phase 1.

Build Phase 1. Stop at the end of it with the full-suite result from an erased
simulator (expect exit 5 and set EXPECTED_TOTAL_RUN from the observed count),
the equality tests' red-then-green evidence, and the What's New draft in five
languages for review.
```
