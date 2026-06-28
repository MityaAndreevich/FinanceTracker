# Budget Crab — Design Plan v2

**Date:** 2026-06-28
**Status:** DRAFT — awaiting user approval before execution
**Source data:** 5 NotebookLM queries + 3 ui-ux-pro-max alternatives + lifehacker.ru RU market analysis + bug-fix observations

---

## 1. Problem statement

User feedback after overnight design polish:
> "нужно вообще проанализировать и проработать редизайн на дружелюбный и минималистичный, выглядит тяжелым и примитивным"

Translation gap analysis:
- **"Тяжёлым"** = visual weight excessive. Density of info, contrast too strong, layout cramped
- **"Примитивным"** = looks unfinished или generic. Lacks polish that signals "$99 lifetime tool"
- **Wanted:** friendly + minimalist + premium (not infantile, not corporate, not sterile)

---

## 2. Validated principles (from 5 NotebookLM queries)

### From Q-D1 (Anxiety vs Calm)

1. ✅ **No systemRed для money signals** — terracotta is correct (color-blind safe + не alarm)
2. ✅ **Hierarchical rendering > rainbow categories** — use opacity layers of brand mint
3. ✅ **Spring transitions > sharp** — source-linked sheet presentations
4. ✅ **Soft icons** — concentric radii, sharper details (post-iOS 27 corrected Liquid Glass)
5. ❌ **Avoid confetti celebrations** if event isn't meaningful — feels cheap

### From Q-D2 (Heavy vs Light)

6. ✅ **Gist before minutiae** — single high-contrast hero metric первый, drill для details
7. ✅ **Large Titles 34pt+** для primary screens (Apple HIG modern standard)
8. ✅ **SF Pro Rounded** — coordinates с soft UI elements, "warm" voice + secure archetype
9. ✅ **Generous vertical padding** (Calm-style tranquility)
10. ✅ **Zero-borders** (Things 3 pattern) — shadow elevation > harsh borders
11. ❌ **Avoid Ultralight/Thin weights** — "frail" feeling

### From Q-D3 (Friendly vs Cold Minimalism)

12. ✅ **Mascot OK if structural** — like Duo (Duolingo), Little Finder Guy
13. ✅ **Custom illustrations** (Headspace pattern) — ground в success narrative
14. ✅ **Capsule shapes** для primary interactive controls
15. ❌ **Avoid exclamation points + "sympathy appeals"** — high-arousal anti-patterns

### From Q-D4 (Premium Signals)

16. ✅ **Typography weight Regular/Medium/Semibold** — Ultralight = frail
17. ✅ **Haptic reinforcement** for success interactions
18. ✅ **Custom hero illustrations** (не just SF Symbols)
19. ✅ **Spacing as primary tool** + zero-borders (Things 3 reference)
20. ✅ **Pixel-perfect alignment** — concentric radii math-aligned

### From Q-D5 (2026 UX Best Practices)

21. ✅ **Demo Mode > Plaid wall** — наш existing demo seeder approach is correct!
22. ✅ **AI-assisted manual tracking** — natural language parser (we have it ✓)
23. ✅ **Sankey diagrams** для cash flow visualization (v1.0.1 candidate)
24. ✅ **Privacy Centers top-level** — promote Settings → Privacy
25. ✅ **3 high-level buckets** (Fixed/Flexible/Non-monthly) > 30+ categories — но не блокирует custom для power users

### Anti-patterns confirmed (DO NOT)

- ❌ Liquid Glass iOS 26 era (vaseline fuzziness)
- ❌ Hand-drawn fonts (Caveat)
- ❌ Navy + gold (banking cliché)
- ❌ Plaid wall as first onboarding step
- ❌ Cluttered desktop-on-mobile
- ❌ Passive history-only tracking (forward-looking preferred)

---

## 3. Updated design tokens

### Color palette (revision)

| Role | Current | **Proposed v2** | Why |
|---|---|---|---|
| Brand accent | Mint `#3DDC97` | **KEEP** | Locked в paywall/screenshots (per overnight MASTER.md) |
| Background light | warm `systemBackground` | **soft cream** `#FAF7F2` | Per Q-D3 warmth |
| Background dark | system | **soft charcoal** `#1A1A1C` | Less stark than `#000` |
| Card surface light | `#F2F2F7` | **floating white** `#FFFFFF с 4% black shadow` | Things 3 floating cards |
| Income | emerald `#1A8F61` | **KEEP** but use opacity layers | Hierarchical rendering |
| Expense | terracotta `#BF5430` | **KEEP** but use opacity layers | Per Q-D1 color blind safe |
| Text primary | label | **slate `#0A0E1A`** light / **warm white `#F8F5F0`** dark | Higher contrast |
| Text secondary | `.secondary` | **muted slate** | Better contrast |
| Separators | hairline | **OMIT mostly** — use spacing instead | Things 3 zero-border |

### Typography (revision)

| Token | Current | **Proposed v2** | Use |
|---|---|---|---|
| `bcHero` | 60pt Display Bold | **60pt SF Pro Display Rounded Semibold** | QuickEntry amount |
| `bcLargeTitle` | 28pt | **34pt SF Pro Display Rounded** | Screen titles (Q-D2 #7) |
| `bcTitle` | 28pt Semibold | **24pt SF Pro Display Rounded Semibold** | Section titles |
| `bcSectionHeader` | 20pt Semibold | **17pt Semibold + UPPERCASE + tracking +1.5** | Section headers (Apple modern) |
| `bcBody` | 17pt Regular | **15pt Regular Rounded** | Body |
| `bcCaption` | 13pt Regular | **12pt Regular + 70% opacity** | Caption |
| `bcMoney` | uses bcAmount | **40pt SF Pro Rounded Semibold** for всех money values | Coordinated |

⚠️ **CRITICAL change:** SF Pro Display **Rounded** variant везде (не regular). Warmer, friendlier, still premium. SF Pro Text where needed.

### Spacing (revision)

Keep current 8pt rhythm. **Add ONE new token:**

| Token | Value | Use |
|---|---|---|
| `Spacing.xs` | 8 | (unchanged) |
| `Spacing.s` | 12 | (unchanged) |
| `Spacing.compact` | 16 | (unchanged) |
| `Spacing.default` | 24 | (unchanged) |
| `Spacing.generous` | 32 | (unchanged) |
| `Spacing.hero` | 48 | (unchanged) |
| **`Spacing.section`** | **64** | NEW — between major sections (Things 3 breathing room) |

### Corner radius (revision)

| Token | Current | **Proposed** | Use |
|---|---|---|---|
| `icon` | 8 | **10** | Match capsule trend |
| `button` | 12 | **14** | Slightly softer |
| `card` | 16 | **20** | More floating |
| `cardLarge` | 20 | **28** | Hero cards |
| `sheet` | 24 | **32** | Premium sheets |

### Elevation (revision)

| Token | Current | **Proposed** | Use |
|---|---|---|---|
| `card` | 5% / 8 / 2 | **3% / 12 / 4** | Softer + larger blur |
| `raised` | 10% / 14 / 6 | **6% / 20 / 8** | Refined |
| **NEW `floating`** | — | **2% / 32 / 12** | Background cards |

### Motion (NEW section)

| Action | Animation | Haptic |
|---|---|---|
| Tap CTA | Spring (response: 0.4, dampingFraction: 0.7) | .light |
| Sheet present | Spring source-linked | none |
| Save transaction | Spring + success symbol effect | .success |
| Category select | Spring + .light | .light |
| Chart selection change | none (instant) | .light |
| Lock/unlock | Spring + symbol effect | medium |
| Error | Shake spring | .error |

---

## 4. Screen-by-screen redesign approach

### Priority screens (most user time)

#### 1. **Dashboard** (current: dense, primitive)

**Redesign:**
- **Hero section:** Large title "Сегодня" / "Today" (34pt rounded semibold)
- **Single hero metric:** Net balance этого месяца, 60pt rounded semibold, mint accent
- **Spending pace indicator** (NEW per Q-D5 #2) — visual showing "you've spent X% by day Y of month"
- **Recent transactions:** 3 items с card surface, zero borders, generous spacing
- **Quick stat tiles:** Income/Expense/Net, soft floating cards, hierarchical color
- **Floating "+" button** для Quick Entry (spring linked к QuickEntry sheet)

**Inspiration:** Things 3 Today screen + Calm hero space

#### 2. **QuickEntry** (already redesigned overnight ✅)

Keep overnight design but apply NEW tokens:
- 60pt → SF Pro Display Rounded Semibold
- Card surface c new floating elevation
- Spring source-linked transition from "+" button

#### 3. **Analytics** (3 tabs: Pulse, Horizon, Breakdown)

**Common redesign:**
- Period selector pill at top (capsule shape, spring tab transitions)
- Chart hero area с generous spacing
- Below: insights cards (NEW)

**Pulse-specific:**
- Day spending area chart
- Sticky selection ✅ (just fixed)
- DaySpendingSheet drill ✅ (just fixed)
- ADD: "this week vs last week" insight card

**Horizon-specific:**
- Net trend line с emerald/terracotta split ✅ (just fixed)
- Month detail sheet
- ADD: forecast indicator (где будем в конце месяца at this rate)

**Breakdown-specific:**
- Donut с rank-opacity
- Legend driven selection ✅
- ADD: top category insights ("Coffee = 15% of this month")

#### 4. **Categories**

- Things 3-style zero-border list
- Color chip + icon + name + monthly total
- Drag-to-reorder feel
- Empty state: custom illustration of Budget Crab mascot organizing

#### 5. **Accounts**

- Same pattern as Categories
- Card-based balance display
- Total net worth at top (hero metric)

#### 6. **Settings**

**Privacy Center promotion** (NEW per Q-D5 #4):
- Top-level "Privacy" section (не buried)
- Visual icon + "Your data stays on this iPhone" tagline
- Below: standard settings groups

Reorganize as:
1. **Privacy & Data** (top)
2. **Appearance** (theme, language)
3. **Notifications**
4. **Premium / Subscription** (founder's pricing reminder)
5. **About** (with Tell a Friend + Rate the App)
6. **Help & Support**

#### 7. **Onboarding**

**Demo Mode first** (per Q-D5 #1):
- "Take a tour" button → opens demo с seeded data
- After tour: "Start fresh" or "Continue with my data"
- Privacy disclosure clear, не buried

**Currency selection:** large card buttons (replace wheel picker confirmed ugly)
**Skip к "core feature unlock":** 60-second к first transaction (per Q-D5 #3)

#### 8. **Paywall** (LOCKED — recently shipped Founder's Edition)

Don't touch. Already premium per overnight work.

### Lower-priority screens

- TransactionDetail, EditTransaction, CategoryEdit, AccountEdit, Help — apply new tokens but не full redesign
- AuthGate (Face ID lock) — apply new tokens

---

## 5. Mascot integration plan (per Q-D3 #12)

Budget Crab mascot character — 6 poses already commissioned (per memory).

**Where к use:**
1. **Onboarding hero** — Welcome crab waving
2. **Empty states** — Crab organizing categories, crab with chart, crab carrying gold (savings)
3. **Success moments** — Crab giving thumbs up after saving transaction (subtle, не intrusive)
4. **Settings → About** — Hero illustration with crab
5. **Privacy section** — Crab guarding treasure chest (privacy metaphor)

**Where NOT к use:**
- ❌ Paywall (would dilute Quiet Premium)
- ❌ Charts / analytics screens (would dilute data focus)
- ❌ Permanent header navigation (intrusive)

**Style:**
- Soft, minimal, не childish
- Match brand mint accent
- Subtle, не attention-grabbing
- Apple Editorial featured-worthy

---

## 6. Pricing recommendation update (RU market-specific)

### Critical finding from lifehacker

Our $99.99 lifetime = **~9000₽** in RU storefront — **2-5× more expensive** than RU competitor lifetime tiers:

- Дзен-мани lifetime: 2990₽ (~$33)
- CoinKeeper lifetime: 1690₽ (~$19)
- Wallet lifetime: 4490₽ (~$50)
- Деньги ОК lifetime: 1999₽ (~$22)

### Options

**Option A: Apple auto-conversion accepted**
- Lifetime $99.99 = ~9000₽ everywhere
- Position: "Premium privacy-first vs cheaper but compromised alternatives"
- Risk: low conversion в RU storefront

**Option B: Custom RU pricing**
- Override lifetime в RU storefront к ~2990₽ (matches Дзен-мани leader)
- Same в US/other = $99.99
- Apple supports per-territory pricing
- Risk: arbitrage shopping (но Apple prevents this)

**Option C: Skip RU storefront initially**
- Focus US + Brazil + LatAm
- Add RU later когда can custom-price properly
- Lose 140M+ Russian-speaking users

**RECOMMENDATION:** Option B — RU lifetime ~2990₽, monthly/yearly accept auto-conversion. Matches Дзен-мани leader, captures price-sensitive market без diluting US premium positioning.

Similar consideration для BR: Mobills R$ 119/yr — наш $34.99/yr ≈ R$ 175 (50% more). Consider RU-equivalent custom price для BR storefront.

---

## 7. Risk assessment

### Execution risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Breaking submission readiness | Medium | Hard constraints brief, commits per area |
| Locale parity break | Low | Tests guard 459 keys |
| Build break | Low | xcodebuild after each commit |
| Over-design (lose Quiet Premium) | Medium | Reference: Things 3, не Spendee |
| User не одобрит final result | Medium | This plan IS the gate — approve OR iterate |
| Time overrun (1 week → 3 weeks) | High | Scope k P0 + P1 first, P2/P3 incremental |

### Scope risks

- Mascot integration adds illustration work (designer time)
- Custom illustrations for empty states (designer time)
- Per-territory pricing requires ASC manual adjustment

### Timeline estimate

- **Token application (mechanical):** 1-2 days
- **Screen redesigns priority (Dashboard, Analytics, Settings, Onboarding):** 3-4 days
- **Mascot integration (with existing 6 poses):** 1 day
- **Empty states custom illustrations:** 1-2 days (or use existing mascot poses)
- **Smoke test + regression:** 0.5 day
- **Screenshot regeneration:** 0.5 day
- **Total:** **7-10 days**

---

## 8. Validation criteria (before launch)

Before considering redesign "done":

- [ ] WCAG AAA contrast verified (was AA — upgrade)
- [ ] All money colors use semantic tokens
- [ ] No magic numbers in spacing (all `Spacing.*`)
- [ ] All fonts use `Font.bc*` extensions
- [ ] Spring transitions on all sheet presentations
- [ ] Haptics on save/select/error
- [ ] 60-second usability test: new user can add first transaction в <60s
- [ ] Daylight readability test: direct sun visible (real iPhone)
- [ ] Dark mode parity tested
- [ ] 4 locales render correctly с new fonts
- [ ] Screenshots regenerated cleanly
- [ ] PaywallView untouched (verified)
- [ ] Build green + tests green

---

## 9. Validation prompts для ChatGPT (you run)

Run these в ChatGPT с screenshots OR descriptions of наш current UI:

### Prompt 1 — Design critique

```
Я создал iOS finance app called "Budget Crab". Currently it has these design tokens:
- Mint accent (#3DDC97)
- Terracotta expense color (#BF5430)
- Emerald income (#1A8F61)
- SF Pro Display fonts (not rounded)
- 60pt hero numbers
- Card-based layout

User feedback: "выглядит тяжелым и примитивным"

I'm planning к redesign с these changes:
- Switch all fonts к SF Pro Display Rounded variant
- Add cream background (#FAF7F2) instead of system
- Use hierarchical opacity rendering для categories instead of multiple colors
- Add Spring transitions с source-linking
- Increase corner radius к 20pt cards
- Use zero-borders pattern (Things 3 style)
- Add custom mascot illustrations в empty states

What's missing? What anti-patterns might I be missing? What references should I study? Be critical.
```

### Prompt 2 — Reference apps deep dive

```
For an indie iOS personal finance app positioned as "Quiet Premium" (privacy-first, на-device only, lifetime purchase option), what specific design choices от these apps should I study:

1. Things 3 — exact patterns to borrow
2. Bear — typography decisions
3. Linear — modern dark mode
4. Reflect — spacious feel
5. Day One — premium card elevations
6. Klipper — icon polish

Give concrete examples (colors, fonts, spacing values, animation timings) — не generic advice.
```

### Prompt 3 — Mascot integration validation

```
I have a crab mascot character (Budget Crab) с 6 poses already commissioned. Considering integrating it в these places:
- Onboarding welcome screen
- Empty states (no categories, no transactions, no savings goals)
- Success moments после saving transaction
- Settings → About page hero
- Privacy section ("crab guarding treasure")

Will NOT use в:
- Paywall (would dilute premium positioning)
- Charts/analytics
- Permanent header navigation

Compare к Duolingo Duo, Mailchimp Freddie, Reflect notes. Is my integration plan good? Where might it backfire? What guidelines should I follow?
```

### Prompt 4 — RU market pricing validation

```
I'm launching indie iOS finance app at $4.99/mo + $34.99/yr с 7-day trial + $99.99 lifetime + Family Sharing enabled.

RU competitor lifetime prices: Дзен-мани 2990₽ ($33), CoinKeeper 1690₽ ($19), Wallet 4490₽ ($50), Деньги ОК 1999₽ ($22).

Apple auto-conversion makes $99.99 = ~9000₽ — 2-5× more expensive than RU competitors.

Options:
A) Accept auto-conversion, position as premium privacy-first
B) Custom RU lifetime price ~2990₽ (matches leader)
C) Skip RU storefront initially

What would you recommend? What's the risk of each? Consider that we cannot offer bank sync (no Plaid в RU now) but emphasize on-device privacy.
```

### Prompt 5 — Onboarding flow validation

```
For an iOS finance app launching 2026, what's the optimal onboarding flow?

Current plan:
1. Welcome screen с mascot
2. Currency selection (large cards, not wheel)
3. "Take a tour" option → demo mode с seeded data
4. After tour: "Start fresh" or "Continue с demo"

Goal: get user к first transaction в under 60 seconds.

Should we:
- Require Face ID setup в onboarding? (currently optional, в Settings)
- Show paywall в onboarding? (currently in Settings only — soft sell)
- Require account creation? (currently no — on-device only)
- Show privacy disclosure card?

What 2026 best practices am I missing?
```

---

## 10. Decision gate — approve before execution

### What I need from you

1. **Approve overall direction?** (Yes / iterate / reject)
2. **Pricing decision:** Option A / B / C (RU custom-price recommended)
3. **Mascot scope:** OK к use в all listed places? Limit?
4. **Timeline:** Accept 7-10 day timeline для full redesign?
5. **Submission delay:** Confirm willing к wait 7-10 days до submit?

### After approval

1. I write detailed execution brief (5-10 pages, screen-by-screen)
2. Claude Code Opus executes (multi-day work)
3. Regenerate screenshots
4. Final smoke test
5. Manual review (you)
6. Submit к ASC

### If rejected / iterate

Tell me what к change, I iterate plan. No execution until you approve.

---

## Sources

- 5 NotebookLM queries (D1-D5) — UX & Mobile Design notebook (ff5e0abc) + Personal Finance Domain (73afc9a4)
- 3 ui-ux-pro-max generated alternatives via search.py
- [Lifehacker top 10 RU finance apps](https://lifehacker.ru/10-money-management-apps/) — fetched 2026-06-28
- Bug-fix work (commits a7e3561 / 78d3e90 / b2c07df) — observations from real code
- Apple HIG 2026 (referenced via design skill)
- WWDC 2025 spring transition patterns (referenced via swiftui skill)
- Pending: 5 ChatGPT validation prompts (above)
- Pending: User-collected reference screenshots в `inspiration/`
- Pending: 3-5 friends/family feedback в `user-feedback.md`
