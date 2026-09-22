# DESIGN — Receipt and screenshot scanning, 1.0.7

**Status: DESIGN, awaiting the founder's approval. No code written. No corpus collected. No parser
run against anything.** Brief: `outputs/BRIEF_MASTER_2026-09-21.md:166–201` (Phase 2). Written
2026-09-21 at HEAD `9a56553`. Status lives in `outputs/STATE.md` row **R1**.

**Two things this document does not do.** It does not describe the receipt pre-test as resolved — it
is not (`STATE.md` R1, R1c: T0 is still blank); the founder decided to build over it, and that
decision is recorded in STATE.md, not re-argued here. And it does not set the accuracy bar after
seeing any result: §7 pre-registers the bar and the corpus **before** a parser exists, and the parser
is written before the corpus is run against it. That ordering is the whole point of §7.

---

## 0. Evidence, before the design

| question | source | finding |
|---|---|---|
| Demand in the competitor review corpus | `review_mining_output/reviews_20260702_135538.csv`, N = 4,904 (Barri excluded), counts run 2026-09-21 | `\breceipts?\b` **20 (0.41%)**; receipt + ask/complaint language **11 (0.22%)**; `scan` 5 (0.10%); "photo/snap … receipt" 5; `ocr` **0**; `screenshot` 7 (0.14%). Top apps mentioning receipts: Goodbudget 5, PocketGuard 4, Spendee 4. The pre-test (§7.4) already argued this corpus is the wrong instrument for this feature — it is dominated by bank-sync users |
| Who ships it, and how | notebook `73afc9a4`, fresh conversation 2026-09-21, no `[History]`, negative control ("receipt scanning by smell") → NOT IN SOURCES | Finny: *"Photograph a receipt and the app extracts totals, dates, and merchant names"* and *"share screenshots from your banking app, payment apps (Venmo, Zelle, Cash App), or email receipts"*, *"Finny's local OCR engine parses these images … locally"*, free tier. Zeroed: *"every receipt you scan with the on-device OCR … lives on your phone"*, one-time purchase. **Accuracy or failure modes users report: NOT IN SOURCES.** Screenshots of *online orders* specifically: NOT IN SOURCES |
| Confirm-before-save UX for machine-read data | notebook `ff5e0abc`, fresh, negative control ("triple-tap confirmation gesture") → NOT IN SOURCES | **NOT IN SOURCES.** Only the general principle: *"check for them and present users with a confirmation option before they commit to the action"* |
| The two citations that originally ranked this feature | `DECISION_RECEIPT_INPUT_PRETEST.md` §7 (sibling repo), `AUDIT_NOTEBOOKLM_CITATIONS_2026-08-13.md` | *"top request"* and *"#1 churn risk"* **both failed a clean re-ask**. What survived: manual-tracker users do ask for receipt import; on-device OCR is valued for privacy |

**Reading.** On-device receipt scanning is a feature two privacy-positioned competitors ship and
sell on exactly our positioning; the review signal for it is weak (0.22% asks, the same band as
reports and sync), and **nobody has published an accuracy number** — which is why §7 measures one.
The design is sized to the founder's decision, not to the signal: one flow, five locales, no ML
pipeline, and a measured bar before it ships.

---

## 1. Ground read, and what it constrains

| ground | fact (file:line at `9a56553`) | constraint |
|---|---|---|
| Prefill surface | `AddTransactionView.swift:14–21` `AddTransactionPrefill { typeRaw, amountText, merchant, categoryUUID, sourceUUID, recurrence }` — **no `date`, no `note`**; `:46` `date` is never prefilled; `:520–525` save rejects dates outside 1990-01-01…now+1y | Extend the prefill with `date: Date?` and `note: String?`; clamp/validate the OCR date to that window before prefilling |
| Save path | `AddTransactionView.swift:497–575`: `AddTransactionSaveService.save` → `MerchantLearningService.record` → recurrence → `RatingPromptCoordinator` | **Reused as-is** — the scan flow ends by presenting this view. No new save code |
| Quick Entry | `QuickEntryView.swift` has no date control; `testHookInput` is a screenshot-mode text seam | Not the prefill surface. The scan **entry button** lives in both sheets; the **result** always lands in `AddTransactionView` |
| Category | `AddTransactionView.swift:591–597` a prefilled `categoryUUID` shows an "Auto-detected ✓" chip and suppresses the inline suggestion (`categoryManuallyChosen`) | Prefill a category only from `CategorySuggestionService.suggest(forMerchant:)` on the OCR'd merchant; otherwise leave the picker |
| Amounts | `AmountParsing.parseCents(_:decimalSeparator:)` (`:44`) rejects: no digits, unrepresentable integer part, overflow; `maxAmountCents` (`:34`) checked by the view; `hasConsistentSeparators` (`:144`) | Every candidate goes through `parseCents`; a rejected token is not a candidate. Separator = the app locale's (§4.3) |
| Camera / Photos / Vision | **none exists** — no imports, no usage strings; usage strings are pbxproj `INFOPLIST_KEY_*` in two configs (`project.pbxproj:652–654`, `:696–698`) | Add `INFOPLIST_KEY_NSCameraUsageDescription` ×5 to both configs. `PHPickerViewController` needs **no** photo-library permission (out-of-process picker) |
| Privacy manifest | `PrivacyInfo.xcprivacy`: no collected data types, one accessed-API reason | In-memory processing adds nothing. **Attachment** (§5) is the item that `APP_PRIVACY_ANSWERS.md` §1.5 flags — re-read at that point, not assumed |
| Schema | `Transaction` has no image field; the store is on the V2/V3 track (`DESIGN_V3_SCHEMA_FREEZE.md`, L1–L3 rollback ladder unbuilt) | **No schema change in this feature.** The optional attachment is a file keyed by `Transaction.uuid`, not a model field (§5) |
| Storage | everything lives in the App Group container; `<group>/Backups` (`StoreBackup.swift:61`) | Receipt images, if kept, go in `<group>/Receipts/`, excluded from the backup copy set and from the synced config |
| Usage signal | `FeatureUsageSignals.Feature` has no scan case; the §1.1 lesson: mark **after** the save returns | Add `receiptScan = "receipt_scan"`, marked in `AddTransactionView`'s success path when the prefill came from a scan |
| Speech is the precedent | `VoiceInputService` is `@StateObject` per sheet, permission asked on tap, `requiresOnDeviceRecognition = true` | Same shape: permission on tap, never at launch; the recognizer is created per scan |

---

## 2. Definitions

- **Capture** — one image: a `VNDocumentCameraScan` page (paper) or a `PHPickerResult` image (screenshot).
- **Recognition** — `VNRecognizeTextRequest`, `.accurate`, `usesLanguageCorrection = true`,
  `recognitionLanguages` = the app language's Vision code first, then the other four (§4.1). Output:
  lines with text, normalised bounding box, Vision confidence.
- **Parse** — pure function from recognised lines to `ReceiptParse` (§4.2). No model, no I/O.
- **Prefill** — `AddTransactionPrefill` built from a parse and presented; the user saves or does not.
- **Grand total** — the amount the customer paid: *Total / Grand total / Order total / Amount due /
  Amount paid* and their locale equivalents. **Not** subtotal, tax, shipping, discount, tip, change,
  cash tendered.
- **Confidence** — `high` / `low`, defined in §4.4. Only `high` prefills the amount.

---

## 3. Approaches considered

**A — VisionKit + PHPicker + Vision text recognition + a keyword-ranked pure parser (RECOMMENDED;
§4–§6 specify it).** No model training, no network, one pure function to test. Prefill into the
existing form.

**B — Vision's `VNRecognizeDocumentsRequest` / receipt-structured document parsing (iOS 26 Vision
document intelligence).** It returns tables and detected data (currency amounts, dates) with
structure. *Why not now:* it raises the deployment target from iOS 17 (`ARCHITECTURE.md` Stack); its
receipt behaviour in ru/uk is unmeasured; and the founder's corpus rule applies to it exactly as to
A, so it saves no measurement. **Revisit after §7's first result: if A's paper accuracy is below the
bar in a locale, B is the first thing to measure against the same corpus.**

**C — Foundation Models (on-device LLM) to extract fields from the OCR text.** *Why not:* iOS 26
only, device-restricted, non-deterministic output on the same input — which makes the corpus
measurement a distribution rather than a number — and the brief's "do NOT over-engineer an ML
pipeline in MVP" (`SPEC_PHOTO_INPUT.md:24`).

---

## 4. The flow

### 4.1 Entry, capture, recognition

- A **scan button** (`doc.viewfinder`) beside the mic in `QuickEntryView` and in `AddTransactionView`'s
  toolbar. Tap → a two-item menu: **Photograph receipt** · **Choose screenshot**.
- Paper: `VNDocumentCameraViewController` (VisionKit — edge detection, perspective, multi-page;
  **only page 1 is parsed**, the rest are dropped with a one-line notice). Camera permission is
  asked here, on first tap.
- Screenshot: `PHPickerViewController`, `filter = .screenshots` first with a toggle to *All photos*
  — the picker is out-of-process, so no library permission and no `NSPhotoLibraryUsageDescription`.
- Recognition runs on a background queue on the captured `CGImage`, downscaled to ≤ 2 200 px on
  the long side (Vision's accurate model needs no more; memory on a 16 GB Mac is not the phone's
  problem, but a 48 MP capture is). **The image never leaves the process** — no `URLSession`, no
  share, no file until §5.
- **A guard that is a test, not a sentence:** `NoNetworkInScanModuleTests` scans every file under
  `Services/ReceiptScan/` and `Views/ReceiptScan/` for `URLSession`, `URLRequest`, `Network`,
  `CloudKit`, `MLModel` and fails on any hit (the `AudioSessionCallSiteGuardTests` shape).
- `VNRecognizeTextRequest.supportedRecognitionLanguages()` **must contain** `en-US`, `ru-RU`, `es-MX`,
  `pt-BR` and `uk-UA` (or their base codes) on the deployment target; a test asserts it on the
  simulator and the result is recorded in §7's report. If `uk` is unsupported by Vision on iOS 17,
  Ukrainian receipts are recognised with `ru` + `en` and **that is stated in the What's New and the
  Guide card** — not silently.

### 4.2 The parser — `ReceiptParser.parse(lines:locale:) -> ReceiptParse` (pure)

```swift
struct RecognizedLine: Sendable { let text: String; let box: CGRect; let confidence: Float }
struct AmountCandidate: Sendable { let cents: Int; let line: Int; let keyword: TotalKeyword?; let visionConfidence: Float }
struct ReceiptParse: Sendable {
    let total: AmountCandidate?          // nil = no high-confidence grand total
    let confidence: Confidence           // .high / .low
    let candidates: [AmountCandidate]    // every parseable amount, for "not this? tap another"
    let merchant: String?
    let date: Date?
    let currencyHint: String?            // symbol/code seen on the total line, for a mismatch warning only
    let rawText: String                  // joined lines, for the hint and the optional note
}
```

**Keywords, per locale, two tiers.** Tier 1 (grand total): en *grand total, order total, total
due, amount due, amount paid, you paid, total paid, balance due*; ru *итого, к оплате, итого к
оплате, всего к оплате, сумма к оплате, оплачено*; es *total a pagar, importe total, total pagado,
gran total*; pt-BR *total a pagar, valor total, total pago, total do pedido*; uk *до сплати, разом
до сплати, всього до сплати, сплачено*. Tier 2 (total): en *total*; ru *всего, сумма*; es *total,
importe*; pt-BR *total*; uk *сума, разом, всього*. **Exclusions** (a line matching one of these is
never a total even if it also matches tier 2): *subtotal / sub-total / промежуточный итог /
подытог / subtotal / subtotal / проміжний підсумок*, *tax / VAT / налог / НДС / impuesto / IVA /
imposto / податок / ПДВ*, *shipping / delivery / доставка / envío / frete / доставка*, *discount /
скидка / descuento / desconto / знижка*, *tip / gratuity / чаевые / propina / gorjeta / чайові*,
*change / сдача / cambio / troco / решта*, *cash / наличные / efectivo / dinheiro / готівка*,
*savings / you saved / экономия / ahorro / economia / заощаджено*. Matching is case- and
diacritic-insensitive on the whole line, all five locales always active (a Russian user photographs
an English receipt).

**Amount tokens.** A regex over the line for digit groups with optional grouping (`,` `.` NBSP
space `'`) and optional decimals, optional currency symbol/code on either side. Each token goes
through `AmountParsing.parseCents(token, decimalSeparator:)` with the **app locale's** decimal
separator (§4.3). Rejected → not a candidate. `cents <= 0` or `> AmountParsing.maxAmountCents` →
not a candidate. A total line whose amount is on the **next** line (right-aligned totals split by
OCR) is handled by looking one line down when the keyword line itself has no token.

**Ranking, in order:**
1. Tier-1 keyword lines. If several, the **last one on the page** (receipts end with the paid
   amount; online orders end with *Order total*); ties by larger amount.
2. Else tier-2 lines, **excluding** any whose amount is smaller than another tier-2 line lower on
   the page (a *Total* followed by a larger *Total* is subtotal/total). Last, then largest.
3. Else → `total = nil`, `confidence = .low` — the largest amount is **not** guessed. (The 2026-07
   spec said "else the largest number"; it is dropped: on an online order the largest number is
   often the item price before a discount, and a plausible wrong money figure is the class of
   defect this project has paid for most.)

**Merchant.** The first line from the top with ≥ 3 letters, not matching a date, amount, phone,
URL, address-number pattern or a keyword; screenshots: also a line matching *order from X* /
*заказ … X* patterns is preferred. ≤ 200 characters (the view's limit). Always shown for
confirmation; never learned until the user saves.

**Date.** First token matching `dd.mm.yyyy`, `dd/mm/yyyy`, `yyyy-mm-dd`, `dd-mm-yyyy`, or
`d Month yyyy` with month names in the five locales; `mm/dd` vs `dd/mm` ambiguity resolved by the
app locale, and **if both readings are valid and differ, the date is not prefilled** (today stays).
Outside the view's 1990…now+1y window → not prefilled.

### 4.3 The decimal-separator decision

`AmountParsing.parseCents` takes a separator only for the one ambiguous shape (one separator, three
digits after). The parser uses the **app locale's** separator, because that is what the user will
read the prefilled amount in and correct against — and the review screen shows the token as
recognised next to the parsed amount, so `1.250` read as 1 250,00 ₽ in a ru app is visible before
save. A **currency-symbol mismatch** (a `$` on the total line in an app set to RUB) shows a warning
line under the amount and does **not** change `defaultCurrencyCode` — per-transaction currency was
removed for a reason (`ARCHITECTURE.md` "Currency is locked").

### 4.4 Confidence, exactly

`high` when **all** of: a tier-1 or tier-2 line matched; its amount parsed; Vision's confidence for
that line ≥ 0.5; and, when tier-2 was used, the chosen amount is ≥ every other tier-2 amount on the
page. Otherwise `low`. There is no third state — the pre-test's §1 defect was a signal with a silent
third state, and confidence here has exactly two values so the review screen has exactly two shapes.

### 4.5 The review screen — `ReceiptReviewSheet`

One sheet after recognition, before the form:

```
┌──────────────────────────────────────────┐
│ [thumbnail]   Recognised                  │
│                                           │
│  Amount    1 250,00 ₽        ← high: filled, "Total" line shown under it
│            (empty)           ← low: empty; "We couldn't find a total — tap
│                                 an amount below or type it"
│  Other amounts on the receipt:  980,00 · 270,00 · 1 250,00   (tap to use)
│  Merchant  Перекрёсток                                        │
│  Date      21 Sep 2026                                        │
│  ▸ Recognised text (collapsed)                                │
│                                                               │
│  [ Use these ]                        [ Retake ] [ Cancel ]   │
└──────────────────────────────────────────┘
```

**Use these** presents `AddTransactionView(prefill:)` with amount (only if `high`), merchant, date,
category via `CategorySuggestionService.suggest(forMerchant:)` when it returns one, and `note`
left empty even though the extended prefill can carry one (the raw text is **not** written into the note — it would put the receipt's contents into
the ledger and into every export). The form's own Save is the only save. **Nothing is ever
auto-saved**, and the review sheet has no save button of its own.

Copy on this sheet is a claim (`ARCHITECTURE.md`): *"We couldn't find a total"* is what happened;
the screen never says *"Total found"* for a `low` parse.

---

## 5. The optional attachment — file, not schema, OFF by default

- Settings → Data → **Keep receipt images** toggle, default **off** (brief `:184`). Off = the image is
  discarded the moment the review sheet closes.
- On = after a successful save, a JPEG (≤ 1 600 px long side, quality 0.7, EXIF stripped) is written
  atomically to `<App Group>/Receipts/<transaction uuid>.jpg`. **No model field, no schema
  version, no migration**: presence is `FileManager.fileExists`. `TransactionDetailView` shows it
  under the note. `TransactionDeleteService` removes the file with the row; `wipeLedger` / Reset
  remove the directory. `StoreBackup`'s copy set and both `ModelConfiguration`s exclude it.
- **It stays on the phone.** The images are never included in CSV/TSV/PDF export, and they live
  inside the App Group container, which the Files app does not show — so "keep" means keep for the
  detail screen only, and the toggle's footer says exactly that.
  **DECIDE:** ship the toggle in 1.0.7, or defer attachment to 1.0.8 and ship scanning as
  in-memory only. Recommended: **defer**. The brief allows it ("optional"), it removes the App Privacy
  question (`APP_PRIVACY_ANSWERS.md` §1.5) from this release, and it keeps §7 about one thing.

---

## 6. Strings, permissions, usage

- `INFOPLIST_KEY_NSCameraUsageDescription` ×5, both configs, in the on-device register the mic
  string uses: *"Budget Crab photographs a receipt to read the total. The photo is processed on your
  iPhone and is not uploaded."* Every sentence of it is checked against §4.1's no-network guard.
- Keys under `scan.*` (≈ 25) ×5; `LocaleCompletenessTests` tripwire moves with them.
- `FeatureUsageSignals.Feature.receiptScan`, marked in `AddTransactionView`'s success path only
  when the prefill carried `source: .receiptScan`; one appended line in the usage summary.

---

## 7. MEASUREMENT — pre-registered here, before any parser exists

**Ordering, which is the whole point:** (1) this section is approved; (2) the corpus is collected
and its manifest frozen (SHA-256 of every image and of the manifest, committed); (3) the parser is
written against `ReceiptParserTests` fixtures that are **not** corpus images (synthetic OCR text
lists); (4) the corpus is run **once** and the result is reported as-is, misses included; (5) any
parser change after (4) is followed by a re-run reported next to the first, never in place of it.

### 7.1 The corpus

| type | locale | minimum | source |
|---|---|---|---|
| paper | en · ru · es-MX · pt-BR · uk | **10 each** | real photographs of real receipts (the founder's, mine, and public-domain images whose licence permits redistribution), varied: thermal fade, skew, a crumple, a long grocery slip, a café slip with tip, a fuel receipt, a pharmacy receipt with tax lines |
| screenshot | en · ru · es-MX · pt-BR · uk | **10 each** | real screenshots of order confirmations / payment apps / email receipts where available; **rendered fixtures** where not (a screenshot *is* rendered pixels, so rendering is faithful for this type in a way it is not for paper). Every rendered one carries Subtotal, Tax, Shipping or Discount lines **and** a grand total, because that is the failure the brief names |

Minimum **100 images**. For each: `true_total_cents`, `true_merchant`, `true_date`, `locale`,
`type`, `source` (real/rendered), `notes` — in `FinanceTrackerTests/Fixtures/Receipts/manifest.csv`.
**Paper cannot be certified from rendered images.** If real paper photos are short in a locale, that
locale's paper cell is reported as *"n < 10, not certified"*, not filled with renders.

### 7.2 The metrics — computed by a reporter test that prints the table

Per (type × locale) cell, over the frozen corpus:
- **Exact total** — `parse.total?.cents == true_total_cents`.
- **Wrong-prefill rate** — `confidence == .high && total != true` (the dangerous one: a plausible
  wrong money figure, filled in).
- **Missed** — `confidence == .low` on an image with a true total (the safe failure: empty field).
- **Merchant match** — case-/diacritic-insensitive prefix match of ≥ 4 characters.
- **Date match** — same day.

### 7.3 The bar — set now, moved never

| cell result | ships as |
|---|---|
| exact total **≥ 90%** AND wrong-prefill **≤ 3%** | prefill on (`high` fills the amount) |
| exact total 75–90% AND wrong-prefill ≤ 3% | prefill on, **with the "check the amount" line always shown** for that locale |
| wrong-prefill **> 3%** in any cell | that (type × locale) ships **hint-only** (amount never prefilled) regardless of exact-total — a filled wrong amount is worse than an empty field |
| exact total **< 75%** | the founder decides: hint-only, or not shipped for that locale, stated in What's New |

Merchant and date have **no bar**: they are convenience prefills the user sees before saving, and
they are reported, not gated.

**Negative control for the instrument:** 5 images that are **not receipts** (a menu, a business
card, a page of text, a photo with no text, a bank statement) — every one must come back `low` with
`total == nil`. If any comes back `high`, the parser is not ready to be measured.

### 7.4 What is reported, honestly

One table, five rows × two types, every cell with n, exact %, wrong-prefill %, missed %, merchant %,
date %, and **the list of misses** (image id, true total, what was chosen, which rule chose it).
`ReceiptCorpusReportTests` prints it and asserts only that it measured something (n ≥ 100), so the
number is visible in every run; `ReceiptAccuracyBarTests` asserts §7.3 per cell and is the gate.

---

## 8. Free vs premium — PROPOSED, NOT DECIDED

Evidence: NOT IN SOURCES for scanning specifically; Finny ships it in a free tier, Zeroed behind a
one-time purchase (§0). The founder's rule from Phase 1 applies: *"a gate is easy to remove later
and painful to add — so start gated, revisit on data."*

| option | free | premium | consistency |
|---|---|---|---|
| **S1 (recommended)** | **5 scans per calendar month** | unlimited | the counted-cap pattern already built (`CapGate`, accounts and custom categories); the free allowance is enough to learn the feature and to be measured (`receiptScan` usage line); a 6th scan hits the paywall with a row *"Unlimited receipt scanning"* |
| S2 | none — premium only | all scanning | consistent with "start gated"; but a feature nobody can try converts nobody, and the usage line would measure only payers |
| S3 | everything | — | Finny's shape; contradicts the founder's stated rule |

Whichever is chosen, the paywall table derives from `AppCapability` (`PaywallComparison`), so the
row and the `unshippedCapabilities` entry are part of the build, not copy.

---

## 9. Test plan

Rule 2 throughout: each guard observed red before the code it guards.

- **`ReceiptParserTests`** (pure, on hand-written `RecognizedLine` lists, not corpus images): the
  ranking rules one by one — tier-1 beats tier-2; last tier-1 wins; subtotal/total picks the larger
  later total; exclusion lines never win; amount on the next line; a rejected token (`AmountParsing`
  nil) is not a candidate; `> maxAmountCents` is not a candidate; no keyword → `low` and no guess;
  all five locales' keywords, with diacritics; the date rules incl. the ambiguous-date-not-prefilled
  rule; merchant selection; the currency-mismatch hint. Negative control: a mutant that re-enables
  "largest number" must fail the online-order fixture.
- **`AmountParsingTests`** gain the receipt shapes: `1 250,00`, `1.250,00`, `1,250.00`, `R$ 1.250,00`,
  `₴1 250,00`, `$1,250.00`, `1250` — each with both separators, asserting the documented reading.
- **`NoNetworkInScanModuleTests`** — source scan (red first by planting a `URLSession` line).
- **`VisionLanguageSupportTests`** — the five languages are supported on the simulator; the result
  is a line in the §7 report.
- **`ReceiptCorpusReportTests` / `ReceiptAccuracyBarTests`** — §7, run against the frozen corpus with
  Vision on the simulator. Commissioned red by a keyword-list mutant (all tier-1 removed).
- **`AddTransactionPrefillDateTests`** — the extended prefill sets the date and note; an
  out-of-window date is dropped; a prefilled category shows the chip. Red first: the current
  prefill has no date field, so this cannot compile until it does — the red is the compile, recorded.
- **Journey (UI, erased simulator):** launch → Quick Entry → scan → *Choose screenshot* → a fixture
  screenshot injected via a launch-argument seam (the picker cannot be driven in XCUITest) → review
  sheet shows the amount → Use these → the form shows it → Save → the transaction exists with that
  amount (presence). And the `low` journey: the non-receipt fixture → empty amount, hint present →
  the user types an amount → save.
- **Existing guards unchanged and green:** `PDFExportRenderTests`, `ReportEqualityCanaryTests`,
  `PoisonedAnalyticsJourneyTests`.

---

## 10. Release cut, sizing, and what is out

- **1.0.7 = scanning (this document) + the user guide (Phase 3)**, per the brief. No schema change.
- Relative cost, largest first: (1) the corpus — collection is the founder's and mine, and it gates
  the ship decision; (2) the parser + its tests; (3) the review sheet + capture UI; (4) strings ×5
  + permission strings + paywall row.
- **Out:** multi-page receipts (page 1 only), batch scanning, item-level line parsing (a split
  transaction from a receipt), bank-app screenshot import as a separate flow (Finny's), the
  attachment if §5's recommendation is taken, Foundation Models / document intelligence (approach
  B, revisited on §7's result).

---

## 11. Decisions for the founder

1. **§8 premium:** S1 (5 free scans/month) / S2 / S3.
2. **§5 attachment:** defer to 1.0.8 (recommended) / ship the toggle in 1.0.7.
3. **§7.1 corpus:** who supplies the real paper photographs, and by when — the parser is not run
   against the corpus until the manifest is frozen, so this date is the feature's critical path.
4. **§4.1 Ukrainian:** if Vision on iOS 17 does not list `uk`, accept ru+en recognition for uk
   receipts (stated in copy), or hold the locale.
5. Approve approach A, or send back.

Nothing in this document is built. STOP.
