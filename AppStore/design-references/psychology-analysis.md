# Marketing Psychology Analysis — Color & Copy

**Skill:** `marketing-psychology`
**Date:** 2026-06-28 · **Inputs:** `Color+Semantic.swift`, `en.lproj/Localizable.strings`, `.agents/product-marketing.md`
**Lens:** Color psychology for the money context · Sage+Ruler archetype alignment · per-screen emotional response. Analysis only.

---

## 1. Color psychology — the money context

### The standout decision: terracotta, not alarm-red (keep, and protect)
`bcExpense` is a muted burnt-terracotta (`0.75,0.33,0.24` light), explicitly *not* `.red`. This is the single best psychological choice in the app:

- **Loss aversion / avoidance.** Alarm-red on every expense triggers the loss-aversion pain response (~2× gain). People *avoid* finance apps that make them feel bad — the classic "I don't want to look at my spending" loop. Terracotta lets users look at spending without flinching, which directly serves retention (the North Star depends on sustained tracking).
- **Archetype fit.** Calm, non-judgmental, premium = **Sage** (wisdom without scolding) + **Ruler** (composed authority). Alarm-red would be Caregiver-panic or Outlaw — off-brand.
- **Craft as authority signal.** The light/dark-adaptive tuning + 4.5:1 contrast intent reads as competence (authority bias) the moment a careful user notices it.

Income emerald/mint = growth, gain, "go" — conventional and correct. Brand mint reinforces freshness/calm.

### Where color psychology breaks
- **Tutorial uses raw `.red` for the expense preview** (`TutorialPage1`). The *first* expense a new user ever sees is alarm-red — contradicting the calm terracotta the whole product is built around. The emotional promise is broken before the user reaches the app.
- **Tutorial dark-purple gradient** (`0.11,0.09,0.22`). Purple signals luxury/mystery, but here it reads as generic "tech onboarding" and diverges from the light, airy, trustworthy palette everywhere else. It under-delivers the *specific* Quiet-Premium-calm feeling and mildly fractures brand recognition (mere-exposure works against you when the intro looks like a different app).

---

## 2. Sage + Ruler archetype alignment (copy)

**Strong alignment (keep):**
- **Sage** ("see / understand / insights"): `"spot where money leaks"`, `analytics.empty.caption` "see your spending patterns", the calm Help articles. Knowledge-as-value, no hype.
- **Ruler** (control / ownership / sovereignty): `"Your data stays yours"`, `"Your Data Stays on Your Device"`, `quick_entry.privacy_chip` "Stays on your iPhone". Ownership and command = textbook Ruler.
- **Voice discipline:** I found **zero exclamation points** in the strings — the voice rule is genuinely respected. Tone is calm-confident throughout.
- **Architecture-first privacy** ("no accounts, no servers, never leaves your device") = Ruler sovereignty + Sage truth, exactly the documented DuckDuckGo template.

**Misalignments (fix):**
- **"Smart insights coming soon"** (`dashboard.day0.title`) violates two rules at once: "smart" is on the **avoid list**, and "coming soon" is a hype-y promise the Sage archetype shouldn't make. (The *body* string is better.)
- **"We figure out the category" / "we'll do the rest"** — the actor is "we," which subtly implies a remote brain processing your data. For a privacy/Ruler brand whose whole claim is "no one can see this," the on-device actor should be **Budget Crab / your iPhone**, never "we." Small words, but they quietly undercut the core differentiator.
- **`general.language_hint` = "Language switching will be fully enabled when localization keys are added."** This is a developer-facing artifact leaking to users — breaks the competent-Sage spell entirely (see copywriting analysis).

---

## 3. Per-screen emotional response (predicted)

| Screen | Dominant emotion | Driver | Risk |
|---|---|---|---|
| Onboarding (2 steps) | Calm, in-control | Low activation energy, defaults pre-filled | None — strong |
| Dashboard (hero) | Pride / reassurance | Green net + terracotta-not-red losses | 4 stacked gray sub-lines add mild cognitive load |
| Analytics (Pulse/Breakdown/Horizon) | Mastery + curiosity | Interactive scrub = IKEA effect, "my data" endowment | None — a peak moment |
| QuickEntry | Competence + safety | Fast entry + "Stays on your iPhone" chip | None — strong |
| Paywall | Low emotional charge | Text-only, plumbing features | Under-converts (see paywall analysis) |
| Tutorial | "Premium but generic" | Purple world, red expense | Palette/promise mismatch |
| AuthGate (locked) | Neutral/cold | Plain lock, secondary gray | Minor friction, no warmth |

---

## 4. Psychology levers — used well vs. left on the table

**Already used well (keep):**
- **Goal-gradient + Zeigarnik:** `"Add %d more transactions to see your first insight"` is a textbook progress-pull. Excellent.
- **Loss aversion + scarcity:** Lifetime "Subscription pricing may rise" + "Founder's Edition."
- **Zero-price / endowment:** free tier (10 tx/mo) + 7-day trial give users something to own and lose.
- **Reciprocity:** unusually generous in-app Help + genuine privacy = goodwill before any ask.

**Underused (opportunity):**
- **Endowment at the ask.** The paywall never references the data the user already created ("Keep all 47 of your transactions"). Peak-end + endowment are free here.
- **Authority/unity via the indie story** — correctly *silent in-app* per channel rules, but the **About** screen is the sanctioned place and currently underplays "built independently" (a Ruler/unity trust asset). (Also note: About still shows `"FinanceTracker"`, not Budget Crab — see copywriting.)
- **Social proof:** absent everywhere (consistent finding). Add only truthful signals when they exist.

---

## TOP 5 ACTIONABLE IMPROVEMENTS

1. **Make the tutorial obey the app's color psychology (P1).** Replace raw `.red` with `bcExpense` terracotta and re-skin the purple gradient toward the light Quiet-Premium palette, so the first expense and first impression match the calm, premium feeling the product is built on.

2. **Purge "smart" and "we" as the on-device actor (P1).** Rewrite `dashboard.day0.title` ("Insights unlock as you track") and switch parsing copy from "we figure out" to "Budget Crab reads it on your iPhone." Aligns voice rules + reinforces the privacy differentiator instead of quietly eroding it.

3. **Protect the terracotta decision (P0 — guardrail).** Document `bcExpense ≠ red` as an intentional psychological rule so no future "make expenses pop" change reintroduces alarm-red. This calm-loss palette is a retention asset.

4. **Use endowment at the paywall (P2).** Reference the user's own accumulated data in the upgrade ask ("Keep every one of your N transactions"). Couples with the paywall analysis's value-preview recommendation.

5. **Lighten the Dashboard hero's emotional load (P2).** Collapse the four secondary gray lines to one so the dominant emotion (pride/reassurance) isn't diluted by cognitive load — peak-end favors a single clear focal point.

---

**Bottom line:** the *color* psychology is genuinely sophisticated (terracotta-not-red is a competitive-grade decision) and the Sage+Ruler voice is mostly disciplined. The leaks are concentrated in (a) the tutorial, which speaks a different visual+color language, and (b) a few copy strings where "smart"/"we" quietly fight the brand's own privacy promise.
