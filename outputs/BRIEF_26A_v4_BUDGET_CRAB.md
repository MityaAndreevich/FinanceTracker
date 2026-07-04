# BRIEF 26A · v4 — Budget Crab App Store Metadata (5 locales)

**Status:** Draft for review · Path B pricing · Quiet Premium positioning
**Supersedes:** conceptual v3 (see note below) · **Do not edit prior v3**
**Locales:** 🇺🇸 EN · 🇷🇺 RU · 🇪🇸 es-MX · 🇧🇷 pt-BR · 🇺🇦 uk
**Author model:** Sonnet-class execution (skills: /copywriting /aso /app-store /product-marketing /competitor-profiling)

> **⚠️ Note on "v3":** No `BRIEF_26A_v3_*.md` or `budget_crab_decision.md` exists in this repo — those are external context. This v4 is authored fresh from the brief's constraints and **verified against the actual codebase**, not by diffing a prior file. All product claims below trace to code (see Verification Log, §12).

---

## Brand decisions locked (Path B)

| Item | Value | Source |
|---|---|---|
| Brand name | **Budget Crab** | Established in all 5 `InfoPlist.strings` + `design-system/budget-crab/` |
| Monthly | **$3.99/mo** | `FinanceTracker.storekit` L98 (`bc_premium_monthly`) ✅ already Path B |
| Yearly | **$29.99/yr**, 7-day free trial | `FinanceTracker.storekit` L126 (`bc_premium_annual`) ✅ |
| Lifetime | **$79.99** one-time | `FinanceTracker.storekit` L18 (`bc_premium_lifetime`) ✅ |
| Savings claim | **37%** ($3.99×12 = $47.88 vs $29.99 → 37.4%) | math verified |
| Positioning | Quiet Premium — architecture-first privacy | brief Q3 R2 |

### 🔴 Two corrections to the brief's assumptions (both code-verified)

1. **"10 transactions/month free tier" is FALSE — do not use it.**
   There is no transaction-count gate anywhere in the code. Free users get **unlimited transactions**. Premium gates *features*, not volume:
   - **Free forever:** unlimited transactions, voice/Siri entry, current-month exports (CSV / PDF / Excel).
   - **Premium unlocks:** all-time exports (CSV / PDF / Excel), CSV **import**, custom fields, advanced filters.
   - Source: `Views/Settings/DataSettingsView.swift` (`gatePremiumOr`, L94/107/120/142) + `en.lproj` `paywall.feature.*`.
   - A *generous* free tier is stronger for Quiet Premium than a stingy 10-tx cap — this is an upgrade, not a compromise.

2. **7-day trial is not in the local `.storekit`** (`introductoryOffer: null`, L102/L130). This is normal — intro offers are configured in **App Store Connect**, not the local test config. But it **must be confirmed live in ASC before any "7-day free trial" copy ships.** See §11 pre-submit checks.

---

## 🇺🇸 EN Metadata

**1. App Name** (≤30) — primary: `Budget Crab` *(11)*
- ASO A/B variant: `Budget Crab: Private Money` *(26)* — brand + keyword; test post-launch.

**2. Subtitle** (≤30) — primary: `Private expense tracker` *(23)*
- Alternative B (A/B post-launch): `Track spending, stay private` *(28)*

**3. Keywords** (≤100, no spaces) *(94)*
```
finance,spending,money,budgeting,offline,voice,siri,cash,wallet,savings,no bank,receipts,daily
```
*(Excludes name/subtitle words — Apple already indexes those.)*

**4. Description** (~2,150)
```
Budget Crab is the private way to track your money. Add an expense in seconds — type it, or tap the mic and say it out loud. It lands on your iPhone and stays there.

No accounts. No sign-up. No cloud sync you never asked for. When you open Budget Crab there is nothing to log into — because there is nowhere to log in to. Your data never leaves the device.

WHAT YOU CAN DO
• Log income and expenses in a couple of taps
• Dictate a transaction with your voice — transcribed on-device, never uploaded
• Add spending straight from Siri and the Shortcuts app
• Organize with a clean two-tier category system
• See where your money goes with clear monthly summaries
• Export the current month to CSV, PDF, or spreadsheet — free

FREE, WITHOUT THE CATCH
Unlimited transactions, free, forever. No monthly cap. No ads. Premium is there when you want more: all-time exports (CSV / PDF / Excel), CSV import, custom fields, and advanced filters.

PRIVACY BY ARCHITECTURE
This is not a privacy promise — it is how the app is built. There are no servers to hold your data, no analytics SDKs watching you, no ad networks in the code. Your finances are yours, full stop.

PLANS
• Monthly: $3.99/month
• Yearly: $29.99/year with a 7-day free trial (save 37%)
• Lifetime: $79.99, one-time

Prices are shown in your local currency at checkout. Subscriptions renew until cancelled; manage or cancel anytime in Settings.

Budget Crab is built independently. No investors, no ads, no data business — just a focused tool that respects your money and your privacy.
```

**5. Promotional Text** (≤170) *(147)*
```
Track spending in seconds — type or speak it. Everything stays on your iPhone. No accounts, no cloud, no ads. Unlimited transactions, free forever.
```

**6. What's New — v1.0** (≤4,000) *(see §9 note: 1.0 typically ships with no What's New; staged for first update)*
```
Budget Crab is here. Private money tracking that never leaves your iPhone: type or speak a transaction, add spending from Siri, and export your month to CSV, PDF, or spreadsheet. Unlimited transactions, free forever. Thanks for trying it — tell us what you'd like next.
```

---

## 🇷🇺 RU Metadata

**1. App Name** (≤30): `Budget Crab` *(11)* — латинский бренд сохраняем.

**2. Subtitle** (≤30): `Приватный трекер расходов` *(25)*
- Alternative B: `Расходы под контролем` *(21)*

**3. Keywords** (≤100) *(89)*
```
финансы,бюджет,деньги,кошелек,офлайн,голос,siri,без банка,траты,экономия,чеки,планировщик
```

**4. Description** (~2,050)
```
Budget Crab — приватный способ следить за деньгами. Добавьте расход за секунды: введите вручную или нажмите на микрофон и продиктуйте. Всё остаётся на вашем iPhone.

Без аккаунтов. Без регистрации. Без облачной синхронизации, о которой вы не просили. Когда вы открываете Budget Crab, входить некуда — потому что входить не во что. Данные не покидают устройство.

ЧТО ВНУТРИ
• Доходы и расходы в пару касаний
• Диктовка транзакций голосом — распознавание на устройстве, ничего не загружается
• Добавление трат прямо из Siri и приложения «Быстрые команды»
• Понятная двухуровневая система категорий
• Ясные итоги по месяцам — видно, куда уходят деньги
• Экспорт текущего месяца в CSV, PDF или таблицу — бесплатно

БЕСПЛАТНО, БЕЗ ПОДВОХА
Транзакции без лимита — бесплатно и навсегда. Никаких месячных ограничений. Никакой рекламы. Premium — когда захотите больше: экспорт за всё время (CSV / PDF / Excel), импорт CSV, пользовательские поля и расширенные фильтры.

ПРИВАТНОСТЬ ПО АРХИТЕКТУРЕ
Это не обещание приватности — так устроено приложение. Нет серверов, где хранились бы ваши данные. Нет аналитических SDK. Нет рекламных сетей в коде. Ваши финансы — только ваши.

ТАРИФЫ
• Месяц: $3.99/мес
• Год: $29.99/год, 7 дней бесплатно (экономия 37%)
• Навсегда: $79.99, разовый платёж

Цены показываются в вашей валюте при оплате. Подписки продлеваются автоматически до отмены; отменить можно в любой момент в Настройках.

Budget Crab разработан независимо. Без инвесторов, без рекламы, без торговли данными — просто аккуратный инструмент, который уважает ваши деньги и вашу приватность.
```

**5. Promotional Text** (≤170) *(150)*
```
Записывайте траты за секунды — вручную или голосом. Всё остаётся на iPhone. Без аккаунтов, без облака, без рекламы. Транзакции без лимита — бесплатно навсегда.
```

**6. What's New — v1.0**
```
Budget Crab уже здесь. Приватный учёт денег, который не покидает iPhone: вводите или диктуйте транзакцию, добавляйте траты из Siri и экспортируйте месяц в CSV, PDF или таблицу. Транзакции без лимита — бесплатно навсегда. Спасибо, что попробовали — расскажите, чего добавить.
```

---

## 🇪🇸 es-MX Metadata

**1. App Name** (≤30): `Budget Crab` *(11)*

**2. Subtitle** (≤30): `Gastos privados, sin nube` *(25)*
- Alternative B: `Control de gastos privado` *(25)*

**3. Keywords** (≤100) *(87)*
```
finanzas,presupuesto,dinero,cartera,offline,voz,siri,sin banco,ahorro,billetera,recibos
```

**4. Description** (~2,100)
```
Budget Crab es la forma privada de controlar tu dinero. Registra un gasto en segundos: escríbelo o toca el micrófono y dilo en voz alta. Todo queda en tu iPhone.

Sin cuentas. Sin registro. Sin sincronización en la nube que nunca pediste. Cuando abres Budget Crab no hay dónde iniciar sesión, porque no hay a dónde: tus datos nunca salen del dispositivo.

QUÉ PUEDES HACER
• Registra ingresos y gastos en un par de toques
• Dicta una transacción con tu voz, transcrita en el dispositivo y nunca subida
• Agrega gastos directo desde Siri y la app Atajos
• Organiza con un sistema de categorías de dos niveles
• Consulta a dónde va tu dinero con resúmenes mensuales claros
• Exporta el mes actual a CSV, PDF u hoja de cálculo — gratis

GRATIS, SIN LETRA CHICA
Transacciones ilimitadas, gratis, para siempre. Sin límite mensual. Sin anuncios. Premium está ahí cuando quieras más: exportaciones de todo el historial (CSV / PDF / Excel), importación CSV, campos personalizados y filtros avanzados.

PRIVACIDAD POR ARQUITECTURA
No es una promesa de privacidad: así está construida la app. No hay servidores que guarden tus datos, ni SDK de analítica observándote, ni redes publicitarias en el código. Tus finanzas son tuyas.

PLANES
• Mensual: $3.99/mes
• Anual: $29.99/año con 7 días de prueba gratis (ahorra 37%)
• De por vida: $79.99, pago único

Los precios se muestran en tu moneda local al pagar. Las suscripciones se renuevan hasta que las canceles; puedes gestionarlas o cancelarlas cuando quieras en Ajustes.

Budget Crab se desarrolla de forma independiente. Sin inversores, sin anuncios, sin negocio de datos — solo una herramienta enfocada que respeta tu dinero y tu privacidad.
```

**5. Promotional Text** (≤170) *(152)*
```
Registra gastos en segundos, escritos o por voz. Todo se queda en tu iPhone. Sin cuentas, sin nube, sin anuncios. Transacciones ilimitadas, gratis para siempre.
```

**6. What's New — v1.0**
```
Budget Crab ya está aquí. Control de dinero privado que nunca sale de tu iPhone: escribe o dicta una transacción, agrega gastos desde Siri y exporta tu mes a CSV, PDF u hoja de cálculo. Transacciones ilimitadas, gratis para siempre. Gracias por probarlo — dinos qué te gustaría después.
```

---

## 🇧🇷 pt-BR Metadata

**1. App Name** (≤30): `Budget Crab` *(11)*

**2. Subtitle** (≤30): `Controle de gastos privado` *(26)*
- Alternative B: `Gastos privados, sem nuvem` *(26)*

**3. Keywords** (≤100) *(89)*
```
finanças,orçamento,dinheiro,carteira,offline,voz,siri,sem banco,economia,despesas,recibos
```

**4. Description** (~2,100)
```
O Budget Crab é o jeito privado de controlar seu dinheiro. Registre um gasto em segundos: digite ou toque no microfone e fale. Tudo fica no seu iPhone.

Sem contas. Sem cadastro. Sem sincronização na nuvem que você nunca pediu. Quando você abre o Budget Crab não há onde fazer login — porque não existe para onde. Seus dados nunca saem do aparelho.

O QUE VOCÊ PODE FAZER
• Registrar receitas e despesas em alguns toques
• Ditar uma transação com a voz — transcrita no aparelho e nunca enviada
• Adicionar gastos direto pela Siri e pelo app Atalhos
• Organizar com um sistema de categorias em dois níveis
• Ver para onde vai seu dinheiro com resumos mensais claros
• Exportar o mês atual em CSV, PDF ou planilha — de graça

GRÁTIS, SEM PEGADINHA
Transações ilimitadas, grátis, para sempre. Sem limite mensal. Sem anúncios. O Premium está lá quando você quiser mais: exportações de todo o histórico (CSV / PDF / Excel), importação CSV, campos personalizados e filtros avançados.

PRIVACIDADE POR ARQUITETURA
Não é uma promessa de privacidade: é como o app foi feito. Não há servidores guardando seus dados, nem SDKs de análise observando você, nem redes de anúncios no código. Suas finanças são suas.

PLANOS
• Mensal: $3.99/mês
• Anual: $29.99/ano com 7 dias grátis (economize 37%)
• Vitalício: $79.99, pagamento único

Os preços aparecem na sua moeda local no pagamento. As assinaturas se renovam até você cancelar; é possível gerenciar ou cancelar quando quiser nos Ajustes.

O Budget Crab é desenvolvido de forma independente. Sem investidores, sem anúncios, sem negócio de dados — apenas uma ferramenta focada que respeita seu dinheiro e sua privacidade.
```

**5. Promotional Text** (≤170) *(150)*
```
Registre gastos em segundos, digitados ou por voz. Tudo fica no seu iPhone. Sem contas, sem nuvem, sem anúncios. Transações ilimitadas, grátis para sempre.
```

**6. What's New — v1.0**
```
O Budget Crab chegou. Controle de dinheiro privado que nunca sai do seu iPhone: digite ou dite uma transação, adicione gastos pela Siri e exporte seu mês em CSV, PDF ou planilha. Transações ilimitadas, grátis para sempre. Obrigado por experimentar — conte o que você quer a seguir.
```

---

## 🇺🇦 uk Metadata

**1. App Name** (≤30): `Budget Crab` *(11)*

**2. Subtitle** (≤30): `Приватний трекер витрат` *(23)*
- Alternative B: `Витрати під контролем` *(21)*

**3. Keywords** (≤100) *(87)*
```
фінанси,бюджет,гроші,гаманець,офлайн,голос,siri,без банку,заощадження,чеки,планувальник
```

**4. Description** (~2,050)
```
Budget Crab — приватний спосіб стежити за грошима. Додайте витрату за секунди: введіть вручну або торкніться мікрофона й продиктуйте. Усе залишається на вашому iPhone.

Без облікових записів. Без реєстрації. Без хмарної синхронізації, про яку ви не просили. Коли ви відкриваєте Budget Crab, входити нікуди — бо входити ні в що. Дані не покидають пристрій.

ЩО ВСЕРЕДИНІ
• Доходи й витрати за кілька дотиків
• Диктування транзакцій голосом — розпізнавання на пристрої, нічого не завантажується
• Додавання витрат прямо із Siri та застосунку «Команди»
• Зрозуміла дворівнева система категорій
• Ясні місячні підсумки — видно, куди йдуть гроші
• Експорт поточного місяця у CSV, PDF або таблицю — безкоштовно

БЕЗКОШТОВНО, БЕЗ ПІДСТАВ
Транзакції без ліміту — безкоштовно й назавжди. Без місячних обмежень. Без реклами. Premium — коли захочете більше: експорт за весь час (CSV / PDF / Excel), імпорт CSV, власні поля та розширені фільтри.

ПРИВАТНІСТЬ ЗА АРХІТЕКТУРОЮ
Це не обіцянка приватності — так побудовано застосунок. Немає серверів, де зберігалися б ваші дані. Немає аналітичних SDK. Немає рекламних мереж у коді. Ваші фінанси належать лише вам.

ТАРИФИ
• Місяць: $3.99/міс
• Рік: $29.99/рік, 7 днів безкоштовно (економія 37%)
• Назавжди: $79.99, разовий платіж

Ціни показуються у вашій валюті під час оплати. Підписки поновлюються автоматично до скасування; скасувати можна будь-коли в Налаштуваннях.

Budget Crab розроблено незалежно. Без інвесторів, без реклами, без торгівлі даними — просто зосереджений інструмент, який поважає ваші гроші та вашу приватність.
```

**5. Promotional Text** (≤170) *(150)*
```
Записуйте витрати за секунди — вручну або голосом. Усе залишається на iPhone. Без облікових записів, без хмари, без реклами. Транзакції без ліміту — безкоштовно назавжди.
```

**6. What's New — v1.0**
```
Budget Crab уже тут. Приватний облік грошей, що не покидає iPhone: вводьте або диктуйте транзакцію, додавайте витрати із Siri та експортуйте місяць у CSV, PDF чи таблицю. Транзакції без ліміту — безкоштовно назавжди. Дякуємо, що спробували — напишіть, що додати далі.
```

---

## 7. In-App About Screen Copy (recommendation)

> Copy recommendation only — **not applied to `.strings`** per brief's no-code constraint. Stage into `about.*` keys when ready.

**EN**
```
Budget Crab

A private money tracker that stays on your iPhone. No servers, no accounts, no tracking — your finances never leave the device.

Built independently. No investors, no ads, no data business.

Version 1.0
```
Localize the tagline + trust line per the strings in §8.

---

## 8. Paywall / Trust Line Copy (updated, per Quiet Premium)

Trust line — placed **near the end** of the paywall, not as a headline:

| Locale | Trust line |
|---|---|
| EN | Built independently. No investors, no ads, no data business. |
| RU | Разработано независимо. Без инвесторов, без рекламы, без торговли данными. |
| ES | Desarrollado de forma independiente. Sin inversores, sin anuncios, sin negocio de datos. |
| PT-BR | Desenvolvido de forma independente. Sem investidores, sem anúncios, sem negócio de dados. |
| UK | Розроблено незалежно. Без інвесторів, без реклами, без торгівлі даними. |

Architecture-first value line (lead of paywall, replaces any "we promise" phrasing):
- EN: *"Everything stays on your iPhone — no servers exist to hold it."*

---

## 9. ASC Fill Order

1. App Information → **Name** ("Budget Crab"), **Subtitle**, **Primary/Secondary category**.
2. Pricing and Availability → confirm tiers map to `bc_premium_monthly` $3.99 / `bc_premium_annual` $29.99 / `bc_premium_lifetime` $79.99.
3. Subscriptions → **configure the 7-day introductory (free trial) offer** on `bc_premium_annual` (⚠️ not in local `.storekit`; must be set here — see §11).
4. Per-locale **Localizable** metadata (EN first as source, then RU, ES, pt-BR, uk): Subtitle → Keywords → Description → Promotional Text.
5. What's New: **leave empty for 1.0** (see §11 note); stage the §6 copy for 1.0.x.
6. Screenshots + App Preview.
7. App Privacy (already answered — see `APP_PRIVACY_ANSWERS.md`).
8. Review notes: mention on-device speech + App Shortcuts; no login required.

---

## 10. Final pre-submit checks

- [ ] All prices read **$3.99 / $29.99 / $79.99** across all 5 descriptions ✅ (consistent as written)
- [ ] Trial period reads **7 days** in every locale: `7-day / 7 дней / 7 días / 7 dias / 7 днів` ✅
- [ ] Savings claim **37%** everywhere ✅
- [ ] Every constrained field ≤ Apple max (counts annotated inline) ✅
- [ ] Free-tier copy = **unlimited transactions** (NOT "10/month") — matches code ✅
- [ ] Forbidden phrases absent in all 5 locales ✅ (no "made with love", "one guy", "support solo dev", "Solo team", "Budget Crab Inc/Financial Services")
- [ ] No YNAB/Copilot comparison; word "Premium" only as plan name ✅
- [ ] "siri" keyword justified — real App Shortcuts exist ✅ (`AppIntents/BudgetCrabShortcuts.swift`)

### 🔴 Blockers to resolve outside this doc (code/config, not metadata)
1. **In-app paywall strings show OLD prices.** `en.lproj/Localizable.strings` still says `$34.99/year`, `$2.92/month`, `Save 42%`, and trial disclosures cite `$34.99` (L393–L412). These contradict the shipped $29.99 / 37% / $2.50-mo. **Update the `paywall.*` price strings in all 5 locales before submission** — otherwise the store listing and the in-app paywall disagree. (Not edited here per no-code constraint; flagged as required.)
2. **Confirm the 7-day intro offer is live in ASC** on `bc_premium_annual`. The app's own strings already promise it, but `FinanceTracker.storekit` has `introductoryOffer: null`. Advertising a trial that isn't configured = App Review rejection risk.

---

## 11. Notes on decisions

- **What's New for 1.0:** Per prior ASC copy decision (memory: `project_asc_copy_decisions`), 1.0 ships **without** a What's New entry — the Description carries the first-run story. §6 copy is provided per the brief's structure request and **staged for the first update (1.0.x / 1.1)**, not for the initial submission.
- **Currency symbols in copy:** Reference prices use `$` for consistency across locales; the App Store auto-localizes the *actual* charged price per storefront. Descriptions state "shown in your local currency at checkout" so no locale over-commits to USD.
- **RU territory:** RU localization ships for Russian-speaking users in **other** storefronts (RU App Store payment restrictions post-2022 remain). Latin brand kept per convention.
- **Keyword strategy:** name/subtitle words deliberately excluded from keyword fields (Apple indexes name+subtitle+keywords jointly; repetition wastes the 100-char budget). Long-tail "no bank / sin banco / sem banco / без банку / без банка" targets the anti-Plaid/anti-account-linking searcher — core to the privacy positioning.

---

## 12. Verification Log (code-grounded)

| Claim | Verified against | Result |
|---|---|---|
| $3.99 / $29.99 / $79.99 | `FinanceTracker.storekit` L98/126/18 | ✅ matches Path B |
| No transaction-count free-tier cap | grep `isPremium` — only in Settings/Data views | ✅ no volume gate; "10/mo" rejected |
| Premium gates all-time export + import + custom fields + filters | `DataSettingsView.swift` L94/107/120/142; `paywall.feature.*` | ✅ |
| Voice/on-device dictation | `Services/VoiceInputService.swift`, `InfoPlist.strings` | ✅ |
| Siri / App Shortcuts | `AppIntents/BudgetCrabShortcuts.swift`, `AddTransactionIntent`, `ShowSpendingIntent` | ✅ |
| Brand "Budget Crab" in 5 locales | `*/InfoPlist.strings` | ✅ |
| 7-day trial NOT in local config | `FinanceTracker.storekit` `introductoryOffer:null` | ⚠️ must set in ASC |
| In-app paywall price strings stale | `en.lproj` L393–L412 ($34.99 / Save 42%) | 🔴 fix before submit |

## 13. Change log v3 → v4

- Pricing updated Path B: $4.99→**$3.99**, $34.99→**$29.99**, $99.99→**$79.99**; trial 14d→**7d**; savings 42%→**37%**.
- Added **RU, pt-BR, uk** full metadata (were absent from v3 scope).
- **Corrected free-tier claim**: removed "10 transactions/month" → "unlimited transactions, free forever" (code-verified).
- Repositioned to **Quiet Premium**: architecture-first ("no servers exist"), trust line moved near-end, no competitor comparisons, "Premium" only as plan name.
- Flagged two launch **blockers** (stale in-app price strings; ASC trial config) that live outside this text deliverable.
