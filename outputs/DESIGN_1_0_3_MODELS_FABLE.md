# DESIGN 1.0.3 — CloudKit-ready models: relationship audit + split transactions

**Status: DESIGN ONLY. No code has been changed.**
Scope: every `@Model` in the app, audited against the CloudKit schema rules
(all attributes optional-or-defaulted, every relationship has an explicit
inverse, no `.unique`, no `.deny`), plus the full design for split
transactions including the aggregation rewrite.

Sources read: `ARCHITECTURE.md`, `Models/Transaction.swift`,
`Models/Category.swift`, `Models/Source.swift`,
`Models/MerchantCategoryLearning.swift`, `Data/SharedModelContainer.swift`,
`Shared/SafeToSpend.swift`, `Services/LedgerAggregator.swift`,
`Services/NetSnapshotBuilder.swift`, `Views/AnalyticsView.swift`,
`Views/DashboardView.swift`, the Analytics sheets, the export services,
`Services/RecurrenceService.swift`, and `outputs/BRIEF_1_0_3_FEATURE_PACK.md`.

---

## 0. Current model inventory

Exactly four `@Model` classes exist (verified by grep across app, widget, and
shared targets):

| Model | `.unique` | Relationships | Non-optional, non-defaulted attrs |
|---|---|---|---|
| `Transaction` | `uuid` | `category: Category` (.nullify, **no inverse**, **non-optional**), `source: Source?` (.nullify, **no inverse**) | `uuid, typeRaw, amountCents, currency, date, createdAt, updatedAt` |
| `Category` | `uuid` | none | `uuid, name, kindRaw, order` |
| `Source` | `uuid` | none | `uuid, name, isActive` |
| `MerchantCategoryLearning` | `merchantNormalized` | none | all four attrs |

`DailyTip` is a plain `Codable` struct, not a `@Model` — out of scope.
The container is `SharedModelContainer` (App Group store `Vela.sqlite`,
currently `cloudKitDatabase: .none`), one `Schema` shared by app, widget, and
AppIntents processes.

---

## 1. Relationship audit

### 1.1 Violations found

**V1 — `Transaction.category: Category` (Transaction.swift:60)**
- No explicit inverse. CloudKit requires one. ❌
- **Non-optional.** CloudKit requires every relationship optional. ❌
- Delete rule `.nullify` is CloudKit-legal, but nullify-into-a-non-optional
  is exactly the crash class we already hit once on this model
  (the historic `.deny` → NSError 1600 incident is documented in the in-code
  comment). Today, deleting a `Category` does *not* actually nullify anything
  — with no inverse, SwiftData has no back-pointer to walk, so the UI guard in
  `CategoriesSourcesView` is the only thing standing between us and a dangling
  reference into a non-optional property.
- Extra CloudKit reality: with sync, a `Transaction` record can arrive on a
  second device **before** its `Category` record. `category` being optional is
  not just a schema rule — it will genuinely be nil for real moments in time,
  and the UI must render that.

**V2 — `Transaction.source: Source?` (Transaction.swift:63) — the confirmed landmine**
- `.nullify` with **no inverse**. Confirmed: this is the known live crash.
  Without an inverse, SwiftData cannot enumerate "transactions pointing at
  this Source" at delete time, so the nullify is **unenforced** — deleting a
  `Source` leaves a dangling on-disk reference that survives relaunch and
  faults as `EXC_BREAKPOINT` the moment any row touches `tx.source`. The
  current mitigation is manual detachment in the delete path; an explicit
  inverse makes the store enforce it instead. ❌

**V3 — No inverse collections exist on `Category` / `Source` at all.**
Consequence beyond CloudKit: `CategoriesSourcesView`'s "is this category in
use?" check has to scan the whole transaction table. The inverse gives it a
free answer.

**V4 — `.unique` on all three synced models** (`Transaction.uuid`,
`Category.uuid`, `Source.uuid`). CloudKit forbids `.unique`. ❌
`MerchantCategoryLearning.merchantNormalized` is also `.unique`, but the fix
there is different (see 1.3) — that model must never sync at all.

**V5 — Non-defaulted required attributes** on all three synced models (table
above). CloudKit requires optional-or-defaulted. ❌

**No `.deny` rules exist anywhere.** ✅ (The one we had was already removed in
541876b.)

### 1.2 Corrected declarations

Inverse macro placement rule used throughout: `@Relationship(inverse:)` is
declared on **exactly one side** of each pair (declaring it on both sides is a
known SwiftData trap). The delete rule is declared on the side whose deletion
triggers the behavior: cascade lives on the parent, nullify-on-category-delete
lives on `Category`, etc.

**`Transaction`** (split-related lines included here; rationale in Part 2):

```swift
@Model
final class Transaction {

    /// Stable external identifier. NOTE: no longer @Attribute(.unique) —
    /// CloudKit forbids it. Uniqueness is now enforced at the write sites
    /// (importer already fetches-by-uuid before insert; keep it that way).
    var uuid: UUID = UUID()

    var typeRaw: String = TransactionType.expense.raw
    var amountCents: Int = 0
    var currency: String = "USD"
    var date: Date = Date()
    var taxCents: Int?
    var note: String?
    var merchant: String?
    var recurrenceRaw: String?
    var isDemo: Bool = false
    var isPossibleDuplicate: Bool = false

    /// OPTIONAL now (CloudKit rule + sync reality: the Category record may
    /// not have arrived yet). Inverse is declared on Category.transactions.
    /// nil renders as "Uncategorized" — see §1.4.
    var category: Category?

    /// Inverse declared on Source.transactions. Deleting a Source now
    /// actually nullifies this — the dangling-reference landmine is closed
    /// by the store, not by UI discipline.
    var source: Source?

    /// Child splits. Cascade: a split cannot outlive its purchase.
    /// Declared inverse lives HERE because the cascade is triggered by
    /// deleting the Transaction. Optional array per CloudKit.
    @Relationship(deleteRule: .cascade, inverse: \TransactionSplit.parent)
    var splits: [TransactionSplit]?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // init unchanged in shape; `category` parameter becomes Category?
}
```

**`Category`**:

```swift
@Model
final class Category {

    var uuid: UUID = UUID()          // .unique removed
    var name: String = ""
    var nameKey: String?
    var nameCustom: String?
    var kindRaw: String = "expense"
    var icon: String?
    var order: Int = 0
    var isPrimary: Bool = true

    /// Explicit inverse of Transaction.category. .nullify: deleting a
    /// Category detaches its transactions (legal now that the far side is
    /// optional). CategoriesSourcesView keeps its "block delete while in
    /// use" UX on top — and can now answer "in use?" from this collection
    /// instead of scanning the table.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    /// Explicit inverse of TransactionSplit.category. Same rule and same
    /// UI guard: "in use" must now mean transactions OR splits.
    @Relationship(deleteRule: .nullify, inverse: \TransactionSplit.category)
    var splits: [TransactionSplit]?
}
```

**`Source`**:

```swift
@Model
final class Source {

    var uuid: UUID = UUID()          // .unique removed
    var name: String = ""
    var note: String?
    var isActive: Bool = true

    /// Explicit inverse of Transaction.source. This line is the actual fix
    /// for the dangling-Source crash: with an inverse, .nullify is enforced
    /// by the store at delete time.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.source)
    var transactions: [Transaction]?
}
```

**`MerchantCategoryLearning`** — declaration unchanged, **container placement
changes** (next section).

### 1.3 `MerchantCategoryLearning` stays local-only (and keeps its `.unique`)

Its doc comment is a privacy promise: "NEVER leaves the device. No analytics,
no sync, no export." Putting it in a CloudKit-synced store breaks that
promise. The fix is a second, non-synced `ModelConfiguration`:

```swift
// SharedModelContainer — next release shape
static let syncedSchema = Schema([Transaction.self, Category.self,
                                  Source.self, TransactionSplit.self])
static let localSchema  = Schema([MerchantCategoryLearning.self])

// Vela.sqlite       → cloudKitDatabase: .private("iCloud.com.dmitrylogachev.budgetcrab")  [app process only]
// VelaLocal.sqlite  → cloudKitDatabase: .none
let container = try ModelContainer(for: fullSchema,
                                   configurations: [syncedConfig, localConfig])
```

Two consequences, both fine:
- Because the local config never syncs, `@Attribute(.unique)` on
  `merchantNormalized` is **allowed to stay** — no upsert-logic rewrite.
- It moves to its own store file. One-time migration: fetch rows from the old
  store, re-insert into the local store (it's a suggestion cache; even losing
  it would only reset personalization, but the copy is cheap).
- No relationship spans the two configurations (`MerchantCategoryLearning`
  stores `categoryName` as a String) — this is what makes the split legal.

**Process rule for later CloudKit enablement:** only the **main app** process
opens the store with CloudKit enabled. Widget and AppIntents processes open
the same `Vela.sqlite` with `cloudKitDatabase: .none` — one sync engine per
store file, ever. (Standard NSPersistentCloudKitContainer guidance; SwiftData
inherits it.)

### 1.4 nil-category presentation contract

Making `category` optional leaks into ~20 files (`tx.category` call sites:
DashboardView, AnalyticsView, CategoryDetailView, DaySpendingSheet,
NetSnapshotBuilder, both export services, PDF export, TransactionsView search,
QuickEntry, edit views, importer). One rule, applied everywhere:

- **Display:** nil → localized `"category.uncategorized"` string, neutral
  color/symbol. Add one shared helper (e.g. `tx.categoryDisplay(bundle:)`)
  so no view invents its own fallback.
- **Aggregation:** nil → a single stable synthetic bucket keyed by a reserved
  UUID (same trick `AnalyticsBreakdownView` already uses for its "Other"
  slice). Never drop the row — dropping makes totals lie.
- **Never force-unwrap, ever.** During sync convergence nil is a *normal*
  transient state, not corruption.

### 1.5 Safe order to apply the Part-1 changes

The schema changes ship as **one** version bump, but the code lands in this
order so every intermediate commit builds and behaves identically:

1. **Call-site hardening first (no schema change).** Introduce the
   nil-category display/aggregation helpers and migrate all `tx.category`
   readers onto them while the property is still non-optional (helpers just
   pass through). Pure refactor; behavior-identical; individually committable.
2. **One schema bump, all of it together** (`SchemaV2` via `VersionedSchema`):
   drop `.unique` ×3, add attribute defaults, make `category` optional, add
   the three inverse collections, add `TransactionSplit` (Part 2), split
   `MerchantCategoryLearning` into the local configuration. One bump — not
   several — because each SwiftData migration of a live store is a risk event;
   staging schema changes across releases multiplies exposure for zero gain.
3. **Custom migration stage, not lightweight.** These changes are
   individually lightweight-migratable, but use
   `MigrationStage.custom(willMigrate:)` anyway for one job: **repair existing
   dangling `Source` references before the inverse starts enforcing
   integrity.** Stores in the field may already contain the landmine
   (transactions whose source row was deleted pre-fix); walk transactions,
   nil out any unresolvable `source`, then migrate. Also do the
   `MerchantCategoryLearning` copy here.
4. **Uniqueness responsibility moves to write sites.** With `.unique` gone,
   the only inserters of Transactions/Categories/Sources by external identity
   are the CSV importer and the seeders — the importer already does
   fetch-by-uuid-then-skip, and `SeedService` is idempotent by nameKey. Audit
   both, add a unit test asserting a double-import of our own export stays
   row-stable.
5. **CloudKit itself stays OFF in 1.0.3** (`cloudKitDatabase: .none`
   unchanged). 1.0.3 ships the CloudKit-*shaped* schema and the split feature;
   the sync flip (container ID, entitlements, schema initialization in the
   CloudKit dev environment, the app-only sync-engine rule from §1.3) is the
   1.0.4 change. This decouples "did the migration break anyone" from "did
   sync break anyone" — never debug both at once.

---

## 2. Split-transaction model

### 2.1 The schema

One purchase = one `Transaction` + N child `TransactionSplit` rows. Never N
transactions (ledger-simplicity rule: the ledger, search, counts, dedup, and
the StoreKit review counter all keep seeing one purchase).

```swift
@Model
final class TransactionSplit {

    /// Stable external id (export/import, sync debugging). Not .unique.
    var uuid: UUID = UUID()

    /// Portion of the parent's amountCents attributed to `category`.
    /// Same Int-cents rule as everywhere; > 0 by UI validation.
    var amountCents: Int = 0

    /// Optional label ("book", "HDMI cable"). Purely descriptive.
    var note: String?

    /// Stable display order within the purchase.
    var order: Int = 0

    /// Inverse declared on Transaction.splits (cascade lives there).
    /// nil = orphan (parent record not yet synced, or parent deleted
    /// mid-flight) — orphans are INVISIBLE to aggregation, see §2.3.
    var parent: Transaction?

    /// Inverse declared on Category.splits (.nullify there).
    /// nil = category deleted or not yet synced → attribution falls back
    /// to the parent's own category, see §2.3.
    var category: Category?

    var createdAt: Date = Date()
}
```

CloudKit checklist: every attribute optional or defaulted ✅ · both
relationships optional with explicit inverses ✅ · no `.unique` ✅ · parent →
children is `.cascade` (declared on `Transaction.splits`) ✅.

`TransactionSplit` joins the **synced** schema and therefore the shared
`Schema` list used by app, widget, and AppIntents — all three processes open
the same store file, and a schema mismatch means the store won't open. This
is a single edit because the schema is defined once in
`SharedModelContainer`, but it's a shipping gate: verify all targets compile
the new model file.

### 2.2 The invariant: remainder model, parent total is authoritative

**Decision: `Σ splits ≤ parent.amountCents`, and the unassigned remainder
(`parent.amountCents − Σ splits`) is implicitly attributed to the parent's own
`category`. We do NOT require exact equality.**

Why remainder, not exact-sum:

1. **CloudKit makes exact-sum unenforceable.** Splits and their parent are
   separate CKRecords arriving asynchronously. On a syncing device there
   *will* be windows where only 2 of 3 splits have landed. An exact-sum
   invariant is violated by the transport itself; a remainder model degrades
   gracefully — money not yet covered by an arrived split simply sits in the
   parent's category, and the **grand total never moves**, because the grand
   total is always `parent.amountCents` regardless of split arrival.
2. **Migration-safety falls out for free.** A transaction with zero splits is
   just "remainder = 100%", which is byte-for-byte today's behavior. No data
   migration, no special-casing "legacy" rows.
3. **UX honesty.** The real use case is "split out the two odd items from the
   Amazon order" — forcing the user to categorize every last cent before
   saving is a form-validation fight. The parent's category is the natural
   home for "the rest of the order".
4. The parent stays authoritative for **amount, date, type, currency,
   merchant, source, recurrence** — a split carries only (amount, category,
   note, order). Splits of an income transaction are allowed by the schema
   but out of UI scope for 1.0.3 (expense-only entry point).

**Enforcement:** the editor validates `Σ splits ≤ parent total` and every
`split.amountCents > 0` at save time. Aggregation must still tolerate an
over-sum (device A edits the amount down while device B adds a split — both
valid at commit time, merged state oversums until someone re-opens the
editor):

> **Over-sum rule:** splits are counted as stated; remainder is
> `max(0, total − Σ splits)`. Transiently, category totals may exceed the
> grand total by the over-sum. This is the honest choice: silently scaling
> splits down would show numbers the user never typed. The editor surfaces
> the discrepancy for a one-tap fix on next open.

### 2.3 The canonical decomposition — the ONE function every category number flows through

This is the load-bearing design element. Do **not** let each view implement
its own split handling — that is exactly how the numbers silently lie.
Pattern-match `SafeToSpend.Entry`: one pure, SwiftData-free, unit-testable
function.

```swift
/// Shared/CategoryAttribution.swift  (new)
enum CategoryAttribution {

    /// One category-attributed piece of one purchase.
    struct Row: Equatable, Sendable {
        let amountCents: Int      // > 0
        let categoryUUID: UUID?   // nil = uncategorized bucket
        let date: Date            // parent's date, always
        let isIncome: Bool        // parent's direction, always
    }

    /// The single source of truth for "which categories does this
    /// transaction's money belong to".
    ///
    /// - no splits            → [ (total, parent.category) ]   ← today's behavior, exactly
    /// - splits               → one Row per split (split.category,
    ///                          falling back to parent.category when the
    ///                          split's category is nil — deleted or
    ///                          not-yet-synced), plus a remainder Row
    ///                          (max(0, total − Σsplits), parent.category)
    ///                          when the remainder is > 0
    /// - orphan splits        → never seen: rows() is derived FROM the
    ///                          parent, so a split with parent == nil is
    ///                          invisible until its parent record arrives.
    static func rows(for tx: Transaction) -> [Row]
}
```

Properties that make the invariant checkable in one unit test:
`Σ rows(for: tx).amountCents == max(tx.amountCents, Σ splits)` — equal to
`tx.amountCents` whenever the editor's invariant holds.

**The two-sided contract:**

- Every **category-dimension** aggregation consumes `rows(for:)`.
- Every **category-blind** aggregation (totals, safe-to-spend, pace,
  time-series) keeps reading `tx.amountCents` and must **never** be "helpfully"
  switched to split rows — summing parents *and* splits double-counts every
  split purchase. This is the #1 silent-lie risk in the whole feature; it gets
  a regression test (seed → split some transactions → assert grand totals
  unchanged, category totals moved by exactly the split amounts, per the
  feature-pack brief's own warning).

### 2.4 Full inventory of aggregation paths

#### A. Category-dimension — MUST change to `CategoryAttribution.rows(for:)`

| # | Path | Today | Change |
|---|------|-------|--------|
| A1 | **Analytics donut** — `AnalyticsView.recomputeBreakdown` (AnalyticsView.swift:268), feeding `AnalyticsBreakdownView.CategoryTotal` | sums `tx.amountCents` into `sums[tx.category.uuid]` | iterate `rows(for: tx)` inside the same month window; accumulate per `row.categoryUUID`; nil bucket per §1.4. Name/symbol/color resolve from the row's category. Donut "Other"-capping logic downstream is untouched. |
| A2 | **Dashboard donut** — `DashboardView` `CategorySpend` build (~line 185) | groups `tx.category` over `currentMonthTransactions` expenses | same substitution. The donut's own center total (`dashboard.total_spent`) must equal Σ slices — it will, because Σ rows = tx total when the invariant holds. |
| A3 | **Widget top-3 categories** — `NetSnapshotBuilder.build` (line 69, `Dictionary(grouping:) { $0.category.uuid }`) | per-category month sums for the mini bars | same substitution; runs at snapshot-build time in the app process, so no extension-side logic changes. `fraction` stays `categoryCents / expenseCents` where `expenseCents` remains the **parent-summed** total (B-side). |
| A4 | **Category drill-down** — `CategoryDetailView` (`filtered` at :32, total at :44) | `tx.category.uuid == categoryUUID`, total = Σ `tx.amountCents` | membership: a purchase belongs to category C if **any** row of `rows(for:)` attributes to C. Header total: Σ of only the C-attributed row amounts — NOT `tx.amountCents` (this is the subtlest lie: a $120 Amazon order with $18 attributed to Health must add $18 to Health's total, while the row list still shows the $120 purchase, badged "split"). |
| A5 | **Day sheet category bars** — `DaySpendingSheet.categorySlices` (:57) | groups `tx.category` per day | same substitution; the day-net figure (:43, `signedAmountCents`) is B-side and stays parent-based. |
| A6 | **Category limits** — 1.0.3 feature-pack Item 3, not yet built | n/a | **build it on `rows(for:)` from day one.** Limit progress for C = Σ C-attributed row amounts in the month. Also the warn-when-nearing alert recompute. Specified now so it's never implemented against `tx.category` and then "fixed". |
| A7 | **Transactions search** — `TransactionsView` (:343 matches `tx.category.displayName()`) | parent category name only | append split categories' display names (and split notes) to the searched fields, else "show my Health spending" misses every split. |
| A8 | **CSV / TSV export** — one `category` column per row (`CSVExportService.swift:23,53`) | parent category string | keep the row exactly as-is (parent category + full amount → old consumers see no change), append one **new trailing optional column** `splits`, encoded `amount:category;amount:category`. RFC-4180 escaping as usual. **The importer must learn to read it in the same release** — otherwise our own export→import round trip silently drops splits, which breaks the existing idempotent-reimport guarantee. Foreign CSVs without the column: unchanged path. |
| A9 | **PDF export** — per-row category name (`PDFExportService.swift:215`) | parent name | show parent name + a "split" marker; optionally footnote the breakdown. Report-level category totals (if/when the PDF grows them) must come from `rows(for:)`. |
| A10 | **Recurrence materialization** — `RecurrenceService` (:81–93 clones `template.category`) | copies category only | deep-copy the template's splits onto each materialized instance (new `TransactionSplit` rows, new uuids, same amounts/categories). A split recurring purchase that materializes without its splits mis-categorizes silently every month. |
| A11 | **Category delete guard** — `CategoriesSourcesView` "in use" check | scans transactions | "in use" = referenced by any transaction **or any split**; with the new inverses this is `!category.transactions.isEmptyOrNil || !category.splits.isEmptyOrNil`. |
| A12 | **Merchant learning** — `MerchantCategoryLearning` writes on save | learns the picked category | learn the **parent** category only; a split purchase teaches nothing extra (a mixed Amazon basket is noise, not signal). |

#### B. Category-blind — MUST NOT change (double-count tripwires)

| Path | Why it stays parent-based |
|---|---|
| `SafeToSpend.aggregate` + `entries(from:)` + `LedgerAggregator` | spent-this-month and prior-history are direction+amount only. Adding split rows here double-counts. Guard with a doc comment on `entries(from:)`: "parent transactions only — see CategoryAttribution". |
| `DashboardView.expenseCents / incomeCents` (:128/:132) | month totals. |
| `ProactiveAlertRefresher / Policy / Scheduler`, `PaceMetric` | consume SafeToSpend; unchanged transitively. |
| `AnalyticsView.recomputePulse` / `recomputeHorizon` | time-dimension series, no category axis. |
| Widget `incomeCents` / `expenseCents` / ring / hero (`NetSnapshotBuilder`) | totals; only the top-3 list (A3) changes. |
| `totalTransactionCount`, StoreKit review save counter, free-tier counts | splits are not transactions; one purchase stays one row everywhere. |
| Import content-dedup & `DuplicateReviewService` | matches on parent-level content (amount/type/merchant); splits don't participate. |

### 2.5 Back-compat & behavior guarantee

- A transaction with `splits == nil || splits.isEmpty` produces exactly one
  attribution row identical to today's `(amountCents, category)` — every A-path
  is a strict generalization, so pre-split stores and non-splitting users see
  **zero behavioral change**. No data migration for existing rows.
- The `splits` table starts empty; V2 migration creates it and touches no
  transaction data.
- Old app versions after a future sync (1.0.4+) would see parent transactions
  but not know about splits → they'd show parent-category numbers. Acceptable:
  by the time sync ships, 1.0.3 is the floor version; note it in the 1.0.4
  release gate anyway.

### 2.6 Editor & product surface (scope fence for 1.0.3)

Model-level design only, but the fence matters: split editing lives in the
existing transaction editor (an optional "Split this purchase" disclosure),
expense-only, validated per §2.2. QuickEntry does not grow split syntax.
Whether splitting is Premium-gated is a monetization call — **not decided
here**; the schema is gate-agnostic (the gate, if any, belongs in
`AppCapability` like everything else).

---

## 3. Test plan (the ones that catch the lies)

1. **Conservation test** (unit, pure): random ledgers, random splits →
   `Σ rows == parent total` under the invariant; over-sum rule holds.
2. **Before/after totals test** (SwiftData, on-disk per the container-lifetime
   memory): seed → snapshot dashboard totals, donut slices, safe-to-spend →
   split several transactions **without changing amounts** → grand totals and
   safe-to-spend byte-identical; only category distribution moved, by exactly
   the split amounts. This is the brief's own acceptance criterion.
3. **Double-count canary**: one 3-way split transaction; assert
   `expenseCents == amountCents` (not ×2), donut Σ == center total.
4. **Dangling-source repair**: craft a store with a dangling source ref,
   run V2 migration, assert clean open + nil source.
5. **Export round-trip**: export with splits → import into fresh store →
   splits intact; import same file again → row-stable (uuid dedup without
   `.unique`).
6. **Category-delete with splits**: delete a category referenced only by a
   split (guard bypassed in test) → split.category nil → attribution falls
   back to parent category; no crash, totals conserved.
7. Existing suites: locale baseline (new keys: `category.uncategorized`,
   split editor strings), and the UI suites keep their
   `--suppress-rating-prompt` seam.

---

## 4. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Double-counting** if any B-path is switched to split rows (or an A-path sums both parent and splits) | High — silent wrong money numbers | single choke-point function (§2.3), canary test #3, doc-comment tripwires on `SafeToSpend.entries` |
| **`tx.category` optionality fallout** across ~20 files; a missed force-unwrap is a sync-time crash | High | step-1 refactor lands helpers *before* the schema flips; grep-gate: no `category!` anywhere |
| **SwiftData migration of a live store** (optionality + inverses + new entity in one bump) | High | explicit `VersionedSchema` + custom stage, rehearsed on copies of real device stores (per the on-disk-repro convention); 1.0.3 ships migration *without* sync so failures are isolated |
| Dangling `Source` refs already in the field crash *during* migration when inverses materialize | Medium | willMigrate repair pass (§1.5.3) runs before enforcement |
| `.unique` removal weakens identity — re-import or future sync-merge duplicates | Medium | write-site uniqueness audit + test #5; CloudKit itself maps one model instance to one CKRecord, so sync does not mint uuid duplicates |
| CategoryDetailView "attributed amount ≠ row amount" confuses users ($120 row in an $18 total) | Medium | explicit "split" badge + per-row attributed amount in the C-scoped list; this is a UX spec item, not optional polish |
| Widget/AppIntents schema drift (three processes, one store) | Medium | schema defined once in `SharedModelContainer`; release gate: launch app + widget + AppIntent against a migrated store |
| Export round-trip loses splits if importer lags the exporter | Medium | A8 pairs them in the same release |
| Recurring templates materialize without splits | Low-Medium | A10 + a recurrence test |
| Over-sum transient (two-device edit race, post-sync) shows category Σ > grand total | Low (1.0.3: impossible; 1.0.4+: transient) | §2.2 over-sum rule + editor surfacing; revisit in the 1.0.4 sync design |
| `MerchantCategoryLearning` privacy promise vs sync | Low (if §1.3 followed) | local-only `ModelConfiguration`; it keeps `.unique` legally |

---

## 5. Deliverable summary / apply order (for the implementation pass)

1. `CategoryAttribution.rows(for:)` + nil-category helpers; migrate A1–A5, A7,
   A11–A12 call sites while behavior is still identical. Tests #1–#3 written
   here (TDD: they pass trivially pre-split, keep passing after).
2. Schema V2 in one bump: audit fixes (§1.2) + `TransactionSplit` (§2.1) +
   local config for learning (§1.3) + custom migration stage (§1.5.3).
3. Split editor UI + A4 drill-down UX + A8/A9 export changes + A10 recurrence
   deep-copy.
4. Category-limits feature (feature-pack Item 3) built on `rows(for:)` (A6).
5. 1.0.4, separate release: flip `cloudKitDatabase` in the app process only,
   CloudKit dev-environment schema init, sync QA.

---

# EXTENSION (accepted-design round 2) — limits×splits, the migration stage, and the canary plan

Sections 6–8 added after the Part 1/Part 2 design was accepted. Same rule:
design only. Explicitly out of scope here (Sonnet's items): the daily-allowance
number (Item 2), the feedback mail composer (Item 5), and all pure-UI work.

---

## 6. Category limits × splits (feature-pack Item 3, made split-correct from day one)

### 6.1 Model addition

One field, CloudKit-shaped, on the already-corrected `Category`:

```swift
    /// Optional monthly spend limit for this category, in cents.
    /// nil = no limit (the default for every existing and new category).
    /// Meaningful only for expense categories; the UI never offers it on
    /// income categories and the policy ignores it there.
    var limitCents: Int?
```

Optional → no default needed, no migration impact, CloudKit-legal. It rides
the same V2 schema bump as everything else in §1.5 (one bump, not two).

### 6.2 The threshold — one symbol, nowhere else

```swift
/// Shared/CategoryLimitPolicy.swift  (new, pure)
enum CategoryLimitPolicy {

    /// Warn when spend crosses this fraction of the limit, from below.
    /// ~70% is a TUNABLE STARTING GUESS, not a research finding (feature-pack
    /// Item 3) — which is exactly why it lives here and only here. Every
    /// consumer (policy, tests, any future UI progress hint) reads this
    /// symbol. Changing the guess is a one-line diff.
    static let warnThresholdFraction: Double = 0.70

    /// The one comparison, in one place (same discipline as
    /// SafeToSpend.remainingCents). Warn iff:
    ///   spent ≥ ceil(threshold × limit)   AND   spent < limit
    /// The second clause is the gain-framing guard: at/over the limit there
    /// is no honest gain-framed sentence, so we say nothing (mirrors
    /// ProactiveAlertPolicy guard 4 exactly).
    static func shouldWarn(spentCents: Int, limitCents: Int) -> Bool {
        guard limitCents > 0 else { return false }
        let threshold = Int((Double(limitCents) * warnThresholdFraction).rounded(.up))
        return spentCents >= threshold && spentCents < limitCents
    }
}
```

Single-sourcing is verified by a test (§6.5), not by convention.

### 6.3 "Spent so far" — the exact computation

**Rule: a category's month-to-date spend is the sum of its
`CategoryAttribution.rows(for:)` attributions — never `tx.amountCents` of
transactions whose parent category matches.** This is path **A6** from the
§2.4 table, now specified precisely. It uses the *identical* month window as
`SafeToSpend.aggregate` (same `monthStart`, same `day <= today`
future-dated-exclusion, same calendar) so the limit alert can never disagree
with the dashboard about what "this month" means.

```swift
/// Pure, SwiftData-free, unit-testable — same pattern as SafeToSpend.
/// Input rows are CategoryAttribution.Row (they already carry the PARENT's
/// date and direction, per §2.3).
static func spentByCategory(
    rows: [CategoryAttribution.Row],   // pre-flattened from month transactions
    monthStart: Date, today: Date, calendar: Calendar
) -> [UUID: Int] {
    var spent: [UUID: Int] = [:]
    for row in rows where !row.isIncome {
        let day = calendar.startOfDay(for: row.date)
        guard day >= monthStart, day <= today else { continue }
        guard let cat = row.categoryUUID else { continue }  // nil bucket can't have a limit
        spent[cat, default: 0] += row.amountCents
    }
    return spent
}
```

Double-count proof, stated as an invariant the tests pin (§6.5, §8):
`spentThisMonthCents` (the B-path total) keeps summing **parent**
`amountCents`; this map sums **rows**. When the §2.2 invariant holds,
`Σ spentByCategory.values + nilBucket == spentThisMonthCents` — the same money
partitioned two ways, counted once each way.

### 6.4 Where it plugs into the proactive-alert pipeline

The existing architecture is: coalesced `didSave`/foreground trigger →
`LedgerAggregator` (off-main fetch + arithmetic, Sendable value out) →
`ProactiveAlertRefresher.apply` (main-actor join) → `ProactiveAlertPolicy.plan`
(pure) → `ProactiveAlertScheduler` (one stable identifier,
`budgetcrab.proactive.weekly`, replace-don't-stack). Each piece changes as
follows — no new pipeline, no second notification stream:

1. **`LedgerAggregator.safeToSpendAggregate(now:)`** → generalizes to
   `monthlyAggregate(now:)`, same single full-table pass, returning the
   extended Sendable value:

   ```swift
   struct Aggregate: Equatable, Sendable {
       let spentThisMonthCents: Int          // unchanged (parent-summed)
       let priorExpenseCents: Int            // unchanged
       let priorSpanDays: Int                // unchanged
       /// Only categories with limitCents != nil — tiny.
       let limitStatuses: [CategoryLimitStatus]
   }
   struct CategoryLimitStatus: Equatable, Sendable {
       let categoryUUID: UUID
       let displayName: String   // resolved on the actor; plain String crosses
       let limitCents: Int
       let spentCents: Int       // from spentByCategory — split-attributed
   }
   ```

   The per-category map is computed in the *same* loop pass that feeds
   `SafeToSpend.aggregate` (one fetch, one iteration — respects the measured
   hot-path budget; the extra work is a dictionary add per row). Nothing but
   value types crosses the actor boundary, as today.

2. **`ProactiveAlertRefresher.apply`** — passes `aggregate.limitStatuses`
   through to the policy, plus the once-per-month latch (below), read from the
   already-injected `defaults`.

3. **`ProactiveAlertPolicy.plan`** — gains one parameter and one `Body` case:

   ```swift
   enum Body { case safeToSpend(amountCents: Int)
               case pace(amountCents: Int)
               case categoryLimit(categoryName: String, remainingCents: Int) }
   ```

   Selection rule, applied AFTER the five existing nil-guards (which all stay):
   among `limitStatuses` where `CategoryLimitPolicy.shouldWarn(spent, limit)`
   **and** the latch has not fired for that category this month, pick the one
   with the highest `spent/limit` fraction (closest to its limit = most
   urgent). If one exists → `Body.categoryLimit(name, limit − spent)`,
   gain-framed: "{amount} left in {category} this month". Otherwise the
   existing pace/safeToSpend selection runs unchanged.
   **Precedence: categoryLimit > pace > safeToSpend** — a specific actionable
   warning beats a general status line, and there is only ever ONE pending
   notification (see 5).
   Guard mirror: `remaining ≤ 0` ⇒ that category says nothing (no
   loss-framing, ever) — enforced inside `shouldWarn`, not at call sites.

4. **"Fires once, when crossing from below" — the latch.** Notification
   timing stays the user's chosen weekday/hour/minute (anti-nagging: we
   reuse the reminder slot the user already consented to; no new
   fire-on-save notification). Staleness is already solved by this pipeline's
   own argument: the number only changes on a write, and every write
   re-plans. "Once" is enforced by a per-category-per-month latch in
   UserDefaults, keyed `"limitWarned.<categoryUUID>.<yyyy-MM>"`:
   - The policy *selects* only unlatched categories.
   - The latch is **set when the notification actually fires**, not when
     planned (a re-plan before the fire date must not burn the latch). The
     scheduler can't observe delivery for a local notification, so the
     refresher latches at the first recompute where `now >= plannedFireDate`
     of a previously-planned categoryLimit body — same frozen-body
     re-plan machinery that already exists, one extra comparison.
   - Month key auto-expires the latch on rollover; stale keys are pruned on
     each pass (bounded: ≤ one key per limited category per month).

5. **`ProactiveAlertScheduler`** — one new `body(for:)` case, same single
   identifier. Deliberate: keeping one identifier preserves the
   replace-not-stack property and the AppIntents rule from 1.0.2
   (out-of-process code CANCELS this identifier, never reschedules — that
   contract is unchanged and must keep covering the new body).

Entitlement: the whole pipeline already re-checks
`AccessManager.isAllowed(.proactiveAlerts)` per pass; the limit alert
inherits it. Whether *setting* a limit is itself gated is a monetization
call — not decided here; if gated, it's an `AppCapability` case like
everything else.

### 6.5 Tests for this section (named)

- `CategoryLimitPolicyTests.test_shouldWarn_firesAtThresholdFromBelow_only`
  — table-driven around `ceil(0.70 × limit)` boundary: threshold−1¢ false,
  threshold true, limit−1¢ true, limit false, over false.
- `CategoryLimitPolicyTests.test_thresholdConstant_isSingleSourced` — asserts
  `shouldWarn` behavior *changes* when the test recomputes expectations from
  `CategoryLimitPolicy.warnThresholdFraction` rather than a literal (i.e. all
  expectations derive from the symbol), plus a repo grep-gate in review: the
  fraction literal appears exactly once outside tests.
- `CategoryLimitSpendTests.test_spentByCategory_readsSplitAttributions` — a
  3-way-split transaction contributes its split amounts to the splits'
  categories and its remainder to the parent's; parent's `amountCents`
  appears in NO single category.
- `CategoryLimitSpendTests.test_partitionInvariant_categorySumsEqualMonthTotal`
  — `Σ spentByCategory + nilBucket == SafeToSpend.aggregate.spentThisMonthCents`
  on a no-over-sum ledger (the §6.3 double-count proof, executable).
- `ProactiveAlertPolicyTests.test_plan_categoryLimitBeatsPace_andLatchSuppressesRepeat`
  — same ledger, two passes: first plan is `.categoryLimit`, latch set, second
  plan falls through to pace/safeToSpend.
- `ProactiveAlertPolicyTests.test_plan_overLimitCategory_saysNothing` — spent
  ≥ limit ⇒ body is never `.categoryLimit` for that category.
- Window-consistency: `test_spentByCategory_usesSameMonthWindowAsSafeToSpend`
  — a future-dated and a last-month expense affect both computations
  identically (both excluded / both prior).

---

## 7. The V1→V2 migration stage, concretely

Highest-risk code in the 1.0.4 foundation; it runs unattended on every real
user's store. Design goals in order: **never lose user data · healthy store =
provable no-op · idempotent · rehearsed on genuinely-damaged fixtures**.

### 7.1 Structure

```swift
enum FinanceTrackerSchemaV1: VersionedSchema { /* today's shapes, verbatim */ }
enum FinanceTrackerSchemaV2: VersionedSchema { /* §1.2 + §2.1 shapes */ }

enum FinanceTrackerMigrationPlan: SchemaMigrationPlan {
    static let stages = [
        MigrationStage.custom(
            fromVersion: FinanceTrackerSchemaV1.self,
            toVersion:   FinanceTrackerSchemaV2.self,
            willMigrate: exfiltrateMerchantLearning,   // V1 context
            didMigrate:  repairDanglingReferences       // V2 context
        )
    ]
}
```

**Why repair lives in `didMigrate`, not `willMigrate` — the ordering
argument, explicitly:**

1. `willMigrate` runs against the store opened under **V1**, where
   `Transaction.category` is still **non-optional** — `tx.category = nil`
   does not even compile there. Category repair is only expressible under V2.
2. The schema transformation between the closures is a Core Data
   *table-level* mapping: it copies rows and columns, never traverses
   relationships, never fires faults — dangling foreign keys pass through it
   untouched and harmlessly.
3. Inverse/delete-rule enforcement is not a standing constraint — it fires
   only when a related object is **deleted** (or a save propagates a change).
   The repair pass deletes nothing and touches only the dangling side, so
   enforcement cannot fire mid-repair by construction. There is no window
   where "the inverse starts enforcing" against still-broken data, because
   enforcement is event-driven and we generate no triggering events until the
   single final save — at which point every reference we wrote is nil, the
   one state that can never dangle.

### 7.2 `willMigrate` — exfiltrate `MerchantCategoryLearning` (V1 context)

The V2 synced schema no longer contains this entity (§1.3): after the
transform its table is unreachable via SwiftData. So its rows must leave
*before* the transform, via a sidecar file (not a cross-container write inside
a migration closure — keep the closure's blast radius at zero):

1. Fetch all `MerchantCategoryLearning` rows (the entity has no
   relationships — nothing can fault).
2. Serialize to plain `Codable` structs → single **atomic** JSON write to the
   App Group: `merchant-learning-handoff.json`.
3. Zero rows → write nothing. **Never call `save()`** — this closure performs
   no store mutation at all.
4. First app launch after migration (`FinanceTrackerApp.init`, after the
   container is up): if the handoff file exists, upsert rows into the new
   local store (`.unique` on `merchantNormalized` is legal there and makes
   the upsert idempotent), save, **then** delete the file. Crash between save
   and delete → next launch re-upserts the same rows onto themselves. Losing
   the file entirely degrades to "suggestion personalization resets" — a
   cache, not user data.

### 7.3 `didMigrate` — the repair algorithm (V2 context)

```
repairDanglingReferences(context):
 1. sourceIDs   ← Set(fetch(Source).map(\.persistentModelID))
    categoryIDs ← Set(fetch(Category).map(\.persistentModelID))
 2. repaired ← 0
 3. for tx in fetch(Transaction):                        // batched enumeration
      a. if let sid = tx.source?.persistentModelID,      // fault NOT fired: reading a
            !sourceIDs.contains(sid) {                   // to-one returns a fault object;
             tx.source = nil; repaired += 1              // its ID is read without firing.
        }                                                // Assignment to nil is a pure FK
      b. if let cid = tx.category?.persistentModelID,    // update — the missing destination
            !categoryIDs.contains(cid) {                 // row is never materialized.
             tx.category = nil; repaired += 1            // → renders "Uncategorized" (§1.4)
        }
 4. // TransactionSplit table was created empty by this very migration —
    // nothing to repair there, by construction.
 5. if repaired == 0: return                             // NO save() → healthy store is
                                                         // byte-identical; pure read pass
 6. else: context.save()                                 // exactly one transaction —
                                                         // all-or-nothing on interruption
 7. PersistenceLog: the count only. Never identifiers, never amounts.
```

Explicit decisions inside that algorithm:

- **Orphaned transaction ⇒ REPAIR (nullify), never delete.** A transaction
  with a dangling source/category is a fully intact money record — amount,
  date, type, merchant, note are all correct; only a decoration pointer
  broke, and it broke because of *our* unenforced-`.nullify` bug. Deleting a
  user's financial record to restore our referential integrity is
  indefensible on a finance app. Nullify is also exactly the end-state the
  declared `.nullify` rule would have produced had it been enforced — the
  repair completes the delete that half-happened, nothing more. The nil
  category then flows through the §1.4 "Uncategorized" contract, which
  exists precisely for this.
- **`updatedAt` is NOT bumped** by the repair. The user didn't edit
  anything; a repair that stamps thousands of rows as "modified today" would
  pollute any future sync/merge heuristics and the UI's own recency signals.
- **No-op proof on healthy stores:** steps 1–3 are reads; step 5 skips
  `save()` when nothing was repaired. No mutation, no WAL growth beyond the
  reads, no timestamps touched. This is assertable in a test (7.5).
- **Idempotent:** a second run finds every reference either valid or already
  nil — `repaired == 0` → no-op path.
- **Interruption-safe:** the only write is one `save()`; Core Data makes it
  atomic. Killed before it → V2 store with the damage still present → the
  repair must therefore also be safe to re-run *outside* the migration:
  wrap the same function as an app-init integrity pass guarded by a
  UserDefaults flag (`v2ReferenceRepairDone`), set only after a successful
  save/no-op. Belt and braces for the one crash window.

### 7.4 The fault-safety assumption, named and hedged

Step 3 rests on one Core Data contract: **reading a fault's object ID does
not fire the fault** (only attribute access materializes the destination
row). SwiftData is a wrapper over exactly this machinery and
`persistentModelID` maps to `NSManagedObject.objectID`, but this assumption
is load-bearing and gets a **rehearsal gate, not trust**:

- Fixture: create the damage the way production did — under the **V1**
  schema (no inverse = the bug itself), insert `tx + source`, delete the
  `Source`, save. The unenforced `.nullify` leaves the dangling ref. That is
  a genuine field-identical damaged store, produced by the bug, not by SQL
  surgery.
- Run the full migration on a copy. If `persistentModelID` turns out to fire
  the fault under some SwiftData version (crash in rehearsal, not in the
  field), the documented fallback is a pre-flight raw-SQLite pass before the
  container ever opens (`UPDATE ZTRANSACTION SET ZSOURCE = NULL WHERE
  ZSOURCE NOT IN (SELECT Z_PK FROM ZSOURCE)` after a WAL checkpoint) — uglier
  and more invasive, which is why it is the fallback and why the rehearsal
  runs first.
- **Backup hatch:** before the stage runs, copy `Vela.sqlite` + `-wal` +
  `-shm` to `Vela.pre-v2.bak/` inside the App Group (a 12k-row store is a few
  MB). Deleted after the first fully-successful post-migration launch. On a
  finance app, turning "migration catastrophically failed" into "restore the
  sidecar and ship a fix" is worth megabytes for one release.

### 7.5 Migration tests (named)

- `MigrationRepairTests.test_dirtyStore_danglingSource_isNullified_dataIntact`
  — field-identical fixture (7.4); post-migration: `tx.source == nil`, every
  other field byte-equal, row counts unchanged.
- `MigrationRepairTests.test_dirtyStore_danglingCategory_becomesUncategorized`
  — same for category; transaction visible in ledger under the nil bucket.
- `MigrationRepairTests.test_cleanStore_isNoOp` — healthy V1 store; assert
  post-migration `updatedAt` values all unchanged and the repair reported
  zero (no-save path taken).
- `MigrationRepairTests.test_repair_isIdempotent` — run the repair function
  twice; second pass repairs zero.
- `MigrationRepairTests.test_merchantLearning_survivesToLocalStore` — rows
  present in local store post-handoff; handoff file deleted; double-run of
  the app-init import is row-stable.
- All on **on-disk** stores with the container held in scope (per the
  container-lifetime memory), never in-memory — this bug class only exists
  on disk.

---

## 8. Verification plan for the aggregation split — the canaries

Purpose: each of the seven "must NOT change" paths (§2.4-B) gets a test that
**fails loudly the day someone routes it through split rows**. The design
weapon is one shared fixture plus exact-equality assertions (Int cents — no
tolerances, ever).

### 8.1 The fixture: `SplitMirrorFixture`

Builds **two on-disk stores** (container held in scope, per the test-lifetime
memory) with a deterministic seed:

- **Store A (baseline):** fixed ledger — e.g. 8 transactions across this
  month + prior month, mixed income/expense, hand-picked cents values, fixed
  reference `now`.
- **Store B (mirror):** the *identical* ledger, after which several expense
  transactions receive splits **without any parent field changing**: one
  3-way exact split, one 2-way split, one partial split with remainder.
  (The deliberate **over-sum** case lives in its own targeted fixture, NOT
  in the mirror — its category totals legitimately diverge and would poison
  the equality assertions.)

Every B-path canary asserts `f(A) == f(B)`. Two structural safeguards:

- **Vacuity guard:** one A-path positive assertion per fixture proves the
  mirror really contains splits —
  `test_fixture_isNotVacuous_topCategoriesDiffer`: `NetSnapshotBuilder`
  top-3 items differ between A and B. If a fixture refactor ever stops
  creating splits, this fails first and the green canaries stop being
  meaningless.
- **Tripwire doc-comments** on each production B-path symbol:
  *"Parent transactions only — adding split rows here double-counts.
  Canary: SplitCanaryTests.<name>. See DESIGN_1_0_3_MODELS_FABLE.md §8."*

Two private computations must be extracted to be pinnable (behavior-identical
moves, slotted into apply-order step 1): the dashboard month totals (into a
pure `MonthTotals` helper) and the Pulse/Horizon accumulation loops (into a
pure `AnalyticsSeries` helper). Without extraction their canaries would test
a copy of the formula, which pins nothing.

### 8.2 The seven canaries, with their assertions

**C1 — SafeToSpend + LedgerAggregator**
`SplitCanaryTests.test_safeToSpendAggregate_identical_onSplitMirror`
: `SafeToSpend.aggregate(entries(A), now)` vs `(entries(B), now)` — assert all
three fields equal: `spentThisMonthCents`, `priorExpenseCents`,
`priorSpanDays`.
`test_entries_countEqualsTransactionCount` : `SafeToSpend.entries(from: B).count
== fetchCount(Transaction, B)` — fails the moment someone expands `entries`
per split (the most likely "helpful fix").
`test_ledgerAggregator_matchesPureAggregate_onSplitStore` : the actor's
`monthlyAggregate(now:)` B-side totals == the pure computation on the same
rows — catches a split-join sneaking into the actor's fetch specifically.

**C2 — Dashboard month totals + the cross-check that catches everything**
`test_monthTotals_identical_onSplitMirror` :
`MonthTotals.expenseCents(B) == MonthTotals.expenseCents(A)` and likewise
`incomeCents`; both additionally `==` the fixture's hand-computed literals.
`test_donutSliceSum_equalsMonthExpenseTotal` : Σ of the A-path donut slices
(split-aware, store B) `== MonthTotals.expenseCents(B)`. **This is the
strongest single assertion in the plan** — it fails if the A-side
under/over-attributes *or* the B-side double-counts, because it pins the two
sides of the 12/7 split to each other, not to a copy of themselves.

**C3 — Proactive alerts end-to-end + PaceMetric**
`test_alertPlan_identical_onSplitMirror` : run
`ProactiveAlertRefresher.refresh(modelContext:isAllowed:defaults:now:center:)`
(the synchronous test form) against A and B with identical injected defaults
(budget set, alerts enabled, fixed `now`) and a spy `NotificationScheduling`;
assert the two captured `UNNotificationRequest`s have **equal body strings and
equal trigger dates, and exactly one request each**. Body equality is
A-vs-B, never vs. an English literal — the never-assert-process-locale rule.
`test_paceState_identical_onSplitMirror` : `PaceMetric.evaluate` inputs built
from A and B produce equal `State`.

**C4 — Analytics time series (Pulse / Horizon)**
`test_pulseSeries_identical_onSplitMirror` : `AnalyticsSeries.pulse(A)` ==
`AnalyticsSeries.pulse(B)` element-wise (per-day cents arrays), and the
derived `pulseNetCents` equal.
`test_horizonSeries_identical_onSplitMirror` : the 12-month income/expense
pairs equal element-wise across all Horizon modes (a flat-zero series stays
flat-zero — degenerate-domain guard territory stays untouched).

**C5 — Widget snapshot totals/ring/hero**
`test_netSnapshot_totalsRingHero_identical_onSplitMirror` :
`NetSnapshotBuilder.build(transactions:currencyCode:monthlyBudgetCents:locale:)`
with pinned `Locale(identifier: "en_US")` on A vs B — assert equal:
`spentText`, `earnedText`, hero label/amount/subtitle/isAlert, ring
components. (Top-3 items are the A-path and are *expected* to differ — that
expectation IS the vacuity guard above, so C5 and the guard are one paired
test class.)

**C6 — Counts (review prompt, free tier, dashboard count)**
`test_transactionCount_unchangedBySplitting` :
`fetchCount(FetchDescriptor<Transaction>())` A == B == the seeded literal.
`test_splitsAreNotTransactions` : on B, `fetchCount(TransactionSplit) > 0`
while the Transaction count still equals the seed — pins "splits never
inflate anything that counts Transaction" (StoreKit review counter, free-tier
caps, `totalTransactionCount`) transitively, since all of them count the
`Transaction` entity.

**C7 — Import dedup / duplicate review**
`test_contentDedup_identical_onSplitMirror` : import the same foreign CSV
(no id column) whose rows content-match transactions that are split in B —
assert the set of `isPossibleDuplicate` flags raised is identical A vs B
(matcher sees parent content only; splits are invisible to it).
`test_ownExportReimport_rowStable_onSplitStore` : export B (with the §A8
splits column) → re-import into B → Transaction and TransactionSplit
fetchCounts unchanged (uuid-skip still idempotent without `.unique`).

**C0 — the master conservation test** (already §3.1–3.3, restated with its
assertion): on B (no over-sum),
`Σ over all tx of Σ CategoryAttribution.rows(for: tx).amountCents
== Σ tx.amountCents` — the grand-total invariant that everything above is a
projection of.

### 8.3 Discipline

- All seven live in one `SplitCanaryTests` suite so a future diff that
  touches any B-path lights up one recognizable test class, not scattered
  failures.
- The over-sum behavior (§2.2) gets its own targeted tests outside the
  mirror suite: `test_overSum_splitsCountedAsStated_remainderClampedToZero`.
- These are unit/SwiftData tests, not UI tests — no rating-prompt seam
  needed; on-disk containers per the lifetime memory.

---

# EXTENSION (round 3) — the safety belt: backup, rollback, real-store protocol

Decision recorded: **everything (V2 schema + splits + limits + migration)
ships in ONE release, 1.0.3, with the safety belt below.** Scale note: the
store population is currently 8 users; everything here is designed as if it
were 8,000 — a migration bug is indistinguishable at any scale, and the cost
of the belt is identical.

---

## 9. Pre-migration automatic backup + first-launch warning

### 9.1 The structural fact that shapes this section

`SharedModelContainer.shared` is a **lazy static** — the migration runs on
whichever process touches it first with the V2 schema. Three processes touch
this store: the app, the widget, and AppIntents. Two consequences the design
must handle, or the belt never engages:

- **Nothing in the pre-migration UI may touch `SharedModelContainer.shared`.**
  The pre-migration screen and the backup run *before* first touch; the
  screen's view tree must contain no `@Query`, no `.modelContainer(shared)`,
  no service that lazily reaches the container. This is an audit item for
  implementation, stated here as a hard rule.
- **Extensions must never be the process that migrates.** A widget timeline
  refresh at 3 a.m. after the App Store auto-update would otherwise run the
  migration inside an extension's memory limit, with no backup and no UI.
  Gate: a shared App Group UserDefaults flag `v2MigrationComplete`. Widget
  and AppIntents check it before opening the store; if unset, the widget
  renders its placeholder state ("Open Budget Crab") and AppIntents return a
  graceful "open the app to finish updating" failure — they do not open the
  store at all. Safe because the 1.0.3 update replaces all three binaries
  atomically: post-update, every process runs gated code. The flag lives in
  **App Group** defaults (all processes see it), not `.standard`.

### 9.2 The backup, fully specified

- **When:** during the app's launch sequence (9.3 step 3) — after
  migration-pending is detected, **before** the pre-migration screen is shown
  and therefore strictly before any store open in this process (even the
  read-only export open). At this moment no live connection exists in this
  process, and the extension gate (9.1) guarantees none exists in any other.
- **What:** a file-level copy of the raw store triple — `Vela.sqlite`,
  `Vela.sqlite-wal`, `Vela.sqlite-shm` — copying whichever of the three
  exist (WAL/SHM may legitimately be absent). No checkpoint is attempted;
  copying all three preserves a consistent snapshot precisely because no
  connection is open. Alongside them, a small `manifest.json`: source app
  version, ISO date, per-file byte sizes (the §10 restore sanity check).
- **Where:** `<AppGroup>/Backups/pre-v2/` — inside the App Group so the
  restore path (§10) can reach it from the same sandbox, with the same
  `applyProtection` file-protection class as the store itself. It stays
  *included* in device/iCloud device-backup (that is a feature: the safety
  copy rides the user's own backup). Backup files are set read-only after
  the copy — the backup is immutable for its whole life.
- **Idempotence:** if `Backups/pre-v2/` already exists with a manifest, the
  copy is skipped (a previous launch already made it — e.g. user force-quit
  on the warning screen). The backup is made **at most once**, from the
  pristine pre-V2 store, never overwritten by a later (possibly damaged)
  state.
- **Retention — one release:** deleted when V2 is *confirmed good*, defined
  as: `v2MigrationComplete` is set **and** a subsequent launch has opened
  the V2 store successfully (i.e. deletion happens on the **second** good
  launch, giving one full launch of soak). Additionally, 1.0.4's launch
  sweep deletes any straggler `Backups/pre-v2/` unconditionally — the
  one-release cap, so no user carries a stale double of their ledger
  forever.

### 9.3 Launch sequence (exact order)

```
FinanceTrackerApp launch:
 1. migrateLegacyStoreIfNeeded()            // existing sandbox→App-Group copy, unchanged
 2. migrationPending := storeFileExists && !appGroupDefaults.v2MigrationComplete
      // Fresh install: no store file → skip 3–5 entirely, open V2 directly
      // (nothing to migrate, nothing to back up, no screen).
 3. if migrationPending: writeBackupIfAbsent()          // §9.2 — BEFORE any open
 4. if migrationPending: root view = PreMigrationView   // §9.4 — NOT ContentView;
                                                        // SharedModelContainer untouched
 5. On "Export a copy…" → scoped V1 read-only container (§9.4)
    On "Continue" / "Skip" → proceed
 6. V2 store open inside the §10 sentinel (attempt marker → ModelContainer
    init with V2 schema + MigrationPlan → post-open sanity fetch →
    set v2MigrationComplete, clear attempt marker)
 7. ContentView; widgets/AppIntents unblock on the flag; WidgetCenter reload
```

### 9.4 The pre-migration screen

- **Content (tone spec; strings are implementation, 5 locales):** calm and
  gain-framed — "We've improved how your data is stored. As a precaution,
  you can export a copy first." Primary button **"Export a copy…"**,
  secondary **"Continue"** (the skip — plain language, not guilt-framed
  "Skip backup"). No red, no warning triangle: the automatic file backup
  (§9.2) already happened; this screen is the *user-held* copy, not the
  safety mechanism itself.
- **Export reuses the existing services, fed a scoped V1 container.** The
  existing store is still V1-shaped at this point, so the button opens a
  **throwaway `ModelContainer` with the explicit `FinanceTrackerSchemaV1`
  and `allowsSave: false`** — schema matches disk, so this open can never
  trigger a migration, and read-only means it cannot mutate anything. Fetch
  transactions, hand them to the **existing** `CSVExportService` (all-time
  scope) and the existing share sheet, then release the container before
  step 6. No new export code; the premium all-time gate is bypassed for this
  one surface (it is a data-safety flow, not a feature — charging to back up
  your own data before *our* migration would be indefensible).
- **Never blocks a decliner:** "Continue" is always enabled, one tap,
  proceeds immediately to step 6. Export failure (no space, share-sheet
  cancel) also lands back on the screen with "Continue" available — export
  is optional in every path.
- **Shown once or every launch? — Resolution: shown until resolved, which is
  structurally at most a few launches, and never again after migration
  runs.** The screen guards a one-time event that executes the moment the
  user leaves it, so "every launch until acted on" is impossible in the
  steady state — after step 6 succeeds, `v2MigrationComplete` makes step 4
  unreachable forever. The only repeat case is a user who force-quits *on*
  the screen (migration hasn't run; next launch legitimately shows it
  again — correct, since the choice was never made). We do NOT persist a
  "screen was seen" flag separate from the migration itself: a seen-flag
  that outlives an un-run migration is exactly the kind of stuck sticky
  state this codebase has been bitten by before (the `editTx` lesson —
  presentation state whose only reset is the thing it gates).

---

## 10. Rollback / failure path

Non-negotiable restated: **a mid-migration failure leaves working,
exportable data — never a brick, never silent loss.**

### 10.1 What "working state" means in a V2-only binary — stated honestly

The shipped 1.0.3 binary's models are V2 shapes. If migration *permanently*
fails, no code path in that binary can run the full app against a V1 store.
Therefore the failure ladder is: **retry from pristine → restore from backup
and retry → and at the floor, a degraded-but-safe mode: the V1 store intact
on disk, openable read-only for viewing/export (the same §9.4 mechanism),
with a support path.** Data access and export survive every rung; only
full-app functionality depends on the migration eventually succeeding.

### 10.2 Detection — the attempt sentinel

Two App Group defaults keys, written around the V2 open (step 6):

- `migrationAttempt` = `{count, timestamp}` — written **before**
  `ModelContainer` init with the V2 schema.
- `v2MigrationComplete` = true — written **after** container init returned
  *and* a post-open sanity fetch succeeded (`fetchCount(Transaction)` — a
  cheap count-only probe proving the store actually answers queries).
  `migrationAttempt` is then cleared.

On launch, before step 6:

| State | Meaning | Action |
|---|---|---|
| no `migrationAttempt`, no complete-flag | first attempt | proceed |
| `migrationAttempt.count == 1`, no complete-flag | previous attempt died (kill, crash, throw) | **restore from backup (10.3), then retry** — every attempt starts from the pristine V1 copy, so failures cannot compound partial state |
| `migrationAttempt.count >= 2`, no complete-flag | migration fails deterministically on this store | **stop retrying**: restore backup one final time, enter the degraded read-only screen (10.4) |

A thrown error from `ModelContainer` init in step 6 is treated identically
to a dead attempt (same ladder, same restore) — **which requires changing
`SharedModelContainer`'s current `fatalError` on init failure into a
recoverable throw surfaced to the launch sequence.** That change is part of
this design: a `fatalError` in the migration path is the brick we are
forbidding.

### 10.3 The restore algorithm

```
restoreFromBackup():
 1. guard Backups/pre-v2/manifest.json exists else:
      // Unreachable by construction (§9.3: backup is written before any
      // V2 open, and the sentinel only exists after step 6 started).
      // Handled anyway: skip restore, attempt migration on current files —
      // degraded but never worse than doing nothing.
 2. move current Vela.sqlite / -wal / -shm  →  Diagnostics/failed-v2-<attempt>/
      // evidence is MOVED aside, never deleted — a failed store is the only
      // artifact that can explain the failure later
 3. copy Backups/pre-v2/* (minus manifest)  →  store location
      // the backup itself is copied, never moved: it remains in place,
      // immutable, for the next rung of the ladder
 4. verify: restored file sizes == manifest sizes; on mismatch, re-copy once,
    then surface the degraded screen rather than proceed on a bad copy
 5. set restoredFromBackup flag (drives the §10.5 user notice)
```

**Idempotent and safe to run twice, by construction:** the backup is
immutable (read-only, written once, never deleted until confirmed-good —
and *restore never deletes it*, step 3 copies). Running restore twice
produces the same on-disk bytes; step 2's move-aside uses a per-attempt
directory name so a second run cannot collide or destroy the first run's
evidence. There is no state in the restore path that the restore path
itself mutates destructively.

### 10.4 The degraded floor (attempt ≥ 2)

Root view becomes a data-safety screen, not the app: "Your data is safe. We
couldn't finish updating its storage format." Buttons: **Export my data**
(the §9.4 V1 read-only + existing CSV export path — this is why that
mechanism is designed as reusable, not inline in the warning screen) and
**Contact support** (mailto:, pre-filled app version + a `PersistenceLog`
excerpt of the migration error — counts and error codes only, never ledger
contents). The pristine V1 store stays on disk untouched; a 1.0.3.1 fix
release migrates it normally, with the backup still present as its belt.

### 10.5 The user-visible restore notice

Whenever `restoredFromBackup` is set and the app subsequently reaches a
working state (a successful retry): a **full-screen, must-acknowledge
notice** — not a toast, not an alert that can be reflex-dismissed:
"We restored your data from a backup made a moment ago. Everything is here:
{N} transactions." The count comes from the live post-restore store, so the
sentence is verifiable by the user against their own ledger. Localized, 5
locales, gain-framed. The flag clears only on acknowledgement. **No path
exists in which data was restored and the user was not told** — silence
here is the one thing explicitly forbidden.

---

## 11. Real-store verification protocol (runbook — manual, not automatable, not cuttable)

Rationale on the record: 850 green tests missed two device-only blockers in
1.0.2 (documented in memory). Unit tests verify the logic; this protocol
verifies **the actual bytes of the founder's accumulated store** — including
damage history no fixture can reproduce. It runs on a COPY; the device is
never the test bench.

### Step 1 — Get the real store off the device

The store lives in the **App Group** container. Trap, on the record: Xcode's
*Devices & Simulators → Download Container* exports the app's sandbox
container and does **NOT** include App Group containers — that route
silently yields no store. Two working routes:

- **Primary (requires one piece of DEBUG scaffolding, to be built by Sonnet
  and listed in ARCHITECTURE.md's "debug scaffolding to remove" section):**
  Settings → Debug → "Share raw store files" — zips `Vela.sqlite` +
  `-wal` + `-shm` from the App Group and hands the zip to the share sheet →
  AirDrop to the Mac. DEBUG-only, deleted after 1.0.3 ships.
- **Fallback (lesser — real data, but not the real bytes):** device
  all-time CSV export → import into a fresh 1.0.2 simulator install → use
  that sim's App Group store (`xcrun simctl get_app_container booted
  com.dmitrylogachev.budgetcrab groups` to locate it). This loses the
  historical damage (dangling refs) that is half the point — use only if
  the primary route is unavailable.

Duplicate the zip immediately; work only on copies (`store-rehearsal/run-N/`).

### Step 2 — Run the migration against the copy, twice over

- **Stage A — assertion harness:** one manually-invoked test,
  `RealStoreMigrationRehearsal` (in the existing unit-test target,
  `XCTSkip`-ed unless env var `REAL_STORE_PATH` is set, so CI never runs
  it). It copies the files at `REAL_STORE_PATH` into a temp dir, opens a
  `ModelContainer` with the V2 schema + `FinanceTrackerMigrationPlan`, and
  performs Step 3's checks programmatically where possible. Run targeted:
  `xcodebuild test -only-testing:FinanceTrackerTests/RealStoreMigrationRehearsal`
  with the env var set. Never the full suite.
- **Stage B — full launch-sequence drill in the simulator:** install the
  1.0.3 build on a fresh simulator, launch once to create the App Group,
  quit, copy the real-store files into the sim's App Group (path from
  `simctl get_app_container … groups`), **and pre-set the sim's app-group
  defaults to look like a 1.0.2 upgrade** (no `v2MigrationComplete`).
  Launch. This exercises what Stage A cannot: the §9.3 ordering, the backup
  write, the pre-migration screen, the widget gate, and the sentinel.

### Step 3 — Post-migration assertions (eyeball checklist)

Before migrating, record from the 1.0.2 device app: screenshot of the
Dashboard (month spent/earned + safe-to-spend), the all-time transaction
count, and one screen of the Transactions list. Then, on the migrated copy:

1. **Grand totals unchanged:** Dashboard month spent / earned / safe-to-spend
   match the 1.0.2 screenshots to the cent.
2. **Transaction count unchanged:** same count as recorded (Stage A asserts
   `fetchCount` pre == post programmatically).
3. **No dangling refs:** scroll the ENTIRE Transactions list (rendering
   fires every fault — a surviving dangling ref crashes here), open several
   transactions that have Accounts, open Categories & Accounts settings.
   Check `PersistenceLog` for the repair count — should be small and
   plausible (0–a few), not hundreds.
4. **A known split reads correctly:** create one 3-way split on a real
   transaction post-migration; verify the donut slices move by the split
   amounts, Dashboard month total does NOT move, `CategoryDetailView` for a
   split category shows the attributed (not full) amount, and the widget
   snapshot totals are unchanged after the split.
5. **Merchant learning survived the handoff:** type a merchant the device
   history knows into Quick Add → the personalized suggestion still appears.
6. **Backup lifecycle:** `Backups/pre-v2/` exists after first launch; still
   exists after the notice; gone after the *second* successful launch.

### Step 4 — The rollback drill (deliberate failure)

Requires one launch-argument seam (project's established pattern):
`--fail-migration` — DEBUG-only, throws at the top of
`repairDanglingReferences`.

1. Fresh sim + real-store copy as in Stage B. Launch with `--fail-migration`.
2. Expected: attempt 1 dies → relaunch → restore-from-backup runs → retry →
   dies again (seam still on) → **degraded floor screen** (10.4) appears;
   "Export my data" produces a correct CSV of the full ledger.
3. Verify `Diagnostics/failed-v2-1/` and `-2/` both exist (evidence
   preserved), `Backups/pre-v2/` untouched and still read-only.
4. Relaunch WITHOUT the seam: migration succeeds from the restored pristine
   store; the **"We restored your data from a backup"** notice appears with
   the correct transaction count; app fully functional; assertions of
   Step 3 hold.
5. Kill-mid-migration variant (optional, non-deterministic): relaunch drill
   killing the app from Xcode during step 6 — expect the same ladder.

**Ship gate: 1.0.3 does not submit until Steps 1–4 have been performed on a
real-device store copy and all boxes checked.** This protocol is manual by
design and is NOT in the cuttable set below.

---

## 12. Token discipline for the implementation pass (binding notes for Sonnet)

**Write exactly these tests, and no others, for this feature set:**

- The seven §8 canaries (C1–C7) + C0 conservation + the vacuity guard —
  one suite, `SplitCanaryTests`.
- The split-sum invariant + over-sum rule tests (§2.2 / §3.1).
- `MigrationRepairTests.test_cleanStore_isNoOp` and
  `test_dirtyStore_danglingSource_isNullified_dataIntact` (+ the category
  twin) — §7.5.
- One rollback-restore test: sentinel at attempt 1 + intact backup →
  restore produces a byte-verified V1 store and the restored flag
  (§10.3 steps as assertions).
- §6.5's policy tests (threshold boundary, latch, over-limit silence).

**Explicitly do NOT write:** UI permutation matrices over the pre-migration
/ degraded screens (one snapshot-free smoke each at most); idempotency
ceremony beyond the single §7.5 idempotence test (the restore path's
idempotence is by-construction, §10.3 — one test, not a family);
trivial-getter pins (`limitCents` round-trips, `Body` case equality);
re-tests of already-green suites; full-suite reruns — **targeted
`-only-testing:` runs only** (CLAUDE.md), the full suite runs once at the
very end before submission, not per-task.

**Not cuttable under any token pressure:** the §11 manual real-store
protocol. It is founder-executed, costs no tokens, and is the only gate
that has historically caught what the test suite missed.

---

## 13. Implementation order for Sonnet (one paragraph)

Build in this order, committing per step (conventional prefixes, build
before commit): **(1)** the pure layer — `CategoryAttribution`,
nil-category helpers, `MonthTotals`/`AnalyticsSeries` extractions, and
`SplitCanaryTests` green against the *unsplit* world (they pass trivially
now and become tripwires later); **(2)** the V2 schema bump in one commit —
§1.2 declarations + `TransactionSplit` + `Category.limitCents` + local
config for merchant learning + `VersionedSchema`/`MigrationPlan` with the
§7 stage, plus `MigrationRepairTests`; **(3)** the safety belt — §9 backup +
launch sequence + pre-migration screen + extension gate, §10 sentinel +
restore + degraded floor + notice (this includes converting
`SharedModelContainer`'s `fatalError` to a recoverable throw), plus the one
rollback-restore test and the two DEBUG seams (`--fail-migration`, Settings
→ Debug "Share raw store files"); **(4)** the A-path aggregation switch
(§2.4 A1–A12) — the canaries from step 1 are now live tripwires — then the
split editor UI; **(5)** §6 category limits end-to-end (model field is
already in from step 2; this step is the policy/refresher/scheduler wiring
and §6.5 tests); **(6)** localization keys for all new strings (5 locales,
baseline bump), then the §11 runbook executes on a real-store copy as the
ship gate. Steps 1–2 must not be reordered: the canaries exist *before* the
schema that could break them. All new strings via `String(localized:)`; no
`tx.category!` anywhere; targeted test runs only.

---

**STOP — design only. Nothing above has been implemented.**
