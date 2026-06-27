# Budget Crab — Localized ASO Metadata (es · pt-BR · ru)

**Category:** Finance
**App Name (Title) — unchanged across all storefronts:** `Budget Crab Money Tracker`
Native subtitle + keyword sets below are **written natively** (not translated from English) and deliberately avoid every English Title word (*budget · money · tracker · crab*), so no indexing budget is wasted on duplicates.

**Positioning wedge per locale** (vs the bank-syncing, subscription-first leaders in each chart):
- **es** — *privado · offline* + *una sola compra* (vs Fintonic/Mooncard et al., which connect to your bank and bill monthly)
- **pt-BR** — *privacidade · offline* + *compra única* (vs Mobills/Organizze, which use Open Finance + premium plans)
- **ru** — *приватный · офлайн* + *одна покупка* (vs CoinKeeper/Дзен-мани, which auto-import bank cards + sell yearly plans)

> **Strategy:** do **not** fight the leaders head-to-head on their core generic stems. Win the thin-competition wedge terms (offline / private / one-purchase / no-subscription / lifetime), and *harvest* the high-volume generics (finanzas/finanças/финансы, gastos/despesas/расходы) through cross-field combinations, exactly as the en-US set does.

---

## Constraints honored (all locales)

- Subtitle ≤ 30 characters · Keyword field ≤ 100 characters, **comma-separated, no spaces**.
- **Zero word overlap** between a locale's Subtitle and its Keyword field (Apple indexes each word once per locale).
- **Banned terms excluded** (incl. native cognates): bank → *banco/банк*, account → *cuenta/conta/аккаунт/счёт*, balance → *saldo/баланс*, free → *gratis/grátis/gratuito/бесплатно*, best → *mejor/melhor/лучший*, plus *free/best*. No prices, no competitor names, no "encrypted/AI" claims.

> ⚠️ **Keyword-field length — characters vs bytes.** App Store Connect's web field enforces **100 characters**, which is what every set below targets. Some tooling/older API paths historically counted **UTF-8 bytes** (Latin = 1, Cyrillic = 2). Byte counts are listed for each set; the **ru** set is well under 100 chars but **over 100 bytes**, so a ≤100-byte fallback is provided. Confirm which your ASC build enforces before paste.

---

## 🇪🇸 es — Español (App Store España)

**Subtitle (28/30 chars):**
```
Gastos privados sin conexión
```
Indexes: *gastos · privados · sin · conexión* — leads with the highest-intent native phrase (*control de gastos* forms via the keyword `control`) and states the wedge plainly ("private, offline").

**Keywords (95/100 chars · 98 bytes):**
```
finanzas,ahorro,presupuesto,dinero,ingresos,control,suscripción,compra,única,categorías,offline
```
Wedge carried: `suscripción` (→ "sin suscripción"), `compra`+`única` (→ "una sola / compra única"), `offline`. Generic harvest: `finanzas, ahorro, presupuesto, dinero, ingresos, control` (→ "control de gastos").

**High-intent combinations covered:** control de gastos · gastos privados · finanzas offline · presupuesto personal · gastos sin conexión · compra única (sin suscripción) · ahorro / dinero / ingresos.

---

## 🇧🇷 pt-BR — Português (App Store Brasil)

**Subtitle (25/30 chars):**
```
Despesas privadas offline
```
Indexes: *despesas · privadas · offline* — *despesas* is the top BR expense stem; *controle financeiro* (the #1 BR phrase) forms from the keyword field below.

**Keywords (97/100 chars · 101 bytes):**
```
finanças,controle,financeiro,orçamento,gastos,dinheiro,economia,assinatura,compra,única,vitalício
```
Wedge carried: `assinatura` (→ "sem assinatura"), `compra`+`única` (→ "compra única"), `vitalício` (lifetime — the exact counter to Mobills/Organizze premium plans). Generic harvest: `finanças, controle, financeiro` (→ "controle financeiro"), `orçamento, gastos, dinheiro, economia`.

**High-intent combinations covered:** controle financeiro · despesas privadas · finanças offline · orçamento pessoal · compra única / vitalício · controle de gastos · economia / dinheiro.

---

## 🇷🇺 ru — Русский (App Store Россия)

**Subtitle (24/30 chars):**
```
Приватные финансы офлайн
```
Indexes: *приватные · финансы · офлайн* — states the wedge ("private, offline") on the highest-volume stem (*финансы*; "личные финансы" forms via keyword combinations). *учёт расходов* (the top RU phrase) forms from the keyword field.

**Keywords — primary, by character count (94/100 chars · 177 bytes):**
```
расходы,бюджет,траты,доходы,накопления,кошелёк,категории,подписки,покупка,навсегда,учёт,деньги
```
Wedge carried: `подписки` (→ "без подписки"), `покупка` (→ "одна покупка"), `навсегда` (lifetime — exactly how CoinKeeper/Дзен-мани label their lifetime tier). Generic harvest: `расходы, учёт` (→ "учёт расходов"), `бюджет, траты, доходы, накопления, кошелёк, категории, деньги`.

**Keywords — ≤100-byte fallback (51 chars · 96 bytes)** — use only if your ASC build counts bytes:
```
расходы,бюджет,траты,подписки,покупка,навсегда,учёт
```
Keeps every wedge term + the two strongest generics; drops the lower-priority fillers (`доходы, накопления, кошелёк, категории, деньги`).

**High-intent combinations covered:** учёт расходов · приватные финансы · финансы офлайн · личный бюджет · одна покупка / навсегда (без подписки) · траты / доходы / накопления · кошелёк / категории.

---

## Paste-ready summary

| Locale | Subtitle | Keywords |
|---|---|---|
| **es** | `Gastos privados sin conexión` | `finanzas,ahorro,presupuesto,dinero,ingresos,control,suscripción,compra,única,categorías,offline` |
| **pt-BR** | `Despesas privadas offline` | `finanças,controle,financeiro,orçamento,gastos,dinheiro,economia,assinatura,compra,única,vitalício` |
| **ru** | `Приватные финансы офлайн` | `расходы,бюджет,траты,доходы,накопления,кошелёк,категории,подписки,покупка,навсегда,учёт,деньги` |
| **ru (byte-safe)** | `Приватные финансы офлайн` | `расходы,бюджет,траты,подписки,покупка,навсегда,учёт` |

---

## Notes & validation

- **Chart references (June 2026):** es leaders — Fintonic, SayMoney, Moneylover, Monefy, Spendee; pt-BR leaders — Mobills, Organizze, Minhas Economias, Guiabolso; ru leaders — Дзен-мани, CoinKeeper. All connect to banks and/or sell recurring plans, which is precisely why the *offline + one-purchase* wedge is open in each market.
- **Pop/Difficulty not pulled from Search Ads** — term selection is grounded in the live category charts above and native search phrasing, but exact volumes should be validated in AppTweak / Astro / ASC Search Ads (per-storefront) before final submit.
- **Cross-locale dedup:** within each storefront there is zero subtitle↔keyword overlap. Across storefronts, words may legitimately repeat — Apple indexes per-locale, so this is not waste.
- **Screenshot OCR (June 2025+):** the localized screenshot captions from `screenshots-storyboard.md` already reinforce the privacy/offline wedge in each language — keep those first two frames in-language.

### Checklist before submit
- [ ] Confirm ASC enforces characters (not bytes); if bytes, use the **ru byte-safe** set.
- [ ] Paste keywords with **no spaces** after commas.
- [ ] Verify no word repeats across Title (`Budget Crab Money Tracker`) → localized Subtitle → localized Keywords per storefront.
- [ ] Validate Pop/Diff per term in a paid ASO tool, then A/B subtitles via Product Page Optimization once traffic allows.

## Sources
- [techtudo — 10 apps de controle financeiro 2026 (BR)](https://www.techtudo.com.br/listas/2026/01/10-apps-de-controle-financeiro-para-cuidar-melhor-do-dinheiro-em-2026-edapps.ghtml)
- [Organizze — App Store BR](https://apps.apple.com/br/app/organizze-finan%C3%A7as-pessoais/id677699286) · [Mobills — App Store BR](https://apps.apple.com/br/app/mobills-controle-de-gastos/id921838244)
- [N26 — apps para controlar gastos (ES)](https://n26.com/es-es/blog/9-apps-para-controlar-tus-gastos) · [BBVA — apps para gestionar gastos (ES)](https://www.bbva.com/es/salud-financiera/las-10-apps-para-gestionar-y-compartir-tus-gastos/)
- [Дзен-мани — App Store RU](https://apps.apple.com/ru/app/coinkeeper-3/id1335547405) · [CoinKeeper — App Store RU](https://apps.apple.com/ru/app/%D1%84%D0%B8%D0%BD%D0%B0%D0%BD%D1%81%D1%8B-%D0%B1%D1%8E%D0%B4%D0%B6%D0%B5%D1%82-%D1%81-coinkeeper/id1335547405)
