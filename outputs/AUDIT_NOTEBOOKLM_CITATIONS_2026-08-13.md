# AUDIT — every NotebookLM citation, re-asked with conversation history excluded

**Date:** 2026-08-13 · **Scope:** both repos (`FinanceTracker`, `budget-crab-internal`)
**Mode:** read-only on the audited documents. **Nothing below has been corrected.** This is the list
the brief asked for; acting on it is a separate decision.

> **Why this exists.** *"NotebookLM: decisive at premium price"* is not in the sources. It was
> generated in an earlier session and cited back to us as literature for six weeks, during which it
> set a feature's priority. A stale comment misdescribes code beside it. This manufactured evidence
> and then admitted it to the canon.

---

## 0. Headline

**64 claims tested across 6 notebooks. 34 CONFIRMED · 9 PARTIAL · 21 NOT IN SOURCES.**

**One in three attributed claims does not survive a clean re-ask.**

The failures are not evenly spread, and that is the most useful thing in this document:

| Notebook | Confirmed | Partial | Not in sources |
|---|---|---|---|
| `04c87827` App Store Marketing & ASO | 7 | 1 | **0** |
| `de492776` iOS Dev & Apple Guidelines | 5 | 0 | **1** |
| `0e5f6bb9` Indie SaaS Sales & Pricing | 9 | 5 | **5** |
| `73afc9a4` Personal Finance App Domain | 9 | 1 | **5** |
| `a16f8bf7` Behavioral Psychology | 2 | 1 | **5** |
| `ff5e0abc` UX & Mobile Design | 2 | 1 | **5** |

**The pattern: hard external numbers survive; interpretive/product claims do not.** ASO and Apple
guidelines — where a claim is a quotable published figure or a rule with a clause number — are
essentially clean. The UX and psychology notebooks, where a claim is a judgement about what users
want, are where the invention happened. **The claims we most wanted to be true are the ones that
failed.**

**The brief's prediction is confirmed, and it is worse than one row.** Backlog rows **#1, #4, #5 and
#9** each rest on at least one failed citation. Row #9 was already struck; **rows #1, #4 and #5 are
newly implicated by this sweep.**

---

## 1. The mechanism, preserved

The archived pre-sweep conversation for `73afc9a4` contains the whole life-cycle of the fabrication.
It matters because it shows this was not a single bad answer — it was a claim that **strengthened**
as it was reused.

**Step 1 — a leading question.** Turn 30 asked:

> *"**How decisive is** couples/shared-household support for budgeting-app adoption vs single-user?
> **Quantify demand** and whether single-user apps succeed without it."*

The question presupposes decisiveness and demands a quantity. The answer obliged:

> *"Support for couples and shared households is a **decisive driver** for adoption in the 2026
> personal finance market, particularly for apps at premium price points."* — cited to `[1]`

**Step 2 — the claim mutates and cites us.** A later turn restated it, silently swapping *adoption*
for *retention*, and citing not a source but the conversation itself:

> *"Budgeting jointly is a **decisive driver for higher app retention** compared to budgeting alone,
> particularly at premium price points **[History]**."*

**`[History]` is the notebook telling us it is quoting our own prior turn back to us.** That marker
is the single most important artefact in this audit: it is the tool being honest about having no
source, in a format that reads exactly like a citation.

**Step 3 — the notebook confesses, and nobody noticed.** A still-later turn in the same archived
conversation says in as many words:

> *"Claims made in our previous conversation regarding joint budgeting as a 'decisive driver' for
> higher retention or its impact on long-term 'stickiness' are **not in the sources**."*

The retraction was already sitting in the transcript. It was never propagated to the four documents
that had by then repeated the claim.

**Step 4 — clean re-ask, three notebooks.** Asked fresh, with history excluded, the claim is
rejected by **every notebook that could plausibly host it** — `73afc9a4` (twice, for adoption and
for retention), `0e5f6bb9`, and `a16f8bf7`. There is no version of it in the corpus.

---

## 2. The list

Verdicts are the notebooks' own, from a fresh conversation (`ask --new`), prompt-constrained to
CONFIRMED / PARTIAL / NOT IN SOURCES with a required quote.

### 2.1 `73afc9a4` — Personal Finance App Domain

| # | Claim as written in our docs | Verdict |
|---|---|---|
| 1 | Couples/shared support is a "decisive driver" at premium price (ADOPTION) | **NOT IN SOURCES** |
| 2 | …the same, framed as RETENTION | **NOT IN SOURCES** |
| 3 | Monarch/YNAB justify $99–109/yr *primarily* through household sharing | **NOT IN SOURCES** |
| 4 | Single-user can win via digital-sovereignty / local-first (Zeroed, Actual) | CONFIRMED |
| 5 | Most abandon manual trackers within two weeks | CONFIRMED |
| 6 | AI-assisted entry (receipt/screenshot/NL, local) = **TOP** manual-app request | **NOT IN SOURCES** |
| 6b | …that it is requested **at all** | CONFIRMED |
| 7 | $58M Plaid settlement | CONFIRMED |
| 8 | 70% of trackers feel anxious | CONFIRMED |
| 9 | Lunch Money 7.8/10 **sustained via** "set your own price" | PARTIAL |
| 10 | YNAB envelope method is the most-recommended method | **NOT IN SOURCES** |
| 11 | Sovereign sync via iCloud/Dropbox is requested | CONFIRMED |
| 12 | Lifetime/one-time pricing is requested (Buckets, Zeroed) | CONFIRMED |
| 13 | CSV / Mint importers are requested | CONFIRMED |
| 14 | On-device OCR is valued specifically for privacy | CONFIRMED |

**#6 is the most consequential single line in this audit, and it needs stating precisely.** The
*feature* has real qualitative support (#6b, #14). The *ranking* does not — and the sources point
the other way. Asked about the top request, the notebook produced a direct counter-example:

> *"The most common request we get is, 'When will you add Plaid for automatic bank sync?' Our answer
> is always the same: we won't."*

So the superlative that made receipt input **backlog row #1** is not merely unsupported: **the one
explicit "most common request" statement in the corpus names a different feature — one we have
deliberately chosen never to build.**

**#9 (PARTIAL) is a causality upgrade.** The 7.8 score and the set-your-own-price model are both
real and both cited; *"sustains … via"* welds them into a causal claim the sources do not make, and
the sources credit customisability and multi-currency too.

### 2.2 `0e5f6bb9` — Indie SaaS Sales & Pricing

**The Path A pricing decision survives.** This is the good news and it is load-bearing: the numbers
that set $4.99 / $34.99 / $99.99 are real.

| # | Claim | Verdict |
|---|---|---|
| 1 | D35 conversion 10.7% vs 2.1% (~5×) | CONFIRMED |
| 2 | D60 RPI $3.09 vs $0.38 (8–9×) | CONFIRMED |
| 3 | Install→trial 9.8% vs 4.3% | CONFIRMED |
| 4 | Payer LTV $62.19 vs $10.69 — "**~7×**" | PARTIAL — source says **~6×** |
| 5 | Low price retains better Y1, 36% vs 23% | CONFIRMED |
| 6 | Access model = conversion not loyalty, 27% vs 28% | CONFIRMED |
| 7 | Brainerr $9.99 lifetime → "**revenue cliff**" | PARTIAL — fact real, phrase is ours |
| 8 | A low anchor makes later raises harder | CONFIRMED |
| 9 | Couples decisive at premium price | **NOT IN SOURCES** |
| 10 | Hard paywall converts **5.5×** better | PARTIAL — source says **5×** |
| 11 | Install→trial **8.9% vs 4.4%** | CONFIRMED |
| 12 | Trial→paid **42–48%** band for a **30-day** trial | PARTIAL — 42.5%/45.7% median for **17–32 day** trials |
| 13 | Feature gates convert 5–10% at moment of intent | CONFIRMED |
| 14 | Teams that experiment earn up to 40× more | CONFIRMED |
| 15 | Gating history is a retention killer / "hostage" sentiment | **NOT IN SOURCES** |
| 16 | Widgets rank **LOW** on paid willingness-to-pay | **NOT IN SOURCES — AND INVERTED** |
| 17 | "Rug-pull" permanently damages the relationship; grandfather users | PARTIAL |
| 18 | Goodbudget free cap (~2 accounts / 15–20 categories) drives upgrades | **NOT IN SOURCES** |
| 19 | Household sharing = highest WTP | **NOT IN SOURCES** |

**#16 is the only INVERTED citation found, and it is a shipped decision.**
`MONETIZATION_FREE_PAID_SPEC.md` keeps the widget free on the stated grounds that *"widgets ranked
LOW paid-WTP ('aesthetic delight, not killer feature')"*. The sources say the opposite:

> home-screen widgets are highly requested native features and a *"differentiator for retention and
> **willingness to pay**"*.

This is worse than an unsupported claim. An unsupported claim is a gap; **an inverted one means the
evidence was consulted and reversed.** Flagging only — the free widget may still be right for brand
reasons, but it is currently justified by a citation that says the reverse.

**#3 vs #11 — not an error, and worth recording so nobody "fixes" it.** `RESEARCH_SYNTHESIS` says
9.8%/4.3%; `MONETIZATION_FREE_PAID_SPEC` says 8.9%/4.4%. The obvious reading is a transposition
typo. **It is not** — the notebook confirmed both, from different sources with distinct quotes. Two
real figures from two studies. Do not reconcile them to one.

### 2.3 `ff5e0abc` — UX & Mobile Design

| # | Claim | Verdict |
|---|---|---|
| 1 | Mobile sessions ~72s | CONFIRMED |
| 2 | **Entry friction is the #1 churn risk** | **NOT IN SOURCES** |
| 3 | One-tap add / auto-save, "Magic Plus" / Things 3 | **NOT IN SOURCES** |
| 4 | Default to "Uncategorized" rather than prompting | **NOT IN SOURCES** |
| 5 | "Mint pattern" predictive modals drive abandonment | **NOT IN SOURCES** |
| 6 | Headspace 96% activation | CONFIRMED |
| 7 | Blinkist +23% trial conversion via **guided onboarding** | PARTIAL — number real, mechanism is **trial paywall optimization** |
| 8 | **Widgets act as contextual triggers** | **NOT IN SOURCES** |

**#2 is cited in more places than any other failed claim** — `SPEC_PHOTO_INPUT.md`,
`FEATURE_PREP_BACKLOG.md` row #1 *and* row #5. It is the load-bearing justification for treating
quick entry as existential. **Note carefully what this does and does not mean:** quick-entry friction
may well be our #1 churn risk. The claim is not disproven — it is **unsourced**, and was presented as
sourced.

**#3, #4, #5 are our own design reasoning wearing a citation.** They are reasonable, specific, and
attributed to a notebook that does not contain them. `#4` in particular describes behaviour the app
actually implements.

### 2.4 `a16f8bf7` — Behavioral Psychology (Money & Subscriptions)

| # | Claim | Verdict |
|---|---|---|
| 1 | Reverse trial lifts conversion 0.4% → 4.5% (11×) via endowment + loss aversion | CONFIRMED |
| 2 | 82–90% of trials start Day 0 | CONFIRMED |
| 3 | **55% of cancellations happen Day 0** | PARTIAL — **3-day trials only** |
| 4 | **Gain-framing** lifts conversion +23% | **NOT IN SOURCES** — the source says **outcome-based messaging** (Strava) |
| 5 | Household sharing = highest WTP | **NOT IN SOURCES** |
| 6 | A "rug-pull" permanently damages the relationship | **NOT IN SOURCES** |
| 7 | Widgets rank LOW on paid WTP | **NOT IN SOURCES** |
| 8 | Gating history is a retention killer | **NOT IN SOURCES** |

**The reverse trial — the actual shipped monetization mechanic — is CONFIRMED.** Its two supporting
numbers hold.

**#3 is a scope error with a live consequence.** 55% Day-0 cancellation is a real figure **for 3-day
trials**. `MONETIZATION_FREE_PAID_SPEC` applies it to our metrics section while specifying a 30-day
StoreKit trial. A 3-day-trial cancellation curve is not evidence about a 30-day trial.

**#4 renamed the mechanism.** `BRIEF_PROACTIVE_ALERTS_V1_0_3.md` designs the alert copy around
"gain-framing" and carries +23%. The number is real; it belongs to *outcome-based* messaging. Whether
our gain-framed copy inherits it is an open question, not a settled one.

### 2.5 `04c87827` — App Store Marketing & ASO — **clean**

All seven substantive numbers CONFIRMED with quotes: 65–70% of downloads from search · Flipster +88%
organic in one month · 38k+ keywords → 10M installs in 8 months · 79–80% check ratings · 3.6→4.2 =
~60% CVR lift · social proof in screenshot 1 up to +90% · up to 70 Custom Product Pages at +5.9–8.6%.

One PARTIAL: *"Reddit/PH = low-to-moderate"* — Product Hunt is supported (*"lots of activity, little
impact"*); **Reddit is not in the sources at all.** Relevant because `LAUNCH_POSTS_REDDIT_X.md` and
`REDDIT_THEME_BANK_TIPS.md` exist.

### 2.6 `de492776` — iOS Development & Apple Guidelines — **one failure**

CONFIRMED with direct guideline quotes: 5.1.1 legal-entity requirement for financial services ·
3.1.2 billed-amount prominence with savings subordinate · trial duration + post-trial price ·
restore mechanism + auto-renewal disclosure · false/misleading pricing is grounds for removal.

| Claim | Verdict |
|---|---|
| Apple **expects `NSFileProtectionComplete`** for sensitive financial data | **NOT IN SOURCES** |

The notebook is precise about why: Guideline 1.6 requires *"appropriate security measures"*; the
specific API is **our** engineering inference presented as an Apple expectation. Low practical risk —
the implementation is defensible regardless — but it is exactly the pattern: a specific, checkable,
authoritative-sounding detail with no source behind it.

---

## 3. Confidence in this audit itself

**The instrument was negative-controlled.** My verification prompts state the claim before asking for
a verdict, which is a leading form — the same defect that produced the original fabrication. So the
sweep was tested with two invented-but-plausible claims mixed with one true one:

- *"Localising screenshots lifts conversion 31%"* → **NOT IN SOURCES**, with the correct nearby
  figures supplied (26%+, 20–40%) and the 31% correctly identified as belonging to a different
  case study.
- *"Apps shipping every 14 days rank 2.3× higher than monthly"* → **NOT IN SOURCES**, with the real
  adjacent facts supplied (2–4 week cadence; 74% of top-1,000 update monthly).
- *"79% check ratings before downloading"* (true) → **CONFIRMED** with quote.

It discriminates. **21 rejections across six notebooks is not an agreeable instrument.**

**Asymmetry to respect when reading the table:** NOT IN SOURCES verdicts are strong — the model
resisted a stated claim. CONFIRMED verdicts are weaker evidence, because the claim was supplied.
Every CONFIRMED above carries a quote, which is the mitigation; where a quote is a close paraphrase
rather than a match, the verdict is recorded as PARTIAL.

**Not covered, so coverage is not overclaimed:** notebooks `0a436b9d`, `2d34868b`, `2fc70c51` (no
substantive claims traced to them in either repo); design-plan claims in
`AppStore/design-references/DESIGN_PLAN_v3.md` attributed to numbered "NotebookLM Q1–Q9" whose
question text no longer exists anywhere; and `DESIGN_SYSTEM.md:7`'s claim that `ff5e0abc` "has full
HIG indexed", which is a claim about a source list rather than about content.

**Also note:** `CLAUDE.md` documents **5** notebooks. **10** exist, and two of the undocumented ones
(`a16f8bf7`, `e4a8bc88`) carry cited claims in `MONETIZATION_FREE_PAID_SPEC.md`.

---

## 4. What rests on nothing

Stated as exposure, not as a recommendation. **Nothing here has been corrected.**

| Backlog row | Its stated evidence | Status after this sweep |
|---|---|---|
| **#1 Photo/receipt input** | *73afc9a4: "AI-assisted entry" = TOP manual-app request; friction = #1 churn risk (ff5e0abc)* | **Both failed.** The feature keeps qualitative support (#6b, #14); **its priority ranking has none**, and the corpus's only "most common request" names bank sync. |
| **#4 Budgets / envelopes** | *NotebookLM: YNAB envelope method most-recommended* | **Failed.** Feature is shipped; the justification was not sourced. |
| **#5 Widgets + Watch + Siri** | *ff5e0abc: quick-entry = top retention lever; friction #1 risk* | **Both failed.** Shipped. Separately, the widget's *free* placement rests on an **inverted** WTP citation. |
| **#9 Couples** | *NotebookLM: decisive at premium price; reviews 69 rage* | **Both failed.** Already struck 2026-08-13. |

**The honest summary:** every one of these features may still be correct. Three of the four are
already built and working. What this audit removes is not the features — it is **the claim that they
were chosen from evidence.** Rows #1, #4 and #5 were argued from numbers that, for the specific
propositions cited, do not exist.

**The one decision that does survive intact is pricing** — Path A rests on nine confirmed figures.

---

## 5. Cross-reference

- `RESEARCH_SYNTHESIS_2026-07-02.md §2` — the canonical "NotebookLM primary findings" section, and
  the origin of most claims audited here. Its §3 reconciliation and §4 **Decision 3** ("Couples: P2
  via CloudKit Shared Database") are both downstream of claim 73afc9a4/#1.
- `FEATURE_PREP_BACKLOG.md` — rows #1, #4, #5, #9.
- `MONETIZATION_FREE_PAID_SPEC.md` — claims 0e5f6bb9/#10–19, a16f8bf7/#1–8.
- `RESEARCH_FAMILY_ACCESS_2026-08-12.md` — the first history-excluded re-probe, which caught this.
- `outputs/AUDIT_BACKLOG_VERIFIED_2026-08-12.md §C.2` — the architectural veto on sharing.
