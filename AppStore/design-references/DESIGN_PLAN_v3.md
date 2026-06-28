# Budget Crab — Design Plan v3 (FINAL — decision-ready)

**Date:** 2026-06-28
**Status:** DRAFT — awaiting user approval before execution
**Major shift from v2:** From "7-10 day redesign" к "3 waves polish, submit after Wave 2"
**Source data:** 5 NotebookLM Phase 1 + 10 Phase 2 + Lifehacker RU + ChatGPT critique + Claude Code 5-skill SYNTHESIS_ANALYSIS.md

---

## TL;DR — what changed from v2

ChatGPT и Claude Code analysis revealed что **fundamental rewrite NOT needed**:

1. Token system + voice **already exist** — discipline gap, not architecture gap
2. Most fixes are **application** не invention → LOW RISK
3. Privacy promise undercut by **few copy leaks** — trivial fixes
4. **Wave 1 includes submission BLOCKER** (wrong brand name в user-visible strings)
5. Can submit after **Wave 2** (~5-7 days), Wave 3 ships as v1.0.1

**Repositioning shift:** "Friendly minimalist" → **"Calm private money tracker с warm mascot layer"** (ChatGPT critique)

---

## Strategic reframe (per ChatGPT critique)

### NOT: Friendly minimalist mascot finance app
### YES: Calm private money tracker с warm mascot layer

**Order matters:** money → clarity → privacy → trust → then crab + cream + rounded.

### Core principle: **Calm clarity > cute friendliness**

Premium = **quieter, not richer.** Restraint over decoration. Privacy as #1 signal, mascot as accent layer.

---

## 3-Wave execution plan (replaces v2's monolithic redesign)

### 🌊 Wave 1 — Pre-submission (1-2 days, all LOW effort)

**6 fixes, mostly copy/layout. One is a SUBMISSION BLOCKER.**

| # | Fix | Effort | Why critical |
|---|---|---|---|
| **1** | **🔴 Fix dev artifacts + wrong brand name** | L | **Submission blocker.** "FinanceTracker" visible в exported PDFs |
| 2 | Paywall benefit-led headline + privacy line + reorder features | L | Privacy = #1 differentiator absent from paywall |
| 3 | Paywall price framing ("Best value" + "Save 42%" per-month) | L | Standard CRO win, copy-only |
| 5 | Drop "smart"/"power features" copy; "we" → on-device actor ("Budget Crab reads it on your iPhone") | L | Aligns voice + reinforces privacy |
| 10 | Simplify Dashboard hero (collapse 4 gray lines к amount + 1) | L | Per ChatGPT: "fewer surfaces, more whitespace, ONE hero metric" |
| 11 | De-dupe Dashboard empty-state copy + finish Source→Account rebrand | L | Quick consistency wins |

**Wave 1 outcome:** Polished, voice-consistent, privacy-coherent app ready для submission.

**Locale parity:** preserve 459 keys × 4 locales. Wave 1 edits existing strings, doesn't add/remove.

### 🌊 Wave 2 — Token + craft pass (2-3 days, mechanical)

**Apply existing token system app-wide. 70% of views currently bypass tokens — fix that.**

| # | Fix | Effort | Source |
|---|---|---|---|
| 4 | Adopt existing design tokens app-wide — kill 5× `mintColor` + `paywallMint` → `Color.brand`; route cards through `.cardSurface`; amounts → `Font.bcAmount/bcDisplay` | L-M | design skill |
| 12 | Raise donut legibility — lift opacity floor (~0.5) для top slices | L | design skill |
| 13 | Dynamic Type adoption — `.font(.system(size:))` → text styles / `relativeTo:` | M | HIG baseline |

**Wave 2 outcome:** Token discipline app-wide. Visual consistency. Accessibility upgraded.

**Additional polish per ChatGPT критика:**
- SF Pro Display Rounded **ONLY**: hero amounts + CTAs + onboarding + empty states
- SF Pro Text для lists/settings/legal
- **Monospaced digits** для all money values (precision feel)
- Background: very subtle cream (NOT obvious cream)
- Mint as accent NOT в text body
- Mascot **strictly 4 places**: welcome, no-transactions empty, no-categories empty, About

### 🌊 Wave 3 — Growth bets (5-7 days, validate via TestFlight)

**HIGHER effort, HIGHER upside. DEFER к v1.0.1.**

⚠️ **No analytics SDK** (privacy by design) → validation only via TestFlight cohorts + qualitative beta, не A/B production funnels.

| # | Fix | Effort | Why defer |
|---|---|---|---|
| 6 | Paywall value demonstration — screenshot strip / one-line outcome preview above plan cards | M | "Show, don't tell" — biggest paywall lever |
| 7 | Make first-run interactive — first transaction IS tutorial | M-H | Time-to-value top retention driver |
| 8 | Re-skin tutorial к app palette (drop purple, replace `.red` с `bcExpense` terracotta) | M | First impression matters |
| 9 | Surface + prime voice в first-run (interactive mic + permission priming) | M | Most differentiated "magic" missed в session 1 |
| 14 | Auto-detect language; cut a pre-value config screen | M | Less friction; де-risks sheet timing |
| 15 | Promote "Explore с sample data" к first-class onboarding fork | M | Peak-end moment |

**Wave 3 ships as v1.0.1** (week +2-3 post-launch).

---

## Updated design tokens (per ChatGPT + NotebookLM)

### Typography (REVISED per ChatGPT)

| Usage | Font | Why |
|---|---|---|
| **Hero amount** (QuickEntry, Dashboard) | **SF Pro Display Rounded Semibold 60pt** | Warm + premium |
| **Large titles** (screen headers) | **SF Pro Display Semibold 34pt** | NotebookLM Q1: anchor hierarchy |
| **All money values** | **SF Pro + `.monospacedDigit()`** | Precision feel, не jittery |
| **Lists, settings, legal, body** | **SF Pro Text Regular** (not Rounded) | Per ChatGPT — keeps precise |
| **CTAs (primary buttons)** | **SF Pro Display Rounded Semibold 17pt** | Friendly handles |
| **Captions** | **SF Pro Text Regular 12pt + 70% opacity** | Subtle |

❌ NEVER: Ultralight/Thin weights (NotebookLM Q2 — "frail")

### Color (REVISED)

| Token | Light | Dark | Use |
|---|---|---|---|
| Brand mint | `#3DDC97` | `#66D69E` (muted) | Accent ONLY, never body text |
| Background light | **Very subtle cream** `#FCFBF9` (not `#FAF7F2`) | `#1A1A1C` charcoal (NOT pure black) | Per NotebookLM Q9 + ChatGPT |
| Card surface | white `#FFFFFF` | `#212123` elevated | "Lighter = closer" |
| Income | emerald `#1A8F61` | mint `#66D69E` | Hierarchical opacity для chart series |
| **Expense** | **terracotta `#BF5430`** | warm clay `#E8876F` | ⚠️ NOT alarm-red — competitive-grade choice per Claude psychology analysis |
| Separators | OMIT mostly | OMIT mostly | Per Things 3 zero-border pattern |

### Spacing/Radius/Elevation

Keep current `Spacing.*`, `CornerRadius.*`, `Elevation.*` tokens (already exist).
**Wave 2 = enforce их application, не redefine.**

### Motion (NEW concrete implementations)

Per NotebookLM Q4:

```swift
// Number ticker (Dashboard hero amount)
Text(balance, format: .currency(code: "USD"))
    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
    .monospacedDigit()
    .contentTransition(.numericText(value: balance))
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: balance)

// Source-linked sheet (QuickEntry from "+" button)
// Parent:
Button { showQuickEntry = true } label: { Image(systemName: "plus.circle.fill") }
    .matchedTransitionSource(id: "quick.entry", in: namespace)
// Sheet:
.navigationTransition(.zoom(sourceID: "quick.entry", in: namespace))

// Haptics
.sensoryFeedback(.success, trigger: transactionSaved)
.sensoryFeedback(.impact(weight: .medium), trigger: categoryDeleted)
.sensoryFeedback(.error, trigger: validationFailed)
.sensoryFeedback(.selection, trigger: selectedCategory) // tap select

// Skeleton (Dashboard initial load)
HStack { /* placeholder */ }
    .redacted(reason: isLoading ? .placeholder : [])

// Timing
.spring(response: 0.3, dampingFraction: 0.7) // standard
.spring(response: 0.3, dampingFraction: 1.0) // critical-damped (reduced motion)
// Keep secondary transitions 0.25-0.35s
```

---

## Mascot integration scope (STRICT per ChatGPT)

### ✅ USE mascot ONLY here (4 places):

1. **Welcome screen** (onboarding step 1)
2. **No-transactions empty state** (Dashboard когда нет данных)
3. **No-categories empty state** (Categories screen)
4. **About page** (Settings → About)

### ❌ DO NOT USE:
- ❌ After every transaction save (intrusive)
- ❌ Privacy section ("treasure chest" cliché)
- ❌ Analytics screens (data focus)
- ❌ Paywall (dilutes premium)
- ❌ Permanent header navigation
- ❌ Speech bubbles / "crab says…" copy

**Rationale (ChatGPT):** Budget Crab должен быть "finance tool with mascot, not mascot app with finance."

---

## Privacy Center promotion (per ChatGPT — main premium signal)

**Privacy Center > Mascot** as premium differentiator.

### Settings hierarchy:

```
Settings
├── Privacy & Data  ← TOP, NEW prominence
│   ├── "Your transaction data stays on this iPhone"
│   ├── ✓ No bank linking
│   ├── ✓ No cloud account
│   ├── ✓ No Budget Crab servers for transaction data
│   ├── ✓ No ads
│   └── ✓ No third-party analytics
├── Appearance (theme, language)
├── Notifications
├── Premium / Subscription (founder's pricing reminder)
├── About (Tell a Friend + Rate the App)
└── Help & Support
```

**Visual style:** Luxury trust card, NOT legal text. Concise, confident, restrained.

---

## Onboarding flow (per ChatGPT + NotebookLM Q6)

**Reframe:** "Take a tour" → **"Add first transaction"**

### Flow (3 screens max per NotebookLM optimal activation):

1. **Welcome + privacy promise**
   - Crab mascot, "Budget Crab" name, 1-line privacy headline
   - Single button: "Get started"

2. **Confirm currency/language** (auto-detect; user confirms)
   - Large cards (not wheel picker per past learning)
   - 4 currencies prominently displayed

3. **Primary: "Add first transaction"** | Secondary: "Explore demo"
   - Primary CTA goes к QuickEntry (filled state)
   - Secondary loads demo seed data (allows clearing later)
   - **NOT requiring Face ID, NOT requiring account**

After first transaction: **Spring transition** к Dashboard, success haptic.

**NO hard paywall before value.** Soft mention в Settings и contextually.

---

## RU pricing (corridor confirmed per ChatGPT)

| Tier | US | **RU custom** | Why |
|---|---|---|---|
| Monthly | $4.99 | accept auto-conversion | Less critical |
| Yearly | $34.99 | check, possibly custom | Mid-tier matters |
| **Lifetime** | $99.99 | **2990-3990₽** | Mid-range RU: between CoinKeeper (1690₽) и Wallet (4490₽). NOT cheapest, NOT most expensive. Position: "local pricing, не скидка" |

Apple ASC supports per-territory pricing manually. Apply Wave 2 timeline.

---

## Wave 1 detailed brief (для Claude Code execution)

### Wave 1 step-by-step:

```
WAVE 1 BRIEF — pre-submission polish + submission blocker fix

6 fixes. ALL low effort. ALL copy/layout (mostly). Constraints: build green, tests green, locale parity 459 keys × 4 locales preserved (edit existing keys, don't add/remove).

═══════════════════════════════════
Fix #1 (🔴 SUBMISSION BLOCKER): Brand-name leaks
═══════════════════════════════════

Replace "FinanceTracker" → "Budget Crab" and purge dev-TODO content в these 5 locale keys (all 4 locales):
- general.language_hint → user-friendly hint, no internal name
- about.privacy_hint → privacy promise in voice
- about.app_name → "Budget Crab" (NOT FinanceTracker)
- settings.privacy.subtitle → privacy tagline
- pdf.report.title → "Budget Crab Report" / "Отчёт Budget Crab" / "Reporte Budget Crab" / "Relatório Budget Crab"

Commit: "fix(i18n): replace dev-artifact + FinanceTracker brand-name leaks (submission blocker)"

═══════════════════════════════════
Fix #2: Paywall benefit-led headline + privacy line + reorder
═══════════════════════════════════

Edit PaywallView strings (4 locales):
- Headline: benefit-led, NOT plumbing. E.g.: 
  - EN: "Own your money, on your iPhone forever"
  - RU: "Финансы под вашим контролем, навсегда на iPhone"
  - ES: "Tu dinero, en tu iPhone para siempre"
  - PT-BR: "Seu dinheiro, no seu iPhone para sempre"
- ADD privacy line above features: "Everything stays on your iPhone." / "Всё остаётся на вашем iPhone." / "Todo se queda en tu iPhone." / "Tudo fica no seu iPhone."
- REORDER feature list: lead с unlimited + forever + privacy. Demote "custom fields", "advanced filters" к bottom.

Constraint: DO NOT change pricing copy (Founder's Edition just shipped). Only headline + privacy line + feature ORDER.

Commit: "design(paywall): benefit-led headline + privacy line + reordered features"

═══════════════════════════════════
Fix #3: Paywall price framing
═══════════════════════════════════

Add к Yearly tier card в PaywallView:
- "Best value" badge (yellow/mint accent)
- "Save 42%" text
- "$2.92/month, billed annually" affordability framing

⚠️ NO false anchoring (Apple §2.3.1(a)). "Save 42%" must be true math vs monthly.

Localize all 4.

Commit: "design(paywall): yearly best-value badge + save% + per-month framing"

═══════════════════════════════════
Fix #5: Voice cleanup — drop "smart"/"power features", "we" → on-device
═══════════════════════════════════

Find any string в .lproj containing:
- "smart" — replace с specific feature description
- "power features" — replace с specific feature names
- "we'll do" / "our servers" / "we automatically" — reframe к на-device actor

Example:
- ❌ "We'll automatically save your transactions"
- ✅ "Budget Crab reads it on your iPhone — nothing leaves your device"

Audit все 4 locales для these patterns. Replace contextually.

Commit: "i18n: voice cleanup — на-device actor + drop hype language"

═══════════════════════════════════
Fix #10: Dashboard hero simplification
═══════════════════════════════════

DashboardView currently has 4 secondary gray lines below hero amount. Reduce к amount + 1 line (most informative — likely "Spent this month" or "Net change vs last month").

ONE hero metric. Generous whitespace around it. Don't break layout.

Commit: "design(dashboard): single hero metric + 1 supporting line (was 4)"

═══════════════════════════════════
Fix #11: Dashboard empty-state + finish Account rebrand
═══════════════════════════════════

1. DashboardView empty state: de-dupe copy (currently 2 competing voices). Pick voice consistent с product-marketing.md Sage+Ruler.
2. Find `edit.source.picker` key (and any remaining "Source" references in user-visible strings) — finish rebrand к "Account" / "Счёт" / "Cuenta" / "Conta".

Commit: "i18n: Dashboard empty-state voice + finish Source→Account rebrand"

═══════════════════════════════════
WAVE 1 FINISH:
═══════════════════════════════════

- Run xcodebuild + full test suite
- Verify 459 keys × 4 locales parity (zero net change in count)
- Regenerate screenshots ALL (4 locales × 8 screens = 32) via capture-screenshots.sh
- Visual smoke check: Paywall, Dashboard, Settings, About all show "Budget Crab" не "FinanceTracker"

Estimated: 1-2 days total Claude Code work.
```

---

## Wave 2 detailed brief (when Wave 1 done)

Brief к be written after Wave 1 review. Will cover:
- Token application sweep (mintColor → Color.brand etc.)
- Donut chart opacity floor
- Dynamic Type adoption
- Plus per-territory pricing setup в ASC (RU 2990-3990₽)

---

## Wave 3 plan (v1.0.1 release, week +2)

Brief к be written 2 weeks post-launch based on:
- TestFlight qualitative feedback
- Actual user reviews
- First-week metrics (manual analysis since no analytics SDK)

Focus areas: paywall value demo + interactive onboarding + voice priming.

---

## Decision gate — APPROVE before Wave 1 execution

### What I need from you (5 yes/no):

1. **Approve 3-Wave strategy?** (Wave 1 + Wave 2 → submit, Wave 3 = v1.0.1)
2. **Wave 1 scope OK?** (6 fixes, ~1-2 days)
3. **Mascot scope strict к 4 places only?** (per ChatGPT)
4. **Privacy Center promoted к Settings top + luxury trust card style?**
5. **Submission target ~7 days from now (Wave 1+2 complete)?**

### After approval:

1. Claude Code executes Wave 1 (paste brief above)
2. I review Wave 1 output → write Wave 2 brief
3. Claude Code executes Wave 2
4. Per-territory pricing setup в ASC (RU custom)
5. Final visual review + screenshots regen
6. ASC submission flow (IAPs + screenshots + metadata + archive + submit)
7. After approval: Wave 3 brief planning

### If iterate:

Tell me what к change. I revise Plan v3 → re-present. No execution until approved.

---

## Risk assessment

### Wave 1 risks: VERY LOW
- All copy/layout edits. Mechanical.
- Build/tests guard everything.
- Submission blocker fix is required regardless.

### Wave 2 risks: LOW
- Mechanical token replacement.
- Dynamic Type might surface accessibility size clipping (good — fix as discovered).

### Wave 3 risks: MEDIUM-HIGH
- Paywall value demo требует design iterations (multiple drafts)
- Interactive onboarding = bigger architectural change
- Validate via TestFlight, не launch как experimental

### Schedule risk: LOW
- 1-2 weeks total realistic
- Vs original 7-10 day blind redesign — better outcomes, less risk

---

## Sources

- `design-skill-analysis.md` (Claude Code)
- `paywall-analysis.md` (Claude Code)
- `psychology-analysis.md` (Claude Code)
- `onboarding-analysis.md` (Claude Code)
- `copywriting-analysis.md` (Claude Code)
- `SYNTHESIS_ANALYSIS.md` (Claude Code top 15)
- 5 NotebookLM Phase 1 queries (D1-D5)
- 10 NotebookLM Phase 2 queries (deeper)
- Lifehacker RU top-10 finance apps article
- ChatGPT critique (11 specific revisions)
- DESIGN_EXPLORATION.md (initial 4 direction comparison)
- DESIGN_PLAN_v2.md (superseded by this v3)
