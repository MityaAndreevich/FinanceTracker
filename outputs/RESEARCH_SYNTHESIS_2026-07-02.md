# Research Synthesis & Decisions — 2026-07-02

**Inputs:** real App Store review mining (**4,904 usable reviews / 15 apps**, Apple RSS, US, most-recent ~500/app) + 6 NotebookLM queries (primary sources). **Decisions locked by user this session** (see §4). Supersedes parts of prior `budget_crab_decision`.

> **Corrected 2026-08-10.** The original header said "4,972 reviews / 17 apps"; neither figure was
> right. 18 apps were targeted, 16 returned rows, and one of those 16 was the **wrong app** — the
> Vento lookup resolved to "Barri Send Money & Remittances", a remittance app, whose 68 rows were
> flagged as a data gap below but never removed from the totals. They are removed now. Every count
> in §1 has been recomputed from `review_mining_output/reviews_20260702_135538.csv` with those rows
> excluded; the originals are shown in parentheses. **No conclusion in this document changed** —
> the largest single shift is 486 → 484, which is 27% either way. See §1.1 for the two apps that
> returned zero rows and the rule that follows from them.

---

## 1. Real review data — counted, not directional

Source: `review_mining_output/summary_20260702_135538.md` + `reviews_*.csv`.

**1-2★ (rage / churn drivers), n=1,804** *(was 1,821)***:**
`price_subscription 484 (27%)` ≫ `privacy_data 169` · `bug_crash 152` · `feature_request 139` · `logging_friction 108` · `categorization 108` · `couples 68` · `sync_breakage 66` · `export_import 51` · `widgets_watch 12`

*(originals, incl. the wrong app: 486 · 169 · 155 · 139 · 109 · 108 · 69 · 67 · 51 · 12)*

**3★ "gold", n=431** *(was 432)***:** `feature_request 81` · `price 65` · `logging_friction 47` · `privacy 41` · `categorization 41` — every one of these five is unchanged by the exclusion.

### Findings that overturn earlier web-tier assumptions
1. **"Sync breakage = #1 pain" was OVERSTATED.** Real sync mentions are ~4-6% even at aggregators, not the top theme. The web-tier claim came largely from affiliate blogs (esp. vento.money, which sells a manual app — motivated to amplify sync pain). Validated the Tier-2 skepticism. (Caveat: the sync regex is conservative and undercounts; treat 66 as a lower bound — but price still dwarfs it.)
2. **The real #1 rage is BILLING DARK PATTERNS, not price level.** Verbatim 1★: *"continued charging after I cancelled"*, *"you have to go into settings to completely cancel… beware!!!"*, *"False advertising"*, *"too many ads, my whole family uninstalled"*. → This is Budget Crab's strongest **data-backed wedge**: no ads, no dark patterns, one-tap cancel, no bank-data honeypot, cheap. 484 rage-reviews point straight at it.
3. **Categorization pain is specific & actionable:** *"STOP forcing default categories"*, *"let me start from a clean slate"*, and Mint's one-tap *"change all instances of this vendor"* vs competitors' clunky rule flows. → concrete feature spec (below).
4. **Logging-friction complaints at aggregators are about failed auto-sync forcing manual entry** (a betrayal for a bank app). For us, manual is the honest promise — our friction risk is pure entry *speed*, addressed by quick-add. Confirms P0.

### 1.1 Which apps contributed nothing — and the rule that follows

**Two of the 18 targeted apps returned ZERO rows: Empower (Personal Capital) and MoneyWatch.**
They appear in the miner's own summary table as `0 | 0 | 0 | 0`. They contributed nothing to any
count in §1, and they never did.

IDs re-verified 2026-08-10 against the iTunes lookup API, which the original "Re-verify IDs" note
asked for and never got:

| App | ID as used | Resolves today | So the zero means |
|---|---|---|---|
| Empower (Personal Capital) | `504672168` | **nothing — dead ID** | the app was never read, by any instrument |
| MoneyWatch | `1593524945` | ✅ "MoneyWatch: Budget & Finance" (Finance) | correct app; the RSS feed returned no US reviews |

> **RULE — a zero-row app is not evidence, and must never be cited as though it were.**
> A row count of zero is indistinguishable between "we pointed at the wrong app", "the feed was
> blocked" and "this app genuinely has no US reviews". All three produce the same silent, confident
> nothing, and a table cell reading `0` looks exactly like a measurement. Before naming a competitor
> as evidence, check it has rows in the corpus. If it does not, either cite a *different* instrument
> for it **and say which** (a listing read is a valid primary source for "what does this app
> advertise" — it is not evidence of user demand), or do not name it.
>
> This is the same defect class as a test that passes having scanned no files: the instrument
> reports success while measuring nothing.

**Where each zero-row app is cited downstream, and whether the claim survives** (checked 2026-08-10):

- **Empower — no downstream claim anywhere.** It is named only in this section and in §5. Nothing
  rests on it. The only cost is that the aggregator picture is one app thinner than "18 apps"
  implied.
- **MoneyWatch — four downstream citations, all survive.** `DEMAND_RESEARCH_AND_ROADMAP_2026-07.md`
  signals #9, #10, #11 and its source list (:131), plus `FEATURE_PREP_BACKLOG.md:28`. Every one of
  them cites MoneyWatch's **App Store listing** (what the app advertises), not its reviews — a
  different instrument, which the zero-row result says nothing about. The ID is confirmed correct,
  so the listing reads were pointed at the right app. They stand as listing evidence.
  **⚠️ But see the separate note on signal #9 — it survives as a citation and fails as a
  conclusion, for an unrelated reason.**

### Other data gaps (not invented)
- **Vento resolved to the wrong app** ("Barri Send Money & Remittances"). Its 68 rows were left in
  the totals until the 2026-08-10 correction; they are now excluded. Our direct manual/privacy lane
  is thin (only Goodbudget captured well). Need correct IDs for Vento, and add **Actual Budget,
  Zeroed, Buckets** if on iOS.
- **"Beyond Budget" and "Budget app"** are named as listing evidence in signals #9 and #11 but are
  not in the 18-app corpus under any name. Listing-sourced, so not invalidated — but unverifiable
  from anything in this repo.
- Small samples (Monarch 50, Copilot 50, MOZE 23) → their % are noisy; weight low.

---

## 2. NotebookLM primary findings (key numbers + citations)

**0e5f6bb9 Pricing —** premium + hard paywall beats freemium+low-price: **D35 conversion 10.7% vs 2.1% (5×)**; **RPI by D60 ~$3.09 vs $0.38 (8-9×)**; **install→trial 9.8% (high price) vs 4.3% (low)**; **payer LTV $62.19 vs $10.69 (~7×)**. Low price retains better (36% vs 23% Y1) but doesn't offset revenue; access model is conversion-not-loyalty (27% vs 28% retention). Price-war fails: **Brainerr $9.99 lifetime → "revenue cliff"**; low anchor makes raises hard. *Caveat I add: premium verdict assumes reinvestment into paid UA — we have none, so rating protection matters more.*

**73afc9a4 Couples —** "decisive driver" at premium price; Monarch/YNAB use household sharing to justify $99-109/yr. Single-user CAN win via **digital-sovereignty / local-first niche** (Zeroed, Actual). Verdict for us: at premium price, shared iCloud budgets recommended or app is seen as "simple utility."

**73afc9a4 Domain (aggregator vs manual) —** aggregator complaints: sync instability, $100/yr wall, data-sovereignty (post **$58M Plaid settlement**), duplicate txns. Manual complaints: maintenance fatigue (**most abandon manual trackers within 2 weeks**), self-host complexity, platform parity. Manual requests: **AI-assisted entry** (screenshot/NL parsing, local), **sovereign sync via iCloud/Dropbox**, **lifetime/one-time pricing** (Buckets $64, Zeroed $39.99), **CSV/Mint importers**. Benchmarks: **70% of trackers feel anxious** (→ simple dashboard-first UI); Lunch Money keeps 7.8/10 satisfaction via "set your own price."

**ff5e0abc Quick-entry UX —** mobile sessions ~72s → capture gist (amount+merchant) before minutiae. Patterns: **one-tap add / auto-save with defaults ("Magic Plus", Things 3)**, default to "Uncategorized" not prompt, haptic+checkmark feedback, robust Undo. **Widgets** = contextual triggers (App Intents one-tap log). **Apple Watch** at-a-glance. **Siri/Shortcuts** NL entry. Anti-pattern: **"Mint pattern" of predictive modal pop-ups during entry** = drives abandonment.

**ff5e0abc Onboarding —** immediate "aha"/perceived success (**Headspace 96% activation**), perceived ownership + variable rewards (Robinhood), guided programmatic ScrollView (`.scrollDisabled(true)`) — **Blinkist +23% trial conversion**; postpone nonessential setup, reasonable defaults, skeleton screens (`.redacted`).

**04c87827 Zero-budget channels (ranked) —** 1) **ASO** (65-70% of downloads from search; Flipster **+88% organic in 1 month**; 38k+ keywords → 10M installs/8mo). 2) **Ratings optimization** (79-80% check ratings; 3.6→4.2 = **+60% CVR**; "borrowed credibility" in screenshot 1 lifts DL up to 90%). 3) **Organic Custom Product Pages** (up to 70, +5.9-8.6% CVR). 4) Educational/viral short-form. 5) **Reddit/PH = low-to-moderate**, best for gathering social proof/logos for the screenshot billboard, not volume.

**de492776 Submission risk —** ⚠️ **§5.1.1: finance apps must be submitted by the legal ENTITY, not an individual** (banking/financial-services/money-management). Subscription disclosure §3.1.2: actual billing amount most prominent, "Save X%" subordinate, renewal + restore required. Trials must state duration + exact post-trial price. **"Was/Now" pricing fraud** = removal (relevant: don't fake strikethrough). Data protection `NSFileProtectionComplete` expected.

---

## 3. Reconciliation — how the two data sources fit

- Pricing notebook says premium wins **on EV**; real reviews say price is #1 rage **on ratings**. Both true: complainers ≠ payers, but on a **zero-UA organic launch ratings are the engine** (ASO notebook). Resolution: **premium but not aggregator-high ($4.99, well under YNAB/Monarch/Rocket), + trial + honest billing** → capture LTV without triggering the dark-pattern rage that tanks ratings.
- Couples "decisive at premium" + we're moving to premium → couples rises in importance → **plan it (CloudKit), don't dismiss it.**
- Manual-abandonment (2 weeks) + friction data → **quick-add is existential, not optional.**

---

## 4. DECISIONS LOCKED (user, 2026-07-02)

1. **Pricing: REVERT Path B → Path A = $4.99 / $34.99 (7-day trial) / $99.99 lifetime.** Rationale: two independent research rounds (this + positioning_r2) + 7× LTV + low-anchor risk. Path B ($3.99) was risk-driven; EV favors Path A. Still far below all aggregators.
2. **Access model: HYBRID** — limited free tier as organic funnel (installs→reviews→ASO), firm paywall on premium features, lead with 7-day trial. Not "generous-free-forever" (5× worse conversion), not "hard-paywall-only" (starves zero-UA funnel).
3. **Couples: P2 via CloudKit Shared Database** (private, no our-server). Not a v1.0 blocker; the answer if premium positioning demands it.

---

## 5. Downstream actions this triggers

**Pricing revert (must do before ASC IAP + submit):**
- ASC: enter Yearly/Lifetime at **Path A** ($34.99 / $99.99), Monthly $4.99. The `ASC_IAP_SETUP_CHECKLIST.md` (Path B) is now **STALE — regenerate for Path A**. (Well-timed: IAP setup was paused, minimal rework.)
- Code (Claude Code brief): revert `PaywallView` + `.storekit` + 5× `.strings` to $4.99/$34.99/$99.99, **"Save 42%"**, trial disclosure "$34.99/year". (Prior session had synced these to Path B — now reverse.)
- Per-territory tables: rescale to Path A base (use pricing playbook 02).

**Roadmap updates (data-backed):**
- P0 add: **billing transparency as product + copy** — one-tap cancel, no ads, no dark patterns, no hidden charges. This is the #1 wedge (484 rage-reviews).
- P0 add: **categorization = clean-slate custom categories + one-tap "recategorize all from this merchant" + simple rules** (direct from 3★/1★ quotes).
- P0 keep: quick-add (widgets/Watch/Siri), "safe to spend", iCloud sync.
- P1: recurring+reminders, envelope goals, CSV/Mint importer, multi-currency.
- P2: **couples via CloudKit**, basic forecasting, AI-assisted entry (screenshot/NL parse, local — ties to v1.1 AI roadmap).
- Anti-pattern to enforce: **no predictive modal pop-ups during entry** ("Mint pattern").

**ASO / positioning (feeds a future /aso brief):**
- Lead billboard screenshot with one bold number + donut + a "borrowed credibility"/rating line once earned.
- Keywords: "budget app without bank linking", "manual expense tracker", "Mint alternative privacy", "no ads budget", "cancel anytime".
- Ratings optimization = top priority (in-app review prompt after a success moment; 3.6→4.2 = +60% CVR).

**Submission de-risk:**
- ⚠️ **Verify §5.1.1** does NOT catch Budget Crab (offline tracker, no bank connection, no money movement, individual dev). Likely exempt (utility, not financial service) and our no-bank design helps — but confirm against guideline wording before submit. If risk, consider a simple legal-entity/DBA.

**Research follow-ups:**
- Fix the Vento ID (+ add Actual/Zeroed/Buckets) and re-run the miner for the direct-lane picture.
  **IDs re-verified 2026-08-10 — see §1.1:** MoneyWatch's ID was correct all along (its feed simply
  returned no US reviews); Empower's `504672168` is a dead ID and needs a new one before Empower can
  be re-mined at all.
- Optional: re-run with `--country us gb ca au` for launch English markets.

---

## Sources
Real data: `review_mining_output/` (this repo). NotebookLM notebooks: 0e5f6bb9, 73afc9a4, ff5e0abc, 04c87827, de492776 (run 2026-07-02, Claude Code). Full query set: `outputs/NOTEBOOKLM_RESEARCH_QUEUE.md`.
