# Budget Crab — GO-LIVE checklist (code complete → Add for Review)

All v1.0 code blockers closed: CSV integrity, premium gate, Charts crash+freeze, locked-intent P0 (audit), QuickEntry UX, amount parser. Remaining = QA + ASC + submit. Work top to bottom.

## 0. BUILD 10 — CLOSED. Submitted to App Review, awaiting verdict.

Submitted 2026-09-12 as reported by the founder. **That date is not a repo artefact** — the
upload happened outside this checkout (the `v1.0.5-build10` tag message still reads "upload to
App Store Connect pending credentials"), so it is recollection, not evidence, and it is the one
line in this section that is.

Every gate below is closed by a RESULT. The results are quoted, not summarised.

- [x] **Recovery-journey verb VERIFIED.** `test_poisonedRow_opensInTheEditorAndAcceptsACorrection`
      ran green on an erased simulator, 2026-09-02: the editor OPENS on a row whose amount cannot
      be summed (so there is no 26th overflow site on that journey) and it ACCEPTS a corrected
      value — the sheet dismissed and `4,000` appeared in the list. **Outcome three, so the card
      keeps "fix" / «исправьте»** and no string changed. That is also the better instruction: the
      expense was real, only the import column slipped, and correcting preserves what deleting
      erases.
      Note for whoever reads this next: the test does NOT use "the dashboard recovered" as its
      success signal, because correcting one row still leaves `Int.max − 8 + 400000`, which
      overflows — a genuine save produces no recovery here. The first version of the assertion
      passed vacuously off a `$` in the Recent list.
- [x] **Full suite from an ERASED simulator**, HEAD baseline and branch, compared test by test.
      Recorded verbatim in the annotated tag:
      `executed=1109 passed=1107 failed=2 skipped=3` · `executed+skipped=1112 expected=1112 Δ=+0`.
- [x] **`EXPECTED_TOTAL_RUN` set from the OBSERVED count.** `scripts/run-tests.sh:170` = **1113**;
      the run above excluded one test by name (`-skip-testing`, the VoiceInputService abort), so
      `SKIP_ALLOWANCE=1` and the adjusted expectation printed as 1112. The two numbers are the
      same statement — do not "fix" one to match the other.
- [x] **No new failure vs the baseline SET.** Both failures are in the known set:
      `test_editAfterQuickAddInsert_stillOpensEditor` (flaky) and
      `test_savingThreeConsecutiveTransactions_...` (deterministic). Nothing else was red.

### What actually shipped in 1.0.5 (10)

Tagged commit `8c98982` (`git rev-parse v1.0.5-build10^{commit}` — `git rev-parse` without
`^{commit}` returns the tag object `443bbfb`, which is not a commit and has already been written
into a fixture MANIFEST under the heading "commit"). Branch `release/1.0.5`.

- **PDF export no longer clips amounts** (`f7dde93`) — the table sizes its columns from the
  content and shrinks the font before it will truncate. This is the fix a tester will look for,
  and it is what the build-10 What's New leads on (`outputs/ASC_WHATS_NEW_1_0_5.md`).
- **Amounts we cannot represent are rejected at import, and the aggregates on the recovery
  journey stopped trapping** (`1b6be14`, `c2461b3`, `4348f7c`) — 25 sites, plus the explicit
  unavailable state on the dashboard.
- **The unavailable card stopped promising something we do not deliver** (`5dcf9b4`) —
  *"Every other screen works normally."* deleted in all five languages, because Analytics still
  traps. Copy corrected instead of code, deliberately and on the record.
- **The suite gate learned to see a truncated run** (`764d920`, `aaad550`) — exit 4, the guard
  that was blind through build 9.

### Still filed against 1.0.5 (10), and NOT fixed in it

Three, each with an owner document. None is a reason to pull the build; each is a reason not to
claim the build is clean.

1. **`outputs/DEFECT_VOICE_INPUT_DEINIT_ABORT.md` — AVAudioEngine teardown can abort the
   process.** A `SIGABRT` out of `AudioComponentInstanceDispose` reached from
   `-[AVAudioEngine dealloc]`, i.e. a crash with no user-visible cause and no recovery. Budget
   Crab ships voice input. Analysed to mechanism in §8 of that file on 2026-09-12 and still
   deliberately untouched: the decisive experiment is a **device** repetition run, and no fix
   should be chosen before it. Its one measured consequence — the suite silently dropping 415
   tests — is already handled by `run-tests.sh` exit 4 and by excluding the single test by name.
2. **The 14 remaining overflow expressions**
   (`outputs/DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md` §"Still filed"): `AnalyticsSeries` (6),
   `CategoryDetailView` (2), `DaySpendingSheet` (2), `AnalyticsView` (1),
   `AnalyticsBreakdownView` (1), `EditTransactionView` (1), `CSVImportService` (1).
   **All 14 are off the recovery journey** — cold launch to deleting the offending row — which is
   the boundary build 10 was drawn at. **`AnalyticsSeries` is the one that matters**: it
   accumulates across ALL months in `Int`, so Analytics still traps on a ledger the dashboard has
   just told the user is otherwise fine. That is exactly why the reassurance sentence was deleted
   rather than softened, and the sentence may only be restored once these are fixed.
   Whoever widens the fix applies the same rule — `addingReportingOverflow` and an explicit
   unavailable state, never a wrapped, saturated, zeroed or widened number. Widening is not a
   fix: `Int128` overflows too, it only moves the cliff.
   Also filed, not built: **the card does not NAME the offending row.** A user whose amounts all
   look ordinary — because the bad one arrived through a mis-mapped import column — cannot tell
   which entry is meant. That is a feature, not a copy fix.
3. **The privacy-copy gate does not fire on build 10. It fires when iCloud sync ships** — §0b
   below, unchanged and still open. Recorded here so that reading §0 as "build 10 is clear"
   cannot be mistaken for "nothing is pending": the gate is on a *different* release, and its
   whole point is that today's copy is TRUE and becomes FALSE by schedule.

## 0b. BEFORE iCloud SYNC SHIPS — a gate on THAT release, not on build 10

Not a build-10 item. Recorded here because we already know the date on which our own rule
gets broken if nobody remembers it, and that date is on the plan.

- [ ] **Re-read every on-device / privacy claim against what the build actually does** —
      in-app strings, the App Store listing (Description, Promo, Subtitle, What's New) and
      `docs/PRIVACY_POLICY.md` — and for each one: still true, or rewritten. **Enumerate them
      at that point.** Do not rely on today's count of "five shipped strings"; that number came
      from a grep, and a grep has been the wrong instrument four times in this project already.

**Why this is a gate and not a note.** Those strings are TRUE TODAY and become FALSE on the day
`cloudKitDatabase` is flipped to `.private(…)`. Not by oversight — **by schedule.** The claim
does not change; the app changes underneath it.

**Why privacy copy specifically.** In a money app this is not ordinary copy. It is read by App
Store review, and by the users who chose Budget Crab *for that sentence*. The positioning rests
on it, so a stale claim here is both a review risk and a broken promise to the people most
likely to notice.

**And the reason this entry exists at all:** ARCHITECTURE.md now says UI copy asserting
behaviour is a claim, verified like any other claim. All three occurrences of that defect so far
— "100% on-device", the 40-day privacy policy, "Every other screen works normally" — were found
**retrospectively**, after the copy was already wrong and in one case already shipped. This is
the first chance to apply the rule BEFORE the fact. A rule that has only ever been applied in
hindsight has not yet been shown to work.

## 1. Final device QA — ONE clean-reinstall pass (the gate)
Gate: delete app → `git pull` (latest commits) → Xcode Clean Build Folder (⇧⌘K) → rebuild. Then run in **all 5 locales** (en/ru/es-MX/pt-BR/uk), Dark + Light, on a normal phone + one small (SE/mini):
- [ ] **Amount parser (the last fix):** long amount with kopecks/cents, BOTH text and voice, in ru + en + pt-BR (comma-decimal) and es-MX (period). `10143,15`, `10 143,15 руб.`, voice "1342 рубля 15 копеек" → correct value.
- [ ] **QuickEntry "+" sheet:** rises smoothly, hint "Введите/скажите сумму" stays visible above keyboard, log has no `Invalid frame dimension` spam.
- [ ] **Keyboard dismiss:** on Add Category + Add Account via Return / Done / drag-down.
- [ ] **Pulse:** income + expense same day → income shows in Earned + chart; Pulse on the 1st of a month = "needs more days" placeholder (NOT a crash).
- [ ] **CSV round-trip in ru:** create tx with kopecks + a comma-in-name → export → re-import own file = 0 duplicates, amounts/categories intact.
- [ ] **Premium in SANDBOX** (real sandbox Apple ID, StoreKit config OFF): start trial → Export/Import open immediately WITHOUT relaunch; localized purchase sheet; Restore works.
- [ ] Core loop: onboarding, Save & add another, category picker (full list one step), edit a tx, no crash/freeze.

## 2. App Store Connect — finalize
- [ ] **IAP:** all 3 (`bc_premium_monthly`/`bc_premium_annual`/`bc_premium_lifetime`) Ready to Submit; **attached to the version** (In-App Purchases section on the version page — select all 3); **Family Sharing = ON on Lifetime**; check the **red minus on Portuguese (Brazil)** subscription localization (fill display name if incomplete).
- [ ] **Metadata, 5 locales:** Name/Subtitle (App Information), Promo/Keywords/Description (version page), 8 screenshots per locale in the **6.9" slot** (from `AppStore/composed/<locale>/`). (Optional ASO: add `csv` to keywords if it fits 100 chars.)
- [ ] **App Review Information:** Sign-in required **unchecked**, Contact filled, Notes pasted (no login / on-device / demo / not financial advice).
- [ ] **Version Release → Manually release** (you travel Aug 20).
- [ ] **Pricing/Availability:** app = Free; Mac availability **unchecked**; School-Manager volume unchecked; Public.
- [ ] Content Rights = No · Age 4+ · App Privacy = Data Not Collected · Privacy/Support URLs live (budgetcrab.app).

## 3. Build & submit
- [ ] Xcode: Version **1.0**, increment **build number**, `ITSAppUsesNonExemptEncryption = NO` present, Release scheme, all icon sizes.
- [ ] **Archive → Distribute → App Store Connect (upload).**
- [ ] **UNCHECK "Manage Version and Build Number" in the Distribute App dialog.** Or export from
      the command line, which cannot forget:
      `xcodebuild -exportArchive -archivePath <archive> -exportPath build/export -exportOptionsPlist ExportOptions.plist`
      — `ExportOptions.plist` pins `manageAppVersionAndBuildNumber` to **false** with the reason
      inline. Checked (the default), Xcode may silently increment the build number *during export*
      when App Store Connect already holds it, and the uploaded binary then carries a build the
      tagged commit never contained — while the tag, the release branch and the `StoreFixtures/`
      MANIFEST all keep asserting the old one, with nothing warning. **That is the tag rule's
      guarantee, broken without a symptom.** On build 10 it was left at the default and Xcode
      happened not to renumber; *it did not happen* is not *it cannot happen*.
- [ ] **Tag the submitted commit** — `git tag vX.Y.Z-buildN && git push --tags`. Without it, "which
      commit shipped as X.Y.Z" becomes a judgment call within weeks: the 1.0.1 and 1.0.2 fixtures had
      to be inferred from version-bump boundaries, and the first attempt at 1.0.2 picked a commit
      that still said `MARKETING_VERSION = 1.0.2` but already contained the V2 schema — i.e. 1.0.3
      development. Caught by inspecting the captured shape, not by the version string.
- [ ] **Capture the store fixture for this version** — `scripts/capture-store-fixture.sh <tag> VX_Y_Z`,
      then add its case to `ShippedStoreShapeTests` and commit both. Do it HERE, not later: this is
      the one moment the binary that writes that store definitely exists and definitely builds.
      Skipping it is how `SchemaV1` came to describe 1.0.2 rather than 1.0.0, which stranded
      1.0.0 users on a dead-end screen for two releases
      (`BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`).
- [ ] **Run the migration repro against a RELEASE build** — every migration measurement to date has
      been made on Debug. The path has no `#if DEBUG` branch, so they should not differ; "should not"
      is the phrasing that has cost this project a week at a time.
- [ ] On the version page: **select the uploaded build**.
- [ ] **Add for Review** → status "Waiting for Review."

## 4. After submit (set up now so it coasts)
- v1.0.1 backlog: color-scheme picker (calm default), Save-to-Spend hero + Pace, analytics redesign, TipKit help, @ModelActor write-path, flexible CSV import (Mint/bank), daily tips, iPad, remaining audit P1s (store-corruption recovery, gate `print()`, Siri phrase localization, fix stale `ft_*` in ARCHITECTURE.md).
- Post-launch: Product Page Optimization A/B (keyword-first title), Custom Product Pages (CSV / cash-flow), App Store featuring nomination.
