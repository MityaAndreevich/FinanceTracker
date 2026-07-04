# Budget Crab — Stage-1 Search Demand & SEO-driven Features

**Date:** 2026-07-02 · Method: App Opportunity Factory Stage-1 (search demand → ASO + feature priorities). We go partly FROM user search queries.
**Evidence tier:** directional (WebSearch + ASO-guide sources). ⚠️ Real search-VOLUME needs an ASO tool (AppTweak/Sensor Tower) or an App Store **autocomplete scrape** — flagged as a Claude Code task (§5). Treat rankings as intent signals, not hard volume.

## 1. Core doctrine (new): a feature should also be a search term
Prioritize features that are ALSO high-intent search queries. Then each feature becomes an ASO keyword we can rank for + a listing bullet. Build partly from what people type into the search bar.

## 2. Keyword clusters (by intent, with our fit)
| Cluster | Example queries | Competition | Our fit |
|---|---|---|---|
| **No-bank / privacy** ⭐ | "budget app without bank linking", "expense tracker without bank", "budget app not linked to bank", "private budget app" | Mid (niche) | ✅ EXACT positioning — own this |
| **Receipt scanning** ⭐ | "app that scans receipts for budget", "receipt scanner budget app" | Mid | ✅ Photo-input feature (on-device) — searched! |
| **Envelope / cash** | "envelope budget app", "cash envelope method app" | Mid | ✅ Budgets/envelopes feature |
| **Head terms** | "expense tracker", "money manager", "budget app" | High | Support via subtitle, don't lead |
| **Free** | "free budgeting app", "track money without paying" | High | ⚠️ we're freemium — target "free expense tracker" honestly (free tier exists) |
| **Couples/family** | "budget app for couples", "family budget app" | Mid | ⚠️ P2 (CloudKit) — keyword unlocks once shipped |
| **Widget** | "budget widget", "expense tracker widget" | Low-mid | ✅ Widgets feature (pre-launch) |
| **AI / voice entry** | "AI expense tracker", "voice budget app" | Low-mid | ✅ Voice (have) + NL quick-add |
| **Long-tail** | "expense tracker for freelancers", "budget app for college students", "monthly expense tracker" | Low | ✅ CPP/keyword long-tail plays |

⭐ = our wedge clusters — highest priority for both ASO and features.

## 3. Searched features → build priority (SEO-driven reprioritization)
These features are BOTH demanded (our review mining) AND searched (this Stage-1) = double-validated. Each is a keyword we can then rank for:
1. **Receipt scanning (photo input)** — searched directly ("app that scans receipts"). Confirms `SPEC_PHOTO_INPUT.md` as a headline. On-device = privacy-unique. (Build v1.1; but it's a marquee ASO term.)
2. **No bank linking / private** — searched heavily. Not a "feature to build" (we already ARE this) but the #1 ASO term — must be in title/subtitle/keywords.
3. **Envelope / cash budgeting** — searched (Goodbudget's turf). → prioritize Budgets/envelopes (#4) — also feeds the redesign hero. Pre-launch.
4. **Widgets** — searched, low competition → easy ASO win. Pre-launch (also a retention lever).
5. **Voice / AI entry** — searched; we have voice, add NL quick-add later.
6. **Couples/family** — searched; unlocks the keyword when we ship CloudKit sharing (P2).

## 4. Direct competitive set (our REAL niche — not YNAB/Monarch)
Search surfaced our true rivals in the privacy/manual/no-bank niche:
- **Finny** — bankless, **AI text input + receipt scanning + screenshot imports**, no subscription. Our closest analog AND biggest threat — they already ship receipt scan + AI entry. Differentiate on: fully **on-device** (verify theirs isn't cloud), polish, crab brand, honest pricing.
- **Skwad** — privacy via bank email-alert parsing (different mechanism).
- **Koody** — bankless, quick entries, receipts, export.
- **Goodbudget** — envelope method, couples/family.
Implication: the no-bank niche is real and contested. Our edge must be **on-device privacy + design (post-redesign) + billing honesty + price** — not just "no bank" (others say that too).

## 5. ASO recommendations (feed the metadata copy pack)
- **Title (30):** brand + strongest searched term, e.g. `Budget Crab: Private Money` or `Budget Crab: Expense Tracker`.
- **Subtitle (30):** pack a searched cluster, e.g. `No bank linking · Receipts · Widget`.
- **Keyword field (100):** `no bank,private,expense tracker,money manager,receipt,envelope,cash,widget,offline,voice,subscriptions,spending` (exclude words already in title/subtitle).
- **Custom Product Pages (organic):** one per long-tail cluster (freelancers / students / couples-later) — Apple allows up to 70 organically indexable.
- **Ratings first:** per 04c87827, 3.6→4.2 = +60% CVR — the redesign + in-app review prompt matter as much as keywords.

## 5b. ⚠️ Upgrade to real volume (Claude Code task, model Sonnet)
Scrape App Store search autocomplete for seed terms per storefront (US/GB/CA/AU + DE/BR/MX localized) via the iTunes hints endpoint, rank by suggestion frequency, and cross-check with an ASO tool trial if available. The Cowork sandbox can't hit the hints endpoint reliably; run in Claude Code. Output → refine §2/§3.

## 6. Net implication for the plan
- **Pre-launch features that are ALSO top ASO terms:** Budgets/envelopes (#4), Widgets (#5). Do these WITH the redesign so screenshots + keywords land together.
- **v1.1 marquee:** Receipt scanning (searched + demanded + on-device).
- **ASO copy** must lead with "no bank linking / private" (our uncontested-ish wedge) + receipts + widget.
- **Threat watch:** Finny already ships AI entry + receipt scan — our redesign + on-device story must be clearly better, not just present.

## Sources
[NerdWallet best budget apps](https://www.nerdwallet.com/finance/learn/best-budget-apps) · [Finny — track without bank](https://getfinny.app/blog/track-expenses-without-linking-bank) · [Finny — receipt scanning](https://getfinny.app/blog/app-that-scans-receipts-for-budget) · [Koody](https://koody.com/blog/budgeting-app-without-bank-linking) · [Skwad](https://skwad.app/) · [WalletHub — no bank link](https://wallethub.com/answers/b/best-free-budget-app-not-linked-to-bank-account-2140877671/) · [AppTweak — keyword tools](https://www.apptweak.com/en/aso-blog/best-aso-keyword-research-tools)
