# Budget Crab — Design Exploration v2

**Status:** WIP — collecting data, awaiting NotebookLM research + user feedback
**Goal:** Define friendly + minimalist + premium design direction (not heavy/primitive)
**Decision-maker:** User approves before execution

## User feedback что triggered redesign

> "нужно вообще проанализировать и проработать редизайн на дружелюбный и минималистичный, выглядит тяжелым и примитивным"

Translation: Need full re-analysis + redesign to **friendly + minimalist**. Current looks **heavy + primitive**.

Plus user wants **proper plan first**, not blind execution.

## 4 design directions under consideration

### Direction A: Current "Quiet Premium" (overnight baseline)

- **Style:** Soft UI Evolution
- **Palette:** Mint brand (#3DDC97) + terracotta expense (#BF5430) + emerald income (#1A8F61) + warm cream background
- **Typography:** SF Pro Display rounded, 60pt hero
- **Mood:** Calm, restrained, "$99 lifetime tool"
- **Source:** `AppStore/design-system/MASTER.md`
- **User verdict:** "тяжелым и примитивным" — too heavy
- **What works:** Sub-$100 charm pricing + on-device privacy positioning
- **What doesn't:** Visual weight excessive, dense info hierarchy, lacks warmth

### Direction B: "Friendly Minimalist" (ui-ux-pro-max)

- **Style:** Soft UI Evolution (same но different palette)
- **Palette:** Monochrome black/gray + cool blue accent (#2563EB)
- **Typography:** Varela Round + Nunito Sans (rounded, friendly, warm, gentle)
- **Mood:** Approachable, soft, friendly
- **Concerns:** Rounded fonts may feel too "casual" для finance apps; blue accent generic
- **Reference apps:** Children's products, pet apps, wellness — possibly TOO playful для money

### Direction C: "Premium Calm" (ui-ux-pro-max)

- **Style:** Liquid Glass ⚠️ FLAGGED — generator's recommendation has "moderate-poor performance + text contrast issues"
- **Palette:** Trust navy (#0F172A) + premium gold (#CA8A04)
- **Typography:** Lexend + Source Sans 3 (corporate, trustworthy, accessible)
- **Mood:** Professional, established, "we mean business"
- **Concerns:** Navy + gold = banking cliché. Liquid Glass deprecated by Apple.
- **Reference:** Old-school banking apps. **NOT recommended**.

### Direction D: "Modern Clean" (ui-ux-pro-max)

- **Style:** Minimalism & Swiss Style (WCAG AAA, excellent performance)
- **Palette:** Fresh cyan (#0891B2) + clean green (#22C55E) + bright background
- **Typography:** Lexend + Source Sans 3 (same as C, but minimalist style)
- **Mood:** Bright, fresh, modern, spacious, accessible
- **Concerns:** Could feel "clinical" or "Material Design 3 generic"
- **Reference:** Enterprise dashboards, healthcare apps

## Synthesis — likely best direction

**Hybrid: A (Quiet Premium) + B (Friendly) + D (Modern Clean) elements**

What к pull from each:
- ✅ From A: terracotta expense colors (warm, не alarm), mint brand accent (unchanged — locked в paywall + screenshots)
- ✅ From B: rounded typography (SF Pro Display rounded), softer effects
- ✅ From D: Swiss-style spacious layout, WCAG AAA contrast, restraint

What к add (not in any generated option):
- 🆕 **Mascot illustration touchpoints** — Budget Crab character peeks через interface (avoids "cold" feeling)
- 🆕 **Generous spacing** — current dense, needs к breathe
- 🆕 **Single confident accent color** — restraint over decoration
- 🆕 **Soft micro-interactions** — gentle haptics, fluid transitions
- 🆕 **Custom illustrations** для empty states (not stock SF Symbols)

## Evaluation criteria

Each direction must satisfy:

| Criterion | Weight | A | B | C | D | Hybrid |
|---|---|---|---|---|---|---|
| Friendly (warm, not cold) | High | 3/5 | 5/5 | 1/5 | 2/5 | **5/5** |
| Minimalist (not cluttered) | High | 3/5 | 4/5 | 2/5 | 5/5 | **5/5** |
| Premium feel ($99 lifetime worth) | High | 4/5 | 2/5 | 5/5 | 3/5 | **5/5** |
| Daylight readable | Critical | 4/5 | 3/5 | 2/5 | 5/5 | **5/5** |
| WCAG AA contrast | Critical | 4/5 | 3/5 | 2/5 | 5/5 | **5/5** |
| iOS HIG aligned | High | 4/5 | 3/5 | 2/5 | 4/5 | **5/5** |
| Quiet Premium positioning fit | High | 5/5 | 3/5 | 4/5 | 3/5 | **5/5** |
| Brand differentiation | Medium | 4/5 | 2/5 | 2/5 | 2/5 | **4/5** |
| **Total** | — | 27 | 25 | 20 | 29 | **39** |

Hybrid wins decisively. Path forward: synthesize after research.

## Reference apps к study

### Tier 1 — Premium minimalist gold standard

| App | What works | What к borrow |
|---|---|---|
| **Things 3** | Magnetic micro-interactions, generous whitespace, perfect typography | Spacing rhythm, transitions, restraint |
| **Bear** | Friendly minimalism + content-first, soft serif touches | Empty states, content density balance |
| **Linear** | Premium professional, dark mode excellence, modern restraint | Dark mode palette, animation timing |
| **Reflect** | Soft + premium + personal | Color warmth, illustration style |

### Tier 2 — Finance category leaders

| App | What works | Lesson |
|---|---|---|
| **Lunch Money** | Highest CSI satisfaction (3.9/5) per research | Methodology > flashy design |
| **Toshl Finance** | Distinctive mascot ("Toshl monsters") | Mascot integration done right |
| **Spendee** | Clean modern, but generic | Avoid: too generic |
| **Wallet (BudgetBakers)** | Functional но heavy | Anti-pattern: dense info |
| **Buckets** | Pure local-first (closest indie analog) | Honest, restrained, but visually dated |

### Tier 3 — Cross-category inspiration

| App | What к learn |
|---|---|
| **Spike Email** | Friendly + warm + calm email |
| **Day One Journal** | Premium feels, beautiful typography |
| **Klipper** | Indie iOS that feels expensive |
| **Things 3** | (Repeat) — every detail matters |

## Pending inputs

1. ⏳ 5 NotebookLM queries (D1-D5) — psychology + visual weight + minimalism + premium signals + finance UX
2. ⏳ User-collected visual references (save к this folder)
3. ⏳ User feedback from 3-5 friends/family
4. ⏳ Final synthesized Design Plan v2 doc

## Next steps

1. Receive NotebookLM responses → enrich this exploration
2. User collects references in `AppStore/design-references/inspiration/`
3. Synthesize complete Design Plan v2 doc
4. User approves
5. Execute via Claude Code

## Anti-patterns identified (DO NOT DO)

- ❌ Liquid Glass (Direction C) — deprecated, poor contrast
- ❌ Material Design 3 generic — feels "Android-on-iOS"
- ❌ Cluttered dashboards (Wallet BudgetBakers anti-pattern)
- ❌ Cold sterile minimalism (Direction D pure) — too clinical
- ❌ Too playful (childrens apps / pet apps territory) — wrong for money
- ❌ Banking cliches (navy + gold = old school)
- ❌ Stock SF Symbols only — feels generic
- ❌ Alarm-red expenses — anxiety inducing
- ❌ Hand-drawn fonts (Caveat etc.) — wrong for money trust
