# Budget Crab — ASC Metadata (submission-ready, paste into App Store Connect)

**Source:** ASO_COPY_PACK.md (research-backed) + de-risk for §3.2.1 / 2.3. Char counts approximate — ASC counts live, trim if over.

## Feature-accuracy audit (2.3) — VERIFIED in code 2026-07-04
- ✅ **voice** — shipped (mic in QuickEntry). Keep.
- ✅ **widget** — shipped (BudgetCrabWidget: read-only Home-Screen NET widget via App Group). Keep.
- ✅ **subscriptions** — via the **Recurring** feature (recurring transactions + notifications). Keep (it's honest recurring tracking, not a bank scanner).
- ❌ **envelope** — NOT shipped (no envelope mode; only Safe-to-Spend + budgets). **REMOVED from all 5 keyword fields**, replaced with a "bills" term (real, via Recurring).
- ✅ offline / no ads / no bank linking / unlimited transactions / on-device — true. Keep.
No banned claims anywhere: no "best / #1 / free forever / encrypted / AI-powered".

## Global fields
- **Primary category:** Finance · **Secondary:** Productivity (or Utilities).
- **Age rating:** 4+.
- **Privacy Policy URL:** https://budgetcrab.app (privacy page) · **Support URL:** https://budgetcrab.app · **Marketing URL:** https://budgetcrab.app
- **App Privacy "nutrition label":** **Data Not Collected** (all data stays on-device, nothing transmitted). NSPrivacyTracking = false. No third-party SDKs collecting data.
- **App Review notes:** "No account or login required — the app is fully usable immediately. All data is stored on-device; nothing is transmitted. On first launch a guided onboarding + optional demo data show all features. This app is an expense tracker/notes tool, not a financial-services provider and not financial advice."
- **Positioning guardrail:** NOWHERE use "money management / banking / investing / financial services" in name/subtitle/description (submitting as Individual; position as expense tracker / private budget).

## Per-locale (Name ≤30 · Subtitle ≤30 · Keywords ≤100 no-spaces · Promo ≤170)

### 🇺🇸 EN
- Name: `Budget Crab: Expense Tracker` (28)
- Subtitle: `No bank linking, private budget` (30)
- Keywords: `money manager,cash,bills,widget,offline,voice,spending,savings,subscriptions,manual,no ads,daily`
- Promo: `Track spending in seconds — type or speak it. No bank linking, no ads, cancel anytime. Everything stays on your iPhone. Free to start, unlimited transactions.`

### 🇷🇺 RU
- Name: `Budget Crab: Трекер расходов` (28) · Subtitle: `Без привязки банка, приватно` (28)
- Keywords: `финансы,деньги,кошелек,наличные,счета,виджет,офлайн,голос,траты,экономия,подписки,без рекламы`
- Promo: `Записывайте траты за секунды — вручную или голосом. Без привязки банка, без рекламы, отмена в любой момент. Всё остаётся на iPhone. Бесплатный старт.`

### 🇪🇸 es-MX
- Name: `Budget Crab: Gastos privados` (28) · Subtitle: `Sin banco, control de gastos` (28)
- Keywords: `dinero,cartera,efectivo,recibos,widget,offline,voz,ahorro,gastos,suscripciones,sin anuncios,manual`
- Promo: `Registra gastos en segundos, escritos o por voz. Sin vincular el banco, sin anuncios, cancela cuando quieras. Todo queda en tu iPhone. Empieza gratis.`

### 🇧🇷 pt-BR
- Name: `Budget Crab: Controle de Gastos` (30) · Subtitle: `Sem banco, gastos privados` (26)
- Keywords: `dinheiro,carteira,dinheiro vivo,contas,widget,offline,voz,economia,despesas,assinaturas,sem anúncios`
- Promo: `Registre gastos em segundos, digitados ou por voz. Sem vincular o banco, sem anúncios, cancele quando quiser. Tudo fica no seu iPhone. Comece grátis.`

### 🇺🇦 uk
- Name: `Budget Crab: Трекер витрат` (26) · Subtitle: `Без банку, приватний бюджет` (27)
- Keywords: `фінанси,гроші,гаманець,готівка,рахунки,віджет,офлайн,голос,витрати,заощадження,підписки,без реклами`
- Promo: `Записуйте витрати за секунди — вручну або голосом. Без прив'язки банку, без реклами, скасування будь-коли. Усе на iPhone. Безкоштовний старт.`

## Descriptions — all 5 locales (paste each into its ASC localization). iOS: description does NOT affect ranking; it's conversion.

### 🇺🇸 EN
```
Budget Crab is the private way to track your money — no bank linking, no ads, no surprise charges. Type or speak a transaction and it's logged in seconds. Everything stays on your iPhone.

Know what's safe to spend. Set a monthly budget and see exactly how much is left, every day.

WHY BUDGET CRAB
• Private by design — all data stays on your iPhone, nothing is transmitted, no account needed
• No bank linking — add expenses manually or by voice, in seconds
• Safe-to-spend — a clear monthly number, not a spreadsheet
• Honest billing — cancel anytime, no ads, no dark patterns
• Unlimited transactions, free to start
• Export anytime — CSV, PDF, Excel
• Works fully offline

PREMIUM
Start with a 30-day free trial, then $34.99/year (about $2.92/month). Monthly $4.99. Or Lifetime $99.99 — one-time, no subscription, shareable via Family Sharing. Cancel anytime in Settings.

Budget Crab is a personal expense-tracking tool for informational purposes only. It does not provide financial, investment, or tax advice.

Subscriptions auto-renew until cancelled; manage or cancel anytime in Settings › Apple ID › Subscriptions. Privacy Policy and Terms of Use: https://budgetcrab.app
```

### 🇷🇺 RU
```
Budget Crab — приватный способ вести деньги: без привязки банка, без рекламы, без скрытых списаний. Введите или продиктуйте трату — она запишется за секунды. Всё остаётся на вашем iPhone.

Знайте, сколько можно потратить. Задайте месячный бюджет и каждый день видьте, сколько осталось.

ПОЧЕМУ BUDGET CRAB
• Приватность by design — все данные на вашем iPhone, ничего не передаётся, аккаунт не нужен
• Без привязки банка — добавляйте траты вручную или голосом, за секунды
• Safe-to-spend — понятная сумма на месяц, а не таблица
• Честные списания — отмена в любой момент, без рекламы, без тёмных паттернов
• Неограниченные транзакции, бесплатный старт
• Экспорт в любой момент — CSV, PDF, Excel
• Работает полностью офлайн

ПРЕМИУМ
Начните с 30 дней бесплатно, затем $34.99/год (около $2.92/мес). Помесячно $4.99. Или «Навсегда» $99.99 — разовая покупка, без подписки, доступна через Family Sharing. Отмена в любой момент в Настройках.

Budget Crab — персональный инструмент учёта расходов только для информационных целей. Он не предоставляет финансовых, инвестиционных или налоговых советов.

Подписки продлеваются автоматически до отмены; управлять и отменять можно в Настройки › Apple ID › Подписки. Политика конфиденциальности и Условия использования: https://budgetcrab.app
```

### 🇪🇸 es-MX
```
Budget Crab es la forma privada de controlar tu dinero: sin vincular el banco, sin anuncios, sin cargos sorpresa. Escribe o dicta un gasto y queda registrado en segundos. Todo se queda en tu iPhone.

Sabe cuánto puedes gastar. Define un presupuesto mensual y mira exactamente cuánto queda, cada día.

POR QUÉ BUDGET CRAB
• Privado por diseño: todos los datos se quedan en tu iPhone, nada se transmite, sin cuenta
• Sin vincular el banco: agrega gastos manualmente o por voz, en segundos
• Safe-to-spend: una cifra mensual clara, no una hoja de cálculo
• Cobros honestos: cancela cuando quieras, sin anuncios, sin patrones oscuros
• Transacciones ilimitadas, empieza gratis
• Exporta cuando quieras: CSV, PDF, Excel
• Funciona totalmente sin conexión

PREMIUM
Empieza con 30 días gratis, luego $34.99/año (unos $2.92/mes). Mensual $4.99. O de por vida $99.99: pago único, sin suscripción, compartible con Family Sharing. Cancela cuando quieras en Ajustes.

Budget Crab es una herramienta personal de control de gastos solo con fines informativos. No ofrece asesoría financiera, de inversión ni fiscal.

Las suscripciones se renuevan automáticamente hasta cancelarlas; administra o cancela en Ajustes › Apple ID › Suscripciones. Política de Privacidad y Términos de Uso: https://budgetcrab.app
```

### 🇧🇷 pt-BR
```
O Budget Crab é o jeito privado de controlar seu dinheiro: sem vincular o banco, sem anúncios, sem cobranças surpresa. Digite ou dite um gasto e ele é registrado em segundos. Tudo fica no seu iPhone.

Saiba quanto pode gastar. Defina um orçamento mensal e veja exatamente quanto resta, todo dia.

POR QUE O BUDGET CRAB
• Privado por design: todos os dados ficam no seu iPhone, nada é transmitido, sem conta
• Sem vincular o banco: adicione gastos manualmente ou por voz, em segundos
• Safe-to-spend: um número mensal claro, não uma planilha
• Cobrança honesta: cancele quando quiser, sem anúncios, sem padrões enganosos
• Transações ilimitadas, comece grátis
• Exporte quando quiser: CSV, PDF, Excel
• Funciona totalmente offline

PREMIUM
Comece com 30 dias grátis, depois $34.99/ano (cerca de $2.92/mês). Mensal $4.99. Ou Vitalício $99.99: pagamento único, sem assinatura, compartilhável via Family Sharing. Cancele quando quiser nos Ajustes.

O Budget Crab é uma ferramenta pessoal de controle de gastos apenas para fins informativos. Não oferece consultoria financeira, de investimentos ou fiscal.

As assinaturas renovam automaticamente até o cancelamento; gerencie ou cancele em Ajustes › Apple ID › Assinaturas. Política de Privacidade e Termos de Uso: https://budgetcrab.app
```

### 🇺🇦 uk
```
Budget Crab — приватний спосіб вести гроші: без прив'язки банку, без реклами, без прихованих списань. Введіть або продиктуйте витрату — вона запишеться за секунди. Усе залишається на вашому iPhone.

Знайте, скільки можна витратити. Задайте місячний бюджет і щодня бачте, скільки лишилося.

ЧОМУ BUDGET CRAB
• Приватність by design — усі дані на вашому iPhone, нічого не передається, акаунт не потрібен
• Без прив'язки банку — додавайте витрати вручну або голосом, за секунди
• Safe-to-spend — зрозуміла сума на місяць, а не таблиця
• Чесні списання — скасування будь-коли, без реклами, без темних патернів
• Необмежені транзакції, безкоштовний старт
• Експорт будь-коли — CSV, PDF, Excel
• Працює повністю офлайн

ПРЕМІУМ
Почніть із 30 днів безкоштовно, потім $34.99/рік (близько $2.92/міс). Помісячно $4.99. Або «Назавжди» $99.99 — разова покупка, без підписки, доступна через Family Sharing. Скасування будь-коли в Налаштуваннях.

Budget Crab — персональний інструмент обліку витрат лише для інформаційних цілей. Він не надає фінансових, інвестиційних чи податкових порад.

Підписки поновлюються автоматично до скасування; керувати та скасувати можна в Налаштування › Apple ID › Підписки. Політика конфіденційності та Умови використання: https://budgetcrab.app
```

## Screenshot captions — OCR-indexed ASO lever (NEW 2026, verify before upload)
Apple now **indexes text inside screenshots via OCR** (NotebookLM 04c87827). Make captions work double as keywords:
- **Keyword-rich, top-left quadrant, ≥40pt, clean sans-serif** (scanning bias + indexing threshold).
- **Lead with privacy + simplicity** (the top-2 converting value props); honest-billing is trust/support, NOT the lead hook.
- Recommended caption sequence (localize per locale):
  1. `100% Private · On-device only` (hits "Private" + "Finance")
  2. `No bank linking` (mechanism)
  3. `Track in 10 seconds` (outcome, not feature list)
  4. `Safe to spend, every day`
  5. `Export anytime · CSV / PDF / Excel`
  6. `Cancel anytime · no ads` (honest-billing = support)
- Action: verify the current composed screenshots carry these (top-left, ≥40pt); if captions are generic, re-run compose-screenshots.py with these before final ASC upload.

## Post-launch (v1.1) keyword adds
Once shipped: `receipt,scan,photo,ai` (receipt/AI entry), `couple,family` (CloudKit sharing). Then A/B the Name via Product Page Optimization.
