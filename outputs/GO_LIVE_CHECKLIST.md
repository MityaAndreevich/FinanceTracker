# Budget Crab — GO-LIVE checklist (code complete → Add for Review)

All v1.0 code blockers closed: CSV integrity, premium gate, Charts crash+freeze, locked-intent P0 (audit), QuickEntry UX, amount parser. Remaining = QA + ASC + submit. Work top to bottom.

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
