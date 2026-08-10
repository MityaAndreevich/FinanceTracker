# Budget Crab — App Store Screenshot Storyboard

**App:** Budget Crab — privacy-first iOS personal finance tracker
**Positioning:** Quiet Premium (Sage + Ruler archetype) — calm, composed, in control. No hype, no loud claims.
**Pricing (not shown in captions — Apple disallows prices in screenshots):** $4.99/mo · $34.99/yr · $99.99 lifetime
**Locales:** EN · RU · ES · PT-BR · **UK**
**Devices:** iPhone **6.9" required (1320 × 2868)** — this is what the shipped set actually is.

> **Corrected 2026-08-10.** This line previously said `6.7" required (1290 × 2796) · 5.5" optional
> (1242 × 2208)`, and the Locales line omitted UK. Both were wrong about assets that already
> existed: all **40** composed frames and all **40** raw captures are 1320 × 2868, across **five**
> locales including UK. No 5.5" asset exists in this repo. A doc describing assets that are not
> the assets is how a release nearly ships the wrong screenshot size — measured, not assumed:
> dimensions read from the PNG headers in `AppStore/composed/` and `AppStore/screenshots/`.

> **Banned-claim guardrails (do NOT use in any locale):** encrypted · AI-powered · free forever · bank-grade · made with love · best · #1 · "free". Also: no prices, no version numbers, no competitor names. "Stays on your iPhone" / "on-device" is the safe way to say the privacy benefit without "encrypted."

---

## Sequence rationale

Most users see only the first 2–3 thumbnails, so the privacy wedge — the single strongest differentiator for this app — is front-loaded at position 2, immediately after the hero. The order then descends from "why us" (privacy, speed) into proof of depth (insights, organization, control) and closes on lifetime ownership, which reinforces the Ruler "own it, no strings" feel.

| # | Purpose | Screen | Why here |
|---|---------|--------|----------|
| 1 | Hero | Dashboard | First impression — value prop + best visual |
| 2 | Differentiator | Privacy / on-device | Lead with the wedge while attention is highest |
| 3 | Core feature | QuickEntry | Show the "aha" — effortless capture |
| 4 | Insight | Analytics breakdown | Proof of payoff |
| 5 | Depth (1.0.3) | Split editor | One purchase, several categories |
| 6 | Care (1.0.3) | Category limits on the categories list | Warns while money is LEFT, never after |
| 7 | Ownership of data | Export (CSV/PDF/Excel) | "Your data, portable" — no lock-in |
| 8 | CTA | Lifetime / clean close | Calm close, ownership |

---

## Visual system (all locales, all screenshots)

- **Palette:** muted sage green accent, warm off-white / soft cream background, deep ink-charcoal text. One accent only. No neon, no aggressive gradients — restraint signals premium.
- **Background:** solid warm cream or a barely-there vertical tint (top slightly lighter). Consistent across all 8 for a calm, cohesive shelf.
- **Device frame:** flat, straight-on, thin minimal frame (or frameless with generous margin). No 3D tilt — straight = composed/Ruler. Same treatment on all 8.
- **Typography:** 2 fonts max — one calm headline (humanist sans or a restrained serif for the Sage warmth) + clean body. Headline ≥ 60pt so it survives thumbnail size.
- **Caption placement:** top third, consistent baseline across all 8. Generous whitespace above and below — silence is the brand.
- **Thumbnail check:** screenshots 1–3 must be legible and distinct at thumbnail scale (test in the actual search-results layout before shipping).

---

## Storyboard (master = English; translations follow each caption)

### SCREENSHOT 1 — HERO · Dashboard
- **Visual:** Dashboard with balance, this-month income/expense, period selector. Realistic but tidy sample data (no $0, no absurd numbers). Sage accent on the balance card.
- **Background:** warm cream, subtle top tint.
- **Notes:** This is the shelf impression. Calm, uncluttered, "I could keep this open and feel fine." Avoid red-heavy expense styling — keep it composed.
- **Caption:**
  - **EN:** Your money, calmly in control
  - **RU:** Финансы под спокойным контролем
  - **ES:** Tus finanzas, bajo control y en calma
  - **PT-BR:** Suas finanças sob controle e tranquilas

### SCREENSHOT 2 — DIFFERENTIATOR · Privacy / on-device
- **Visual:** Privacy settings or a simple on-device illustration (iPhone glyph, "no account needed"). Could pair the PrivacySettingsView with a calm one-line statement.
- **Background:** consistent cream.
- **Notes:** The wedge. Say it plainly without the banned word "encrypted." "Stays on your iPhone" + "no account needed" is true and compliant.
- **Caption:**
  - **EN:** Your data stays on your iPhone
  - **RU:** Данные остаются на вашем iPhone
  - **ES:** Tus datos se quedan en tu iPhone
  - **PT-BR:** Seus dados ficam no seu iPhone

### SCREENSHOT 3 — CORE FEATURE · QuickEntry
- **Visual:** QuickEntry mid-entry — natural amount + category tap-to-pick. Show how fast a transaction lands. Keyboard or chips visible.
- **Background:** consistent cream.
- **Notes:** The "aha." Effortless capture is the daily-habit hook.
- **Caption:**
  - **EN:** Log spending in seconds
  - **RU:** Записывайте траты за секунды
  - **ES:** Registra tus gastos en segundos
  - **PT-BR:** Registre gastos em segundos

### SCREENSHOT 4 — INSIGHT · Analytics breakdown
- **Visual:** Analytics breakdown chart with the income/expense segmented filter. Clean category breakdown, sage palette on the chart.
- **Background:** consistent cream.
- **Notes:** Proof the logging pays off. Keep the chart legible — few categories, clear labels.
- **Caption:**
  - **EN:** See where your money goes
  - **RU:** Видно, куда уходят деньги
  - **ES:** Mira a dónde va tu dinero
  - **PT-BR:** Veja para onde vai seu dinheiro

### SCREENSHOT 5 — DEPTH · Split editor  *(new in 1.0.3, replaces Categories & Accounts)*
- **Visual:** `EditTransactionView` on the seeded marketplace order (Amazon / Ozon / Rozetka).
  The SPLIT ACROSS CATEGORIES section shows two parts plus the remainder footer
  ("$26.00 stays in Shopping.") — the whole remainder model in one frame.
- **Route:** `--screenshot-screen split`. Data comes from the DemoSeed `splits` block on the
  day-14 Shopping row; the parts are whole numbers so no "18.5" appears in an amount field.
- **Notes:** Caption reuses the app's own `split.section` wording per locale, so the caption and
  the on-screen section header agree word-for-word.

### SCREENSHOT 6 — CARE · Category monthly limit  *(new in 1.0.3, replaces Face ID lock)*
- **Visual:** `CategoriesSourcesView` alone, scrolled so the limited categories lead the frame —
  Food & Drink "Limit: $600.00/month" and Coffee "Limit: $40.00/month", both in mint. The row
  label IS the feature's proof, so the list needs no sheet over it.
- **Route:** `--screenshot-screen categorylimit`. The seed sets limits so month-to-date spend
  lands at ~70–80% used — the gentle warn band. NEVER seed an at/over-limit state: the app
  deliberately says nothing there (`CategoryLimitPolicy`), so there'd be nothing to show.
- **No sheet on the shelf:** the limit editor was slot 06 through 636e515 and was pulled — it
  puts a destructive red "Remove limit" button on a shelf frame (reads as a warning, off the
  mint palette) and its `.medium` detent leaves ~30% of the frame empty. It stays routable as
  `--screenshot-screen categorylimitsheet` for ad-hoc captures.
- **Notes:** There is no in-app "X left in <category>" surface — that sentence only exists as a
  local-notification body, which can't be captured under `simctl` and mustn't be faked (2.3.3).
  The mint limit label is the honest real-UI equivalent; the caption carries the "gentle" promise.

### SCREENSHOT 7 — DATA OWNERSHIP · Export
- **Visual:** Data settings export sheet — CSV / PDF / Excel options visible.
- **Background:** consistent cream.
- **Notes:** "No lock-in, your data is portable." Pairs with the privacy story — you own it and can take it anywhere.
- **Caption:**
  - **EN:** Export to CSV, PDF, or Excel
  - **RU:** Экспорт в CSV, PDF и Excel
  - **ES:** Exporta a CSV, PDF o Excel
  - **PT-BR:** Exporte para CSV, PDF ou Excel

### SCREENSHOT 8 — CTA · Lifetime / clean close
- **Visual:** Calm closing frame — app icon + a clean dashboard glimpse, or a composed "yours to keep" panel. NO price text. Generous whitespace, single sage accent.
- **Background:** consistent cream, strongest finish.
- **Notes:** Ruler ownership close. "For life" references the lifetime tier accurately and is NOT the banned "free forever."
- **Caption:**
  - **EN:** Yours to keep, for life
  - **RU:** Останется с вами навсегда
  - **ES:** Tuyo para siempre
  - **PT-BR:** Seu para sempre

---

## Caption sheet (copy-ready, all locales)

> **The shipped captions live in `AppStore/compose-screenshots.py` (`CAP`), which is the single
> source of truth** — it covers all five shelf locales (incl. UK) and is what actually gets
> baked into the composed PNGs. The table below is the original storyboard intent, kept for the
> reasoning; where the two differ, the script wins. No caption may state a trial length (the
> 30-day intro offer is removed for 1.0.3).

| # | EN | RU | ES | PT-BR |
|---|----|----|----|----|
| 1 | Your money, calmly in control | Финансы под спокойным контролем | Tus finanzas, bajo control y en calma | Suas finanças sob controle e tranquilas |
| 2 | Your data stays on your iPhone | Данные остаются на вашем iPhone | Tus datos se quedan en tu iPhone | Seus dados ficam no seu iPhone |
| 3 | Log spending in seconds | Записывайте траты за секунды | Registra tus gastos en segundos | Registre gastos em segundos |
| 4 | See where your money goes | Видно, куда уходят деньги | Mira a dónde va tu dinero | Veja para onde vai seu dinheiro |
| 5 | Split one purchase across categories | Разделить покупку по категориям | Una compra, dividida entre categorías | Uma compra, dividida entre categorias |
| 6 | Gentle monthly limits, never a scolding | Мягкий месячный лимит, а не выговор | Límite mensual amable, nunca un regaño | Limite mensal gentil, nunca uma bronca |
| 7 | Export to CSV, PDF, or Excel | Экспорт в CSV, PDF и Excel | Exporta a CSV, PDF o Excel | Exporte para CSV, PDF ou Excel |
| 8 | Yours to keep, for life | Останется с вами навсегда | Tuyo para siempre | Seu para sempre |

---

## Localization & production notes

- **Sample data must be localized per screenshot set.** Currency, number format, category names, and dates should match each locale (₽/RUB context for RU, € for ES, R$ for PT-BR, $ for EN) so the in-frame UI text matches the caption language. Don't ship English in-app text under a Spanish caption.
- **Captions are localized above;** the in-app UI strings already ship in en/ru/es/pt-BR `.lproj`.
- **RU caption #5** is idiomatic ("всё на местах" = "everything in its place"), chosen over a literal translation to keep the Ruler tone; swap to "Упорядочьте по категориям и счетам" if you prefer a strict parallel.
- **5.5" (optional):** reuse the same 8 frames re-exported at 1242 × 2208; if you ship fewer, keep frames 1–5 (hero through organization). Captions unchanged.

## Capture workflow

1. Seed the simulator with tidy, locale-appropriate sample data.
2. `xcrun simctl` on iPhone 15 Pro Max (6.7") and iPhone 8 Plus (5.5") for the two required canvases.
3. Capture raw screens → compose captions/background in Figma using the visual system above.
4. Before shipping: view frames 1–3 at thumbnail scale in a mock search-results row; if any caption is unreadable, increase size/contrast.

## Compliance pass — confirmed clear

No caption uses: encrypted, AI-powered, free forever, bank-grade, made with love, best, #1, "free," prices, version numbers, or competitor names. Privacy benefit is expressed as "stays on your iPhone" (compliant). Lifetime expressed as "for life" / "para siempre" / "para sempre" / "навсегда" (accurate to the lifetime tier, not "free forever").
