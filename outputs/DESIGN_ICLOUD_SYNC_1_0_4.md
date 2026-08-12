# DESIGN 1.0.4 — iCloud sync (private CloudKit)

**Status: DESIGN ONLY.** No code, no schema change, no entitlement edit was made
producing this document. Read with `DESIGN_AUTOPOST_RECURRENCE_1_0_4.md` — the
two are coupled (§0.1).

Scope: **private** sync of one user's own devices via SwiftData + CloudKit
private database. Out of scope, named so nobody assumes it: `CKShare` /
couples / family sharing (a genuinely different design — shared zones,
participant management, per-record ACLs — and a separate doc when we want it).

---

## 0. The two things to read before anything else

### 0.1 Sync breaks recurrence *today*, before auto-post is even discussed

The recurrence period watermark lives in `UserDefaults.standard` as
`recurring.handled.<uuid>` (`RecurrenceService.swift:30`, `:247–258`). It is
per-device and not synced.

With sync on and **today's manual Add/Skip flow unchanged**:

1. Netflix is due. Device A prompts. User taps Add. A writes the instance and
   sets `recurring.handled.<uuid>` locally.
2. The instance syncs to device B. B's `handled` key is still unset.
3. B computes `nextDueDate` from `tx.date` → same period → **prompts again**.
4. User taps Add. Two identical charges in the ledger.

So the watermark migration is a **prerequisite of shipping sync**, not a
prerequisite of shipping auto-post. It is specified in Doc 2 §3. Sync must not
ship without it.

### 0.2 Our `uuid` is not the sync identity

CloudKit identity is the CKRecord name derived from SwiftData's
`PersistentIdentifier`. One model instance ⇄ one CKRecord — sync never mints a
`uuid` duplicate for a record it is replicating. But `.unique` was removed in
V2, and **first sync between two devices that already have data is a union**
(§2.3): after it, two rows can legitimately carry the same `uuid`. Every
`fetch(where: uuid == x).first` becomes "an arbitrary one of possibly several".
Audit list in §3.6.

---

## 1. Container setup

### 1.1 The configuration change (one line, plus a process rule)

`SharedModelContainer.openContainer(storeURL:localStoreURL:preflightRepair:)`
(`SharedModelContainer.swift:250`) already builds exactly the two-configuration
shape this needs. The sync flip is:

```swift
// synced store — Vela.sqlite
ModelConfiguration("synced", schema: syncedSchema, url: store,
                   cloudKitDatabase: .private("iCloud.com.dmitrylogachev.budgetcrab"))

// local-only store — VelaLocal.sqlite  (unchanged)
ModelConfiguration("local", schema: localSchema, url: localStore,
                   cloudKitDatabase: .none)
```

`MerchantCategoryLearning` coexisting with the synced config is already solved
and needs **no change**: it lives in its own `Schema` on its own store file with
`cloudKitDatabase: .none`, no relationship crosses the two configurations (it
stores `categoryName` as a `String`), and being non-synced is what legally keeps
its `@Attribute(.unique)`. Its doc comment is a privacy promise; this design
does not touch it. One consequence to state in the consent copy: **merchant
learning does not follow the user to a second device** — the new device
re-learns. That is the intended trade, not a defect.

### 1.2 One sync engine per store file — enforced through an existing seam

Rule (§1.3 of `DESIGN_1_0_3_MODELS_FABLE.md`): only the **main app** process may
open `Vela.sqlite` with CloudKit enabled. The widget never opens the store at
all (it renders the baked `NetSnapshot` from App Group defaults —
`SharedModelContainer.swift:5–8`), so it is unaffected. The problem process is
**AppIntents**, which open the same file headless.

The codebase already separates these two openers, and the separation is exactly
the right seam:

| Opener | Who reaches it | CloudKit |
|---|---|---|
| `bootstrap()` → `openContainer()` | main app, via `LaunchGateView` only | `.private(…)` |
| `readyContainer()` fresh-open branch | any process that never ran bootstrap = headless AppIntent | `.none` |

Recommended shape: add a `cloudKitDatabase:` parameter to
`openContainer(storeURL:localStoreURL:…)` defaulting to `.none`, and have
`bootstrap()` — and only `bootstrap()` — pass `.private(…)`. In the app process
`readyContainer()` returns the already-created `current` container, so app code
paths (`FinanceTrackerApp.swift:138`, `:146`) keep getting the synced one; in an
intent process `current` is nil and the fresh open is local-only by
construction. No new global, no process-name sniffing.

**Consequence that must be verified, not assumed (O-1):** a write made by the
headless intent process is not seen by a sync engine that is not running.
NSPersistentCloudKitContainer exports such changes from persistent history the
next time the app process runs its engine — *if* history tracking is on for that
store for every opener. SwiftData does not expose that switch. The observable
question is simply: **Siri-add a transaction with the app never launched; launch
the app; does it reach device B?** If the answer is no, the fallback is a
foreground reconciliation pass, and the fallback UX ("Siri entries sync when you
next open the app") is acceptable. This is a drill item (§7, D-11), not a
blocker to designing.

### 1.3 Entitlements / capabilities to add — list, not applied

App target (`FinanceTracker/FinanceTracker.entitlements`, today contains only
the App Group):

- `com.apple.developer.icloud-services` → `["CloudKit"]`
- `com.apple.developer.icloud-container-identifiers` →
  `["iCloud.com.dmitrylogachev.budgetcrab"]`
- `aps-environment` → `development` / `production` (CloudKit's silent pushes;
  without it, remote changes only arrive on the next foreground poll)
- Info.plist `UIBackgroundModes` → `remote-notification`

Portal / project:

- Create the CloudKit container `iCloud.com.dmitrylogachev.budgetcrab` in the
  developer portal; enable the iCloud capability on the App ID; regenerate the
  provisioning profile.
- Xcode → Signing & Capabilities → iCloud → CloudKit → tick the container. Add
  Background Modes → Remote notifications.
- **Do not** add any of this to the widget target. It does not open the store.

CloudKit Console, and this one is a silent-failure trap:

- The Development schema is auto-created from the model on first run of a
  **Debug** build. The Production schema is **not**. "Deploy Schema Changes" in
  the CloudKit Console must be run before the TestFlight build that becomes the
  App Store build. Skip it and every production user gets a silently inert sync.
- Production schema is **additive-only, forever**: no field rename, no retype,
  no deletion. From the day sync ships, every future schema change must be a
  new optional field. This ends the freedom the V1→V2 migration had, and it is
  the single biggest long-term cost of this feature. Worth stating to the
  founder in one sentence: *we are trading future schema freedom for sync.*

### 1.4 Ordering against the migration gate

Sync is only ever enabled on a store that has **completed** V2 migration. Two
rules fall out and both are cheap:

- `bootstrap()` reaches the `.private(…)` open only on its success paths. The
  degraded floor (`MigrationFloorView`) and the read-only V1 export container
  (`openV1ReadOnly`) stay `.none` — we never upload a store we just failed to
  migrate.
- `v2MigrationComplete` and the attempt/restore sentinels stay **local** App
  Group flags. They describe *this device's store file*. Syncing them is
  meaningless and would break a fresh device's gate.

---

## 2. First sync, consent, and onboarding

### 2.1 Recommendation: opt-in, off by default, premium-gated

`AppCapability.iCloudSync` already exists with `requiresPremium == true`
(`FreeTierLimits.swift:93`, `:105`) and is deliberately kept off the paywall via
`PaywallComparison.unshippedCapabilities`. Shipping means: remove it from that
set and add a `Row(capability: .iCloudSync, …)` to `PaywallComparison.rows` —
the table derives from the capability, so the copy cannot drift from the gate.

**Both sides, honestly:**

*For default-on:* sync is the most-requested feature in this category; discovery
of a Settings toggle is poor; a user who loses their phone with sync off loses
everything (the store is even `isExcludedFromBackupKey = true`, so there is no
device-backup copy either — see §2.5).

*For opt-in (recommended):*

1. **Shipped copy would become false.** Flipping the default makes these false
   for existing users *without them acting*. Opt-in lets the strings stay true
   for everyone who does not opt in, and the changed strings become conditional
   ("…unless you turn on iCloud sync").

   > **⚠️ CORRECTED 2026-08-12** (`AUDIT_BACKLOG_VERIFIED_2026-08-12.md` §B.6).
   > This paragraph said **"Five keys × 5 locales"** and then listed **four**.
   > Both numbers were wrong. Verified against HEAD `4e6a8db`, the live, rendered
   > count is **TEN**. It also named `tutorial.page3.bullet1` first — which is a
   > **dead string**: no view renders it (the 3-page carousel was retired), so it
   > must be **deleted, not rewritten**, and it never belonged on this list.
   >
   > The two the original list missed are the sharpest of all, because they are
   > enumerated claims sitting under a heading that reads *"what we do not do"*:

   | Key | Rendered at | Under sync |
   |---|---|---|
   | `onboarding.greeting.privacy` — "nothing leaves your phone" | `MascotGreetingView` | **FALSE** |
   | `help.privacy.body` — "never leaves your device" | `HelpView` | **FALSE** |
   | `settings.privacy.title` — "Your Data Stays on Your Device" | `PrivacySettingsView` | **FALSE** |
   | `settings.privacy.subtitle` — "No cloud account…" | `PrivacySettingsView` | **FALSE** |
   | **`privacy.claim.no_cloud_account`** | `PrivacySettingsView:85` | **FALSE** ← *was missed* |
   | **`privacy.claim.no_data_uploaded`** | `PrivacySettingsView:86` | **FALSE** ← *was missed* |
   | `paywall.subtitle` — "no servers, no accounts" | `PaywallView` | **FALSE** |
   | `about.privacy_hint` — "No accounts, no servers." | `AboutView` | **FALSE** |
   | `about.tell_friend.share` — "a private, on-device finance app" | `AboutView` | **FALSE** (outbound marketing) |
   | `quick_entry.privacy_chip` — "Stays on your iPhone" (+ its a11y twin) | `QuickEntryView` | **FALSE** |

   **Stays TRUE — do not touch.** These are about *processing*, not storage, and
   remain accurate under sync: `help.quick_add.body` (parsing is local),
   `help.voice_entry.body` (audio never sent to a server),
   `quick_entry.listening`, `quick_entry.a11y.mic_hint`.

   **Dead — delete rather than rewrite:** `tutorial.page2.caption`,
   `tutorial.page3.bullet1`, `tutorial.page3.bullet3`.

   Corrected now, while it is a documentation edit. On the day sync ships it is a
   copy emergency, and an undercount of 4-vs-10 is how two of them get missed.
2. **Privacy label re-audit is a documented trigger.** `APP_PRIVACY_ANSWERS.md`
   §6 lists "CloudKit / iCloud sync is enabled" as a mandatory re-audit trigger.
   The answer very likely stays *Data Not Collected* (private-database data is
   the user's, in the user's iCloud, unreadable by us — Apple's own guidance),
   but the audit must be re-run and the doc updated before submission.
3. **It is a paid feature.** A premium feature that is silently on for everyone
   is not a feature, it is a surprise.
4. **Blast radius.** A first-release sync bug reaches only users who chose it.

**Recommended default: OFF. Settings → iCloud Sync, plus one non-blocking
promo card shown once to premium users.** Ship the discovery, not the default.

### 2.2 The consent screen — what it must say

Not a checkbox. A short screen, before the first `.private(…)` open, stating:

- **What syncs:** transactions, categories, accounts, splits.
- **What does not:** merchant learning (stays on this device), your daily-tip
  collection, app settings and reminders (§4).
- **Where it goes:** your own private iCloud. We have no servers and cannot read
  it. It counts against your iCloud storage.
- **It combines, it does not replace.** If your other device already has
  transactions, you end up with both sets. ← the sentence that prevents the
  worst support thread.
- **Turning it off later** keeps everything on this device; the copy already in
  iCloud stays there until you remove it in iOS Settings (§6.5).

### 2.3 The three first-sync shapes

| Shape | What happens | Verdict |
|---|---|---|
| **Fresh + fresh** | Trivial. | Fine. |
| **Existing local user + fresh device** (the upgrade path) | Device A exports its whole store; B imports it. Nothing local is deleted — export is a read of local plus a write to cloud. Both seeded category sets exist, but B's is brand-new and B has zero transactions, so the dedup in §2.4 collapses them cleanly. | Fine, with §2.4. |
| **Existing + existing** (the hazard) | Union. Both ledgers merge. Two full seeded category sets, two account sets, and any transaction the user entered on both devices appears twice. | Needs §2.4 **and** the honest consent sentence. |

### 2.4 The post-first-sync reconciliation pass

Runs once after the first import converges (defined as: an import landed and
then ≥N seconds passed with no further import — a settle timer, not a promise).

- **Categories:** merge by `nameKey` first (seeded ones), then by
  case/diacritic-folded `nameCustom`/`name` + `kindRaw`. Keep the oldest
  (`order`, then earliest-created), repoint the loser's `transactions` and
  `splits` to the winner, delete the loser. Deterministic on both devices, so
  they converge on the same winner even if both run it.
- **Sources/accounts:** same rule by folded `name`. Note the free-tier cap is
  2 accounts — a merge can leave a free user above their cap. That is fine and
  already the designed behavior: `AccessLogic.canAdd` gates *adding*, never
  what already exists (`AccessManager.swift:26–30`).
- **Transactions:** never auto-merge, never auto-delete. Run the existing
  content matcher and set `isPossibleDuplicate` (`Transaction.swift:54`,
  `DuplicateReviewService`), which already has a badge and a review sheet. The
  user decides. This is the same principle as
  `project_quickadd_no_content_dedup`: identical content ≠ accidental
  duplicate, and silently deleting a real transaction is the worse failure.
- **Splits:** nothing to do — they are children of their parents.

### 2.5 One consequence of the current backup posture

`applyProtection` sets `isExcludedFromBackupKey = true` on both store files
(`SharedModelContainer.swift:352`). So today there is **no** iCloud device-backup
copy of the ledger either. For a sync-off user that is a real statement to make
plainly in the consent copy ("this device is currently the only copy of your
data"), and it is a genuine argument in favor of promoting sync. It does not
change under sync (CloudKit is the copy).

---

## 3. Conflict resolution

### 3.1 The model to design against

SwiftData over CloudKit is **eventually consistent, record-level
last-writer-wins**. Do not design anything that needs cross-record atomicity or
per-field merge guarantees across devices. The one lever we have is that all
records from a single `context.save()` go up as one batch to one zone
(`com.apple.coredata.cloudkit.zone`), so a save is practically atomic — but the
guards below must survive it not being.

The invariants we already hold and that do the heavy lifting:

- **The grand total is always `Σ tx.amountCents`** — never a sum over splits.
  Category-blind aggregation reads the parent; only category-dimension
  aggregation goes through `CategoryAttribution.rows(for:)`. Canary C0/C2.
- **Remainder model, not exact-sum** (`TransactionSplit.swift:12–19`,
  design §2.2). Chosen *because* CloudKit makes exact-sum unenforceable.
- **Orphans are invisible.** Attribution derives from the parent, so a split
  whose parent has not arrived (or was deleted) contributes nothing.

### 3.2 Split parent + children edited on two devices

| Race | Converged state | Why it is acceptable |
|---|---|---|
| A edits parent 400→300; B adds a 150 split | Parent 300, splits may sum > 300 | Over-sum rule already specified: remainder = `max(0, total − Σ)`, splits counted as stated. **Grand total = 300 on both devices.** Category totals transiently over-sum; the editor surfaces the discrepancy on next open. No money invented in any total the user reads as "the total". |
| A deletes a split; B edits the same split | LWW; a late edit can resurrect the row | Worst case: an extra split. It is still bounded by its parent for grand-total purposes, and re-opening the editor fixes it. |
| A deletes the parent; B adds a split to it | Cascade removes A's children; B's new child arrives parentless | Invisible orphan row. Zero effect on any number. |
| Both devices split the same purchase differently | Union of splits → over-sum | Same as row 1. |

**No orphaned splits that affect a number, no double-count of the grand total,
in any of the four.** That is the whole reason the remainder model was chosen in
1.0.3, and it pays off here exactly as predicted.

Deferred, deliberately: an orphan sweep. A nil `parent` is *also* the normal
transient "parent hasn't arrived yet" state, so any sweep must be time-gated
(orphaned > 7 days, and at least one completed import). Since orphans are
invisible and tiny, this is a 1.0.5 tidiness item, not a 1.0.4 requirement.

### 3.3 Category rename / delete

- **Rename** is one field on one record → LWW → last rename wins on both. No
  action needed.
- **Delete racing an edit:** `.nullify` is now genuinely enforced (explicit
  inverse, `Category.swift:51`), so transactions on the other device become
  Uncategorized. Money preserved, attribution lost, renders through the
  nil-category contract (§1.4 of the 1.0.3 doc) as "Uncategorized". Acceptable —
  and it takes two devices disagreeing about "in use", because
  `CategoriesSourcesView` still blocks deleting a category that is in use
  locally. Keep that guard; add nothing.
- The **duplicate-category** problem is a first-sync problem, not a conflict
  problem. §2.4.

### 3.4 Deletion racing an edit on a Transaction

Both devices converge on one outcome (row gone, or row present with the edited
values). Which one is not worth engineering: for a ledger row, "you may have to
delete it again" is an acceptable worst case, and both devices agree afterwards.
What must never happen is **duplication**, and it cannot: one model instance is
one CKRecord.

### 3.5 What *could* actually double-count

Only paths that create rows on a schedule. That is exactly recurrence, and it is
Doc 2's entire §3. Nothing else in the app writes rows without a user tap.

### 3.6 `uuid`-uniqueness audit (post-union)

Sites assuming one row per `uuid`, to re-read before shipping:

- `RecurrenceService.fetchTemplate(_:modelContext:)` (`:239–242`) — `.first` of
  a predicate on `uuid`. After a union, two templates can share a uuid; the
  service would drive one and prompt for both. Interacts with Doc 2 §3.
- `CSVImportService` fetch-by-uuid-then-skip — behavior is unchanged and still
  correct (skipping against *any* matching row is the intent).
- `SeedService` idempotence is by `nameKey`, not uuid → unaffected.
- Export/import round-trip: unaffected (canary C7 covers it).

---

## 4. Non-model state: sync it, or keep it per-device

**Standing rule to write into the code comment: `UserDefaults` is never synced
wholesale. Every key is an explicit decision and the default is per-device.**

| State | Where it lives | Verdict | Why |
|---|---|---|---|
| `recurring.handled.<uuid>` | `UserDefaults.standard` | **Must move into the synced model.** Doc 2 §3 | §0.1 — without it, sync alone double-charges. Blocking. |
| `recurring.lastPromptDay`, `recurring.notifAuthRequested` | standard defaults | Per-device | A throttle and a one-shot permission ask. Divergence is invisible. |
| Reverse-trial start (`AppGroupReverseTrialStore`) | App Group | **Per-device** | See §4.1 — the farming scenario is nearly closed by construction. |
| `hasShownTrialEndPaywall` | App Group | Per-device | Worst case: the paywall is shown once per device. Fine. |
| `tipDeckSeed`, `tipRevealedIDs`, `tipLastRevealDay` | standard defaults | Per-device (explicitly out of scope) | Documented decision: "a reinstall resetting it is the correct behaviour". The reveal log is append-only and the per-user rework exists precisely because rewriting it mis-reveals the back-catalogue. Merging two logs risks re-introducing that. Cost to state: a two-device user sees two different tips-of-the-day and two collection counts. Backlog. |
| `defaultCurrencyCode` | `@AppStorage` + mirrored to App Group | **Ledger-semantic — needs handling.** §4.2 | The only setting whose divergence corrupts data rather than presentation. |
| `monthlyBudgetCents` | `@AppStorage` | Per-device for 1.0.4, surfaced as such | Drives safe-to-spend, the widget hero and alert bodies. Divergence is confusing but harmless — no stored value changes. |
| `alertsEnabled`, `alertHour/Minute/Weekday` | `@AppStorage` | Per-device | Notification prefs are legitimately per-device (alerts on phone, not iPad). iOS treats them this way too. |
| `appLanguageCode`, `appearanceMode`, `horizon_mode`, `requireAuthMode`, `quickAddConfidenceThreshold` | `@AppStorage` | Per-device | Presentation/local-security. `requireAuthMode` especially: biometric policy is a property of a device. |
| `hasCompletedOnboarding`, `hasSeenFeatureTour`, `hasSeenOpenFormHint`, `hasSeenPeriodHint`, `swipe_hint_shown_count`, `firstLaunchDate`, `TipDismissal` | standard defaults | Per-device | Coach-marks are per-device by nature. A second device re-teaching itself is correct. |
| `v2MigrationComplete`, `v2MigrationAttemptCount`, `v2RestorePendingNotice`, `legacyStoreMigrationChecked` | App Group | **Per-device, must never sync** | They describe *this device's store file*. |

### 4.1 Reverse trial — recommendation: leave it per-device

The brief asks whether device #2 can farm a fresh 14 days. It largely cannot,
by construction: **`iCloudSync.requiresPremium == true`**, so a user on the
reverse trial cannot turn sync on at all. The scenario requires the user to
already be paid — in which case `AccessLogic.isPremium` short-circuits on the
real entitlement and the trial date is irrelevant.

- *For syncing it* (via `NSUbiquitousKeyValueStore` with a `min()` merge, since
  the start date only ever moves backward in the user's favor): closes the hole
  completely, ~20 lines.
- *Against (recommended)*: it adds the `ubiquity-kvstore-identifier`
  entitlement and a new failure mode (KVS is silent when signed out) to defend
  against an exposure of "a two-device user gets a second 14-day *preview* of a
  feature set they can already see" — and StoreKit entitlements, the thing that
  actually costs money, already sync through Apple.

**Recommended default: per-device. Revisit only if data shows multi-device
preview farming.**

### 4.2 Default currency — the one setting that can corrupt

`Transaction.currency` is stamped from the local `defaultCurrencyCode` at
creation, while all aggregation reads the *current* default
(`ARCHITECTURE.md` §"Currency is locked…"). Two devices with different defaults
produce one synced ledger with mixed `currency` strings rendered under one
symbol — a wrong number the user cannot see is wrong.

Options:

1. **Sync it via KVS.** Correct, needs the entitlement, and LWW on a currency is
   itself a little scary (a stray change on device B restamps nothing but
   changes how everything renders).
2. **A synced singleton `LedgerSettings` model row.** No new entitlement, rides
   the consent the user already gave — but a singleton in a LWW store needs a
   duplicate reconciler, and adds a model to a schema we just froze.
3. **Detect and prompt (recommended for 1.0.4).** After the first import
   settles, if the local default differs from the modal `currency` of the
   synced transactions, show a one-time, non-blocking prompt: *"Your other
   device records in EUR. Use EUR here too?"* Zero entitlement, zero schema,
   zero silent write, and it makes the divergence visible at the only moment it
   matters. It also handles the case option 1 cannot: a genuine mismatch that
   existed *before* sync.

**Recommended: option 3 for 1.0.4; KVS (option 1) later if the prompt proves
insufficient.** `monthlyBudgetCents` gets no mechanism at all — it is listed in
the Sync settings screen under "kept separate on each device".

---

## 5. Widget and App Group under sync

Nothing about the widget's data path changes, and that is the point: it reads
the baked `NetSnapshot` from App Group defaults and never opens the store. The
App Group + `.completeUntilFirstUserAuthentication` protection posture stays as
is (it exists for headless AppIntents, `SharedModelContainer.swift:341–351`).

What changes is **when the snapshot is rebuilt.** Today it is rebuilt from
`DashboardView`'s content-signature `onChange` (`DashboardView.swift:329`),
i.e. only while the app is in the foreground with the Dashboard alive. A remote
import does not fire `ModelContext.didSave`, so under sync a transaction added
on the iPad would not reach the iPhone widget until the iPhone app is opened.

**Design:** add one remote-change hook alongside the two that already exist in
`FinanceTrackerApp.swift:133–149` (`scenePhase == .active` and
`ModelContext.didSave`), observing `.NSPersistentStoreRemoteChange` for the
synced store, coalesced through the same `ProactiveAlertRefreshScheduler`
debounce that already collapses save bursts. It must drive **both** consumers of
a data change:

- `NetSnapshotBuilder.updateSnapshot(…)` → widget
- `ProactiveAlertRefreshScheduler.schedule(container:)` → the safe-to-spend
  notification body, which is frozen at schedule time and *only* moves on a
  write (`project_proactive_alerts_v102`). A remote write is a write.

**The honest guarantee to ship: "fresh by the next time you open the app."**
With `aps-environment` + `remote-notification` the engine can import while the
app is backgrounded, so in practice it will often be fresher — but a terminated
app is not woken for this, and promising live cross-device widgets would be a
promise we cannot keep.

The `v2MigrationComplete` gate is untouched and stays local (§1.4).

---

## 6. Failure modes — degrade, never block, never lose

| Mode | Behavior | UI |
|---|---|---|
| **Offline** | Local writes commit normally and queue for export. | Nothing modal. "Last synced <relative time>" in Settings → Sync. |
| **Not signed in to iCloud** | The store opens and works; sync is inert. This must be verified as non-throwing at open (drill D-9) — the app must never fail to launch because of an iCloud account state. | "Sync paused — sign in to iCloud in Settings." Never a blocking screen. |
| **iCloud storage full** (`CKError.quotaExceeded`) | Local writes keep committing; export stalls indefinitely. **Nothing is ever deleted locally.** | Persistent non-modal notice in Settings → Sync: "iCloud storage is full — new changes aren't syncing." |
| **Throttling / initial upload** | A large store (the founder's is in the thousands of rows) uploads over minutes-to-hours in the background, with server-driven retry-after. | "Syncing…" plus last-updated. Never a modal, never a progress bar that implies the user must wait. |
| **Schema not deployed to Production** | Silent no-op sync for every App Store user. | Prevented by process (§1.3), detected by drill D-12. |
| **Restore-from-backup ran** (the §10 ladder) | The restored store lacks CloudKit metadata for newer records; the engine will re-import from the cloud and effectively undo the restore. | Sync stays off until the user acknowledges `RestoreNoticeView`; the restore notice should say the iCloud copy will be re-downloaded. Narrow case (a restore only happens on a failed migration, and sync is only enabled post-migration), but it must not surprise us. |

**Status UI without unsupported plumbing (O-3).** SwiftData exposes no public
sync-event API; `NSPersistentCloudKitContainer.eventChangedNotification` works
underneath but is not SwiftData's contract. Recommendation: derive the status
line from two supported inputs — `CKContainer.default().accountStatus()` and a
locally-stored "last remote change observed" timestamp written by the §5 hook.
Ship that; treat the private event stream as DEBUG-only diagnostics if used at
all.

---

## 7. Verification plan (design only — this is the ship gate)

CloudKit cannot be unit-tested. This mirrors the §11 real-store protocol of the
1.0.3 doc: a manual, non-cuttable runbook, run on **two devices signed into one
test Apple ID** (a second simulator with a signed-in account works for most of
it; D-8 and D-11 need real hardware).

Add a DEBUG **Sync Status** panel in Settings → Debug (precedent: the
chart-bisection panel, and it goes on the same "delete when the bug is closed"
list in `ARCHITECTURE.md`): account status, last remote change, per-entity local
row counts. Without it, a field report is unfalsifiable.

| # | Drill | Pass condition |
|---|---|---|
| D-1 | Fresh + fresh. A creates 20 tx incl. 2 split and 1 recurring. | B shows exactly 20, splits intact, counts equal via the debug panel — not by eyeball. |
| D-2 | **Existing + fresh** (the upgrade path). A = a copy of the real store, B = clean install. | B's count == A's count; **A's count unchanged**. This is the data-loss check. |
| D-3 | **Existing + existing** (union). Independent data on both. | Nothing deleted on either; seeded categories converge to one set; content duplicates carry `isPossibleDuplicate` and appear in the review sheet. |
| D-4 | Offline divergence. Airplane-mode both, edit the same tx differently, reconnect. | Converges to one value; **no duplicate row**; grand totals equal on both. |
| D-5 | **Split conflict.** A edits parent amount down; B adds a split. | Grand total on both == parent amount. Category totals may over-sum. Re-opening the editor surfaces it; after a fix both agree. Check by hand against C0/C2. |
| D-6 | Delete race. A deletes; B edits. | Single converged outcome; equal totals both sides. |
| D-7 | **Recurrence.** A monthly series due today, both devices launched. | **Exactly one** instance after convergence. Doc 2 §3. **Ship blocker.** |
| D-8 | Widget freshness. Add on A; do not open B. | B's widget is stale (expected, documented); opening B refreshes it within one timeline reload. |
| D-9 | Sign B out of iCloud. | App launches, all local data present, status says paused. Sign back in → converges. |
| D-10 | Full path: a 1.0.2 V1 store → 1.0.4. | Migration runs first with sync off, then the user enables sync; no interaction between the two. |
| D-11 | Siri/AppIntent write with the app never launched, then launch. | Reaches B (validates §1.2 / O-1) — or documents the fallback. |
| D-12 | Production schema check. | CloudKit Console shows `CD_Transaction`, `CD_Category`, `CD_Source`, `CD_TransactionSplit` in **Production** before submission. |

Automatable in advance of the drills (worth doing, cheap): the §2.4
reconciliation rules are pure functions over arrays of category/source
descriptors — unit-test the merge-winner choice for determinism (both devices
must pick the same winner from the same input).

---

## 8. Open questions, with a recommended default for each

| # | Question | Recommended default |
|---|---|---|
| **O-1** | Do headless AppIntent writes (store opened `.none`) reach other devices once the app runs? | Assume **yes via persistent history**, verify with D-11. If no: reconcile on foreground and document "Siri entries sync when you next open the app". Not a ship blocker either way. |
| **O-2** | Sync default-on or opt-in? | **Opt-in, off by default, premium** (§2.1). The five privacy strings and the ASC re-audit are the deciding factors, not engineering. |
| **O-3** | How does the UI know sync state without private API? | `accountStatus()` + a locally-stored last-remote-change timestamp (§6). |
| **O-4** | Does `defaultCurrencyCode` sync? | **No mechanism in 1.0.4** — detect-and-prompt after first sync (§4.2 option 3). |
| **O-5** | Does the reverse-trial start sync? | **No** — the premium gate on `iCloudSync` already closes the farming path (§4.1). |
| **O-6** | Do tips/collection sync? | **No** — out of scope, stated in the consent copy (§4). |
| **O-7** | Can the user delete the iCloud copy from inside the app? | **Not in 1.0.4.** "Turn off sync" stops syncing and keeps local data; deleting the cloud copy points to iOS Settings → iCloud → Manage Storage. Deleting the record zone from the app is destructive across devices and deserves its own design. |
| **O-8** | Do we ship the orphan-split sweep? | **No** — orphans are invisible to every number (§3.2). 1.0.5. |
| **O-9** | Is sync gated on premium at the *toggle* or does an existing synced user who lapses stop syncing? | **Gate the toggle only.** Never stop syncing data a user already trusted us with — the reverse-trial precedent is explicit that lapsing takes away *adding*, never what exists. |
| **O-10** | One release or two? | See below. |

### The smallest safe 1.0.4 slice

**In:**

1. The recurrence watermark moved into the synced model (Doc 2 §3) — a
   prerequisite, not an option.
2. Opt-in, premium-gated private sync of Transaction / Category / Source /
   TransactionSplit; `.private(…)` passed only by `bootstrap()`.
3. Consent screen (§2.2) + Settings → iCloud Sync with status and off-switch.
4. Post-first-sync reconciliation: automatic category/account merge; content
   duplicates surfaced through the existing `isPossibleDuplicate` review, never
   auto-deleted.
5. The remote-change hook driving widget snapshot + proactive-alert recompute.
6. Currency-mismatch prompt.
7. Paywall row for `.iCloudSync` (remove from `unshippedCapabilities`).
8. Privacy copy revision (5 keys × 5 locales) + `APP_PRIVACY_ANSWERS.md`
   re-audit.
9. DEBUG Sync Status panel + the D-1…D-12 runbook, all of it, before submission.

**Out, explicitly:**

CKShare / family sharing · settings & tips sync · delete-the-iCloud-copy from
in-app · orphan sweep · BGAppRefreshTask · any live cross-device widget promise
· per-field merge cleverness of any kind.

**On O-10 — sequencing.** The 1.0.3 doc's own rule was *never debug a migration
and a sync at once*. The same logic says: do not ship auto-post and sync in the
same build if either can slip, because a double-charged ledger has two possible
causes and you will not be able to tell them apart from a review. The clean
order is: **watermark-to-model + sync first (auto-post OFF, prompt behavior
unchanged), then auto-post in the next build once D-7 has been green on real
hardware for a release.** If they must ship together, D-7 becomes the single
hardest gate in the release and should be run at least twice on real devices.
