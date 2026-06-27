# Budget Crab — Keyword Strategy (US / en-US)

**Category:** Finance
**Positioning:** privacy-first · on-device data only · no analytics · no ads
**Differentiation vs Mint/YNAB/Copilot:** lifetime purchase (no subscription) · no account sync required
**Constraints honored:** avoid generic banking terms (no *bank*, *account*, *balance*); target high-intent privacy/offline/no-subscription searches.

> ⚠️ **Data caveat:** The Popularity/Difficulty values below are educated estimates based on category knowledge, NOT pulled from Apple Search Ads. Treat them as a prioritization hypothesis to validate in Astro / AppTweak / App Store Connect Search Ads before finalizing. Everything else (allocation, dedup, char counts, combos) is exact.

---

## App Name (Title) — 25/30 chars

```
Budget Crab Money Tracker
```

Indexes (brand + category, highest weight): **budget · money · tracker** ("crab" = brand). Gives combos "budget tracker," "money tracker," "budget money" for free. No change recommended — it already owns the two strongest generic stems without keyword stuffing.

---

## Subtitle — top 3 candidates (30 chars max)

All three avoid every Title word (budget/money/tracker) — no wasted duplication. First 3 words show in search results, so the lead word is front-loaded for the angle it represents.

### ⭐ A (RECOMMENDED) — max popularity blend — 29 chars
```
Private Expense & Finance Log
```
New words indexed: **private · expense · finance · log**
- **Why:** captures the two highest-volume generic finance stems (*expense*, *finance*) PLUS the privacy wedge (*private*) in one line. Best raw reach.
- Visible trio in search: "Private Expense &…" — leads with the differentiator.

### B — privacy + offline angle — 27 chars
```
Private Offline Expense Log
```
New words indexed: **private · offline · expense · log**
- **Why:** swaps *finance* for *offline* — leans harder into the on-device/offline story. Choose if "offline finance tracker" is your #1 target phrase and you'd rather weight *offline* at subtitle level than keyword level.

### C — differentiator angle — 24 chars
```
Offline Finance, No Sync
```
New words indexed: **offline · finance · sync**
- **Why:** most explicit "no account sync" positioning ("no sync"). Lowest raw volume of the three, but highest intent match for the anti-cloud crowd. Choose if differentiation > reach.

**Recommendation:** ship **A**, move *offline* into the keyword field (below). You lose almost nothing — *offline* still indexes, just at medium weight, and the phrase "offline finance tracker" still forms across fields.

---

## Keywords Field — 100/100 chars (paired with Subtitle A)

```
offline,spending,saving,cash,receipt,subscription,lifetime,secure,personal,bills,wallet,income,daily
```

- Exactly 100 characters, no spaces after commas, no plurals-of-the-same-stem, no stop words.
- **Zero overlap** with Title (budget/money/tracker) or Subtitle A (private/expense/finance/log).
- Carries the two differentiator terms — **subscription** (for "no subscription") and **lifetime** — plus the privacy term **secure** and the offline term **offline**.

If you instead ship **Subtitle B** (which uses *offline*), replace `offline` here with `finance` and add `manual` by trimming `daily` → keep it at/under 100.

---

## Expected high-intent search combinations

Apple combines words across all three fields *within a locale*. Your three target phrases are all covered:

| Target search | Source words | Covered? |
|---|---|---|
| expense tracker private | expense (sub) + tracker (title) + private (sub) | ✅ |
| budget app no subscription | budget (title) + subscription (kw) | ✅ ("app"/"no" auto-handled) |
| offline finance tracker | offline (kw) + finance (sub) + tracker (title) | ✅ |
| private finance / private money | private (sub) + finance (sub) / money (title) | ✅ |
| offline expense / offline budget | offline (kw) + expense (sub) / budget (title) | ✅ |
| lifetime budget / no subscription tracker | lifetime (kw) + budget (title) | ✅ |
| spending tracker / receipt tracker | spending|receipt (kw) + tracker (title) | ✅ |
| personal finance | personal (kw) + finance (sub) | ✅ |
| cash / income / bills tracker | kw + tracker (title) | ✅ |

---

## Ranking rationale (prioritized — estimates to validate)

Opportunity Score = (Pop × 2) − Diff, with skill's sweet-spot bonuses. Grades per keyword-criteria.md.

| Keyword | Field | Est. Pop | Est. Diff | Opp. score | Grade | Rationale |
|---|---|---|---|---|---|---|
| **offline** | kw | 25 | 30 | 40 +20 = **60** | A | Low-competition wedge; few finance apps claim it. Core to positioning. |
| **private** | sub | 30 | 35 | 25 +20 = **45** | B | The differentiator. Rising privacy intent, beatable difficulty. |
| **no subscription** (subscription) | kw | 20 | 25 | 15 +20 = **35** | C→high-intent | Low volume but extreme purchase intent — these searchers want exactly your lifetime model. |
| **lifetime** | kw | 22 | 28 | 16 +20 = **36** | C→high-intent | Same buyer, anti-subscription. Cheap to own. |
| **spending** | kw | 35 | 50 | 20 +10 = **30** | C | Solid generic stem, "spending tracker" combo. |
| **expense** | sub | 55 | 70 | 110 −70 −30 = **10** | D alone | High volume / brand-heavy. Don't try to *win* it — harvest via long-tail combos cheaply at subtitle weight. |
| **finance** | sub | 60 | 78 | 120 −78 −30 = **12** | D alone | Same as expense: harvest, don't fight. Powers "personal/offline/private finance." |
| **receipt** | kw | 40 | 55 | 80 −55 = **25** | C | Decent; "receipt tracker" is a real entry query. |
| **saving** | kw | 45 | 65 | 90 −65 = **25** | C | Broad intent, mid difficulty; ride via combos. |
| **cash / income / bills / wallet / personal / secure / daily** | kw | 25–40 | 45–60 | ~10–30 | C | Long-tail volume fillers; each adds a "X tracker"/"personal finance" combo at low cost. |

**Read:** Win the **A/B-grade niche terms** (offline, private, lifetime, no-subscription) where your app is genuinely differentiated and competition is thin — that's where you can rank top-10 fast. **Harvest the A+-volume terms** (expense, finance, budget) through cross-field combinations rather than head-to-head, since Mint/YNAB/Copilot dominate them directly.

---

## Bonus: cross-localization (zero-risk reach, you already ship these locales)

You ship es / pt-BR / ru `.lproj`. In App Store Connect you can add **es-MX, pt-BR, ru** localizations with **English keywords** — they index for the US storefront too. Use *new, unique* words only (no repeats across any locale). Suggested **second 100-char set** (es-MX, English words, all fresh):

```
envelope,zero,frugal,habit,goal,record,debt,monthly,weekly,planner,category,note,minimal,track,spend
```

Adds method/long-tail terms (envelope budgeting, zero-based, frugal, debt, monthly/weekly) without touching your primary set. Validate char count after final edits; deploy es-MX first, then pt-BR / ru with further unique terms.

---

## Screenshot OCR keywords (June 2025 algorithm — free extra indexing)

Apple OCRs screenshot captions (top/bottom) and indexes them — and *expects* repetition there. Your storyboard captions already do this well: "Your data stays on your iPhone" (private/offline signal), "Export to CSV, PDF, or Excel," "Log spending in seconds." Keep the privacy + spending + offline language in the **first two** screenshots where OCR weight is highest.

---

## Do-not-use list (kept clean)

`bank` · `account` · `balance` (your constraint) · `free` · `best` · `#1` · `app` · competitor names (Mint/YNAB/Copilot) · any price. None appear in any field above.

## Validation checklist before submit
- [ ] Pull real Pop/Diff for offline, private, lifetime, subscription, spending, receipt in Astro/AppTweak and re-rank.
- [ ] Confirm final keyword string = ≤100 chars after any edits (current: exactly 100).
- [ ] Confirm no word repeats across Title → Subtitle → Keywords, and across added locales.
- [ ] A/B test Subtitle A vs B via Product Page Optimization once you have traffic.
