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

> ### ⚠️ STANDING CAVEAT ON THIS CORPUS — read before using any percentage on this page (added 2026-08-13)
>
> **Every percentage in this document, and every demand percentage derived from it anywhere in this
> programme, is a share of a population whose first choice we refuse to serve.**
>
> This corpus is competitor reviews, and the competitors are overwhelmingly bank-linked aggregators.
> Asked cleanly what manual-tracker users most want, the sources answer with the one thing we have
> decided never to build:
>
> > *"The most common request we get is, 'When will you add Plaid for automatic bank sync?' Our
> > answer is always the same: we won't."*
>
> Refusing it is the product, and the refusal is well defended. But it means the people who would
> most want a manual, local-first, privacy-first tracker — **our** users — are the people **least
> likely to appear in this corpus at all**, because they never installed the apps it samples.
>
> **Both halves of this matter, and the caveat is useless if only the first is remembered:**
>
> **VALID — comparisons between features measured the same way.** Sync at 0.28% versus shared access
> at 0.04–0.14% is a sound comparison: same corpus, same denominator, same instrument, so the bias
> applies equally to both. *"Below a threshold we already declined to build against"* remains a real
> argument, and the falsifications built on this corpus (the "69 rage" idiom artefact, the
> remittance-app exclusion) **stand without qualification** — they are mechanical properties of the
> data, not inferences from it.
>
> **INVALID — reading any single number as an absolute statement about our market.** "0.28% mention
> sync, therefore our users don't want sync" does not follow. The number is a fact about aggregator
> users. It may mean *"low demand for X"*; it may equally mean *"this is not our population."* From
> this corpus alone the two are indistinguishable, and no amount of extra rows from the same source
> can separate them — a bigger sample of the wrong population is still the wrong population.
>
> **The consequence, stated plainly, because it is the operative one:**
>
> > **One forwarded inbox from our own users outweighs another 4,904 competitor reviews.**
>
> Not because the mailbox is large — it is almost certainly tiny — but because it is the only channel
> that samples **our** users rather than a competitor's, and it is therefore the only evidence here
> not drawn from a population defined by preferring the thing we refuse to build. `n` is not the
> binding constraint on this programme; **population validity is**, and every additional competitor
> review improves the wrong one. That is the argument for reading `support@budgetcrab.app`, and it is
> considerably stronger than *"we haven't looked."*
>
> **This does not retract anything.** No finding above is withdrawn. It fixes what the findings are
> evidence *of*.

> ### 📭 THE MAILBOX HAS BEEN READ. IT IS EMPTY. (recorded 2026-08-13)
>
> The caveat above ends by naming the one thing that could correct it: *"that is the argument for
> reading `support@budgetcrab.app`."* It has now been read. **Founder checked 2026-08-13: zero
> messages since the address shipped 2026-07-29.** Fifteen days, no mail.
>
> **This is recorded as a finding, not as the absence of one.** Every prior version of this
> programme's demand story carried an open item — *"the mailbox is unread, so 'no demand' and 'we
> have not looked' are indistinguishable"* (`FEATURE_PREP_BACKLOG` row-9 standing caveat,
> `RESEARCH_FAMILY_ACCESS_2026-08-12 §"support@budgetcrab.app: still unread"`). That item is closed.
> It did not close the way it was expected to.
>
> **What it establishes, stated plainly, because it changes the standing of everything else on this
> page:**
>
> > **We hold ZERO demand data from our own users.**
>
> Every percentage in this programme — sync **0.28%**, shared access **0.04–0.14%**, the **27%**
> price-rage wedge — comes from the competitor corpus, whose population caveat is recorded
> immediately above. There is now no second channel. The empty mailbox **does not weaken those
> numbers**; nothing about them has changed. What it does is **remove the only channel that could
> have corrected them.** The caveat above is therefore not a temporary condition awaiting a better
> source — it is the standing state of the evidence base, and it will remain so until an instrument
> we build samples our own users.
>
> **Consequence — the 1.0.4 feedback instrument is no longer one source among several.**
> It is the *only* channel that will ever sample **our** users. Two things follow, and both are
> operative now:
>
> 1. **It raises the cost of the §1.1 bias fix riding in the same release.** ⚠️ *That is
>    `DECISION_RECEIPT_INPUT_PRETEST.md` §1.1 — the `usage.ever.splits` mark-before-save bias
>    (fixed `15b646b`), **not** §1.1 of this document, which is about the two zero-row apps.* The fix
>    was already load-bearing because the instrument had never shipped and so no data was
>    contaminated. It is more load-bearing now: a biased instrument was previously one flawed source
>    among several, and is now the sole source. There is no corroborating channel to catch it, and
>    no second instrument that would disagree with it. **1.0.4 must carry that fix**, and that
>    conclusion no longer depends on the pre-test alone.
>
> 2. **It makes `DECISION_RECEIPT_INPUT_PRETEST.md`'s `N ≥ 25` a harder bar than it looked.**
>    That threshold was fixed before any measurement of the install base, and
>    `DECISION_RELEASE_SHAPE_1_0_4 §4` already sized it as an explicit guess needing **~5 000–25 000
>    MAU**, flagged as *"needs validating against App Store Connect before it is relied on."* The
>    empty mailbox is the first real datum bearing on that sizing, and it points the wrong way: at
>    ~3 ratings and zero support mail in fifteen days, the install base is not plausibly near that
>    range. **This strengthens the time-limited "free move" in that document's §4** — amend §4.3
>    clause 2 *before 1.0.4 ships* so a low-N result reads *"no data, no verdict"* rather than KILL.
>    It is legitimate today precisely because no data exists; the receipt forbids that edit once
>    mail starts arriving. A `KILL` returned by an `N` that was never reachable is not a finding
>    about splitting — it is this same empty mailbox, arriving a second time wearing a verdict.
>
> **FOOTNOTE, 2026-08-14 — the mailbox is no longer empty, and the finding stands.**
> One message has arrived: a **known tester** (Anton Kyriachok) reporting a launch bug, not organic
> demand. So the sentence *"zero messages since it shipped"* is now false as of 2026-08-14 and is
> retained above as the state on 2026-08-13; **every consequence drawn from it is unchanged**,
> because a solicited bug report from someone we know is not a sample of user demand. The count of
> organic, unsolicited messages from users we did not recruit is **still zero**. What did change is
> that the channel is now demonstrated to work end-to-end — see
> `DECISION_RELEASE_SHAPE_1_0_4 §"instrument verified in the field"`.
>
> **What it does NOT mean — read this before anyone cites it as reassurance.**
> An empty mailbox at **~3 ratings** is consistent with **a small install base**. It is *not*
> evidence that users have nothing to say, and it is **not satisfaction**. Zero complaints and zero
> requests are what a near-zero denominator produces regardless of what those users think. Reading
> silence as approval here would repeat, on our own data, exactly the inference the caveat above
> forbids on the competitor corpus: mistaking a fact about the population for a fact about the
> product.

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

> ### RULE — supply-side evidence is not demand evidence.
>
> **"Competitors advertise X" tells you what they can build, what differentiates them from each
> other, and what justifies their price. It says nothing about whether our users want X.**
>
> The companion to the zero-row rule above, and the more common failure of the two. A competitor's
> feature list is evidence *about a competitor*. Reading it as demand imports their roadmap, their
> cost structure and their segment — and for a local-first app whose whole thesis is that the
> market's assumptions are wrong, that is exactly the wrong instrument.
>
> This is not a ban on listing reads. A listing is a sound primary source for "what does this app
> advertise" (that is why the MoneyWatch citations survive above). It is unsound as an answer to
> "do our users want this". State which question you are answering.
>
> **Live instance:** signal #9 of `DEMAND_RESEARCH_AND_ROADMAP_2026-07.md` scored iCloud sync as
> **Medium-strong demand** on the sole evidence that two competitors advertise it — while
> `sync_breakage` sits at **66 of 1,804** here, 4%, the second-lowest theme of eleven, and Finding
> #1 above says in as many words that sync pain was overstated. It is struck through there, with a
> supply-side sweep of the whole table beside it.

> ### RULE — never infer willingness-to-pay from how small a feature felt to build. (added 2026-08-13)
>
> **Build effort is an engineering fact about us. Willingness to pay is a market fact about them.
> They are not correlated, and substituting one for the other is silent because both come out as a
> confident sentence about a feature.**
>
> The third member of this set, and the hardest to catch. The zero-row and supply-side rules both
> concern using the *wrong source*; this one is worse, because there is **no source at all** — an
> internal intuition acquires the grammar of a finding on the way to the page, and thereafter reads
> exactly like research.
>
> Effort tells you what a feature costs. It cannot tell you what it is worth to someone who will
> never know how long it took. A feature can be a weekend's work and a decisive purchase trigger; it
> can be a quarter's work and worth nothing. The two questions do not share evidence, so an answer
> to one is never an answer to the other.
>
> **Live instance — and it is inverted, not merely unsourced.**
> `MONETIZATION_FREE_PAID_SPEC.md` keeps the home-screen widget free because *"widgets ranked LOW
> paid-WTP (**aesthetic delight, not killer feature**)"*. That parenthetical is an effort intuition —
> it describes how the feature felt to build. Asked cleanly, `0e5f6bb9` calls home-screen widgets
> highly requested native features and a *"**differentiator for retention and willingness to pay**"*.
> The phrase "aesthetic delight, not killer feature" is in no source.
>
> **The tell to look for:** a rationale that fuses *"does this drive retention?"* with *"would
> someone pay for it?"* into a single verdict. Those have different answers and different evidence.
> The sources scored the widget positively on **both**; our spec collapsed them and got the second
> one backwards. **Separate the two questions and the substitution becomes visible.**
>
> Full working: `AUDIT_FREE_PAID_LINE_PREMISES_2026-08-13.md`. The shipped free widget is **not**
> clawed back — the conclusion may still be right on brand grounds; the reasoning is discarded.

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

> ⚠️ **This section was re-asked claim by claim on 2026-08-13 with conversation history excluded.
> 21 of 64 claims across the programme did not survive; several of them are below.** Content is left
> exactly as written — see `AUDIT_NOTEBOOKLM_CITATIONS_2026-08-13.md` for the per-claim verdicts
> before citing anything on this page. In particular the couples "decisive driver" line **is not in
> the sources** — it was generated in an earlier session and cited back to us as literature, and it
> is the basis of §3's couples reconciliation and §4's Decision 3. **The pricing figures in the
> `0e5f6bb9` paragraph are confirmed and Path A stands.**

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
