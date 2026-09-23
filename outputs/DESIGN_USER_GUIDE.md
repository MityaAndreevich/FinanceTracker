# DESIGN — The in-app User Guide ("How to use Budget Crab"), 1.0.7

**Status: DESIGN ONLY — awaiting Dmitry's approval. No code, no strings written.** Written
2026-09-22 at HEAD `a9ff5ef` (working tree `MARKETING_VERSION` 1.0.6 / build 11). Brief:
`BRIEF_MASTER_2026-09-21.md` Phase 3 (`:204–268`), with the founder's 2026-09-22 scope change: write
the design now for everything that exists plus Reports, with the scanning card as a named
placeholder (§5). Evidence and the pre-registered acceptance test: `PLAN_TUTORIAL_AND_HELP.md`.

**Every step in every card below was verified against the build before it was written** — file and
line are given per card — because a guide is nothing but claims (brief §2.8), and a support reply
was nearly sent with a step that does not exist (`PLAN_TUTORIAL_AND_HELP.md` §1.4). The
verification also found **five shipped sentences that are false today** and **one instruction in
the brief that the build contradicts**. They are in §1.3 and §2, and they change what the guide
says.

---

## 0. What this is, in one paragraph

Three layers, per the brief: (1) a short skippable **walkthrough** on first run, re-playable from
Settings; (2) **the Guide** — one card per feature, grouped by what the user wants to do, each with
a purpose sentence, steps, a screenshot of the real screen, and a **Show me** button that lands the
user on that screen; (3) **contextual hints** — one at a time, once, on the screen where an unused
capability sits. Plus on-device measurement of whether the walkthrough was completed and which
cards were opened. The design's one structural idea: **card text names UI controls by string key,
not by retyped words**, so the guide is rendered from the same table the screens are — a button
cannot be called one thing on the screen and another in the guide (§9).

---

## 1. Ground read — what teaches today, and what it gets wrong

### 1.1 What exists (verified at HEAD)

| surface | what it is | where | evidence |
|---|---|---|---|
| Greeting + 3 coach marks + first-win card | `OnboardingCoordinator`, steps `quickAdd → budget → analyticsTab`, on the real Dashboard controls; "Skip" ends it for good | first launch; **re-playable** via Settings → General → Tutorial & Sample Data → "Replay tutorial" | `Views/Onboarding/Coachmarks/OnboardingCoordinator.swift:31, 86–106`; `GeneralSettingView.swift:409`; `ContentView.swift:335–338` |
| First-win card | "Try your first entry" — Add one now / Explore with demo data / Maybe later | end of the walkthrough | `Views/Onboarding/FirstWinView.swift` |
| Demo sandbox | adds locale-appropriate rows flagged `isDemo` to the user's store; cleared from the Dashboard banner or General | first-win card; Settings → General | `Data/DemoSeeder.swift:116–151` |
| Learn & Tips | tip of the day (one reveal per day), seen tips, search over unlocked tips, **and four help articles** (Getting started, Advanced, Privacy, Contact) | Settings → Learn & Tips | `Views/Settings/LearnAndTipsView.swift`; `Services/TipDeck.swift:73–99` |
| "Set up Widget & Siri" | two articles: widget, Siri | Settings row | `SettingsView.swift`; strings `help.widget.*`, `help.siri.*` |
| One-shot hints | `onboarding.hint.openform` (Quick Entry, empty state, first open); `onboarding.hint.period` (Transactions month pager, first visit) | in place | `QuickEntryView.swift:691–698`; `TransactionsView.swift` |
| Dashboard teaching slot | exactly one card: empty-ledger arrow → tip of the day → "Insights coming as you track" | Dashboard | `DashboardView.swift:1170–1186` |
| Discoverability footers | `add.category.split_hint` (form), `cs.category.limit_hint` (Categories & Accounts), `add.source.tip` | in place | `AddTransactionView.swift`; `CategoriesSourcesView.swift:236` |

**What is NOT there:** a feature library; any way to get from a description to the screen; any
record of whether the walkthrough was seen, skipped or completed (`PLAN_TUTORIAL_AND_HELP.md` §3).
`OnboardingView` (language/currency screens) and the 3-page carousel are retired; their strings are
dead (`Shared/LocaleAutoDetect.swift:8, 86`).

### 1.2 What the Guide does with the existing surfaces (proposal)

- **Absorb** the four Learn & Tips help articles and the two "Set up Widget & Siri" articles into
  Guide cards. Both rows go; one row, **"How to use Budget Crab"**, takes the first position of
  Settings group 2. Learn & Tips keeps the tips and loses the articles. (Six articles in two places
  is the scatter the brief is fixing.)
- **Keep** the coach-mark coordinator as the walkthrough engine (§6) — it is live, on real controls,
  and already re-playable. The walkthrough grows from 3 marks to 5 and gains the instrumentation
  `PLAN_TUTORIAL_AND_HELP.md` §6 puts first.
- **Keep** the existing one-shot hints and footers; the contextual-hint layer (§8) generalises the
  mechanism they already use rather than adding a second one.

### 1.3 Shipped teaching copy that is FALSE against the build — found by this pass

These are §2.8 defects. Each is a sentence a user can read today. **None is fixed here** (doc only);
they are filed for the 1.0.7 string pass and the guide is written so as not to repeat them.

| # | string | what it claims | what the build does | evidence |
|---|---|---|---|---|
| C1 | `help.widget.body` | the widget *"shows this month's net at a glance"* | the hero is **Safe to spend / Over budget / Spent** depending on whether a budget is set | `BudgetCrabShared/NetSnapshot.swift`; `BudgetCrabWidget.swift:639–655` |
| C2 | `cs.category.limit_hint` | *"set a monthly limit **and see how much of it is left**"* | the row shows only `Limit: %@/month`. **No surface shows a remainder** — not the row, not the Dashboard, not Analytics. The only over-limit line is in the month Report | `CategoriesSourcesView.swift:450`; `CategoryLimitPolicy` is consumed by no view |
| C3 | `help.siri.body` | *"Say 'Hey Siri, add ten dollars groceries in Budget Crab'"* | the registered phrases are exact: "Add transaction/expense to Budget Crab", "Record transaction in Budget Crab"; parameters are asked for ("How much?", "Which category?"). The quoted sentence is **not a registered phrase**; whether Siri resolves it is not guaranteed and was not verified | `AppIntents/BudgetCrabShortcuts.swift:31–35`; `AddTransactionIntent.swift:14–19` |
| C4 | `add.source.expense_disabled_hint` | *"Account is available only for income transactions."* | **dead string, used nowhere** — and false: accounts attach to both directions (§2) | grep `expense_disabled_hint` in `*.swift` → 0 |
| C5 | `tab.add` = "Add", `quick_entry.title` = "Quick entry" | that the centre tab and the sheet have those labels | the centre tab is icon-only; the sheet has no title. Both strings unused. A guide that says "tap the Add tab" describes nothing on the screen | `ContentView.swift:138–140`; grep → 0 uses |

Also unused and misleading if ever cited: `quick_entry.voice.start/.stop`, `onboarding.language.*`,
`onboarding.currency.*`, `tutorial.page1–3`, `edit.section.currency` / `edit.currency.picker`,
`data.import.progress.format` (progress is a no-op, `DataSettingsView.swift:282–285`). The guide's
claim test (§12.2) fails on any card that references a key with zero Swift uses, so none of these
can enter it.

---

## 2. The brief vs the build — accounts

Brief `:237–238`: *"accounts (and the fact that they attach to INCOME only — say it, do not let
users hunt for it)"*.

**The build attaches accounts to both income and expense.** The add form's Account section is
unconditional (`AddTransactionView.swift:427–452`; the save at `:557` is commented *"Account
available for both income and expense"*), and so is the editor's (`EditTransactionView.swift:397–413`).
`CLAUDE.md` lists *"Restricting Source/Account to income-only"* as an anti-pattern. The only trace of
"income only" is the dead string C4.

**The guide follows the build** (§2.8: the sentence changes, not the code). Card A8 says accounts
work on both. **Dmitry: confirm** — if income-only is what you *want*, that is a product change and a
separate decision; the guide will not say it until the build does.

What IS true and worth saying so nobody hunts: Quick Entry and voice **never** set an account
(`QuickAddSaveService.swift:81` passes `source: nil`) — an account is attached in the full form or
by editing afterwards. Card A8 says that.

---

## 3. The three layers, and where the Guide lives

```
Settings
  ├─ General · Premium · Data · Categories & Accounts · Recurring · Privacy   (group 1, unchanged)
  └─ How to use Budget Crab   ← NEW, first in group 2 (replaces "Set up Widget & Siri")
     Alerts · Reports · Learn & Tips (tips only) · Tell me what's missing · About
```

**Guide root screen:** six groups as section headers (brief `:231–233`), each card a row (icon,
title, one-line purpose). Search field over card titles and purposes. A top card "Replay the
walkthrough" (the existing replay action, moved here; it stays in General too — two entry points
cost nothing).

**Card screen:** title → purpose sentence → screenshot (annotated) → numbered steps → "Show me"
button (prominent, bottom) → tier line when the feature is Premium or capped → "Related" links to
other cards. No card may contain a sentence about a future version.

**Group order** is the brief's, which is the order a new user needs them: Record spending → Control
a budget → See where money goes → Import and export → Automate → On your iPhone.

---

## 4. THE CARDS — full English text

Format per card: **Purpose** (one sentence a normal person understands) · **Steps** · **Screenshot**
(what is captured, what is annotated) · **Show me →** destination (§7) · **Tier** · **Verified**
(file:line for every step). Words in `{braces}` are **string keys rendered live from the string
table** (§9), shown here with their English value. 26 cards + 1 placeholder.

### Group A — Record spending

**A1 · Add an expense in seconds**
Purpose: Type what you bought and how much, in any order, and Budget Crab files it under the right
category.
Steps:
1. Tap the **+** in the middle of the tab bar. *(It has no label — it is the round plus.)*
2. Type an amount and a word or two — `Starbucks 5.50`, `lunch 12`, `67 gas`. Order doesn't matter.
3. The card under the field shows the amount, **{analytics.label.expense}** or **{analytics.label.income}**, and the category Budget Crab picked. Tap that row to choose a different category.
4. Tap **{quick_entry.save}**. Or **{quick_entry.save_add_another}** to keep going.
5. For income, start with **+** (`+2800 paycheck`) or use a word like *salary*, *refund*, *received*.
Screenshot: Quick Entry with `Starbucks 5.50` parsed; annotation ring on the category row and on Save.
Show me → `quickEntry` (presents the sheet).
Tier: free.
Verified: tab + `ContentView.swift:138–140, 176–195`; parser order-free and locale-aware `QuickAddParser.swift:43–63, 188–222`; direction inferred only `QuickAddParser.swift:66–70, 304–359`; preview row → `CategoryPickerSheet` `QuickEntryView.swift:470–535`; save/dismiss `QuickEntryView.swift:1023–1062`; Save & add another `:671–686, 1068–1083`; category chain learned→keyword→"Other" `QuickAddSaveService.swift:167–188`.
Not said, because not true: no income/expense switch in Quick Entry; no account, date, note or tax here (card A4).

**A2 · The Quick Add bar on the Dashboard**
Purpose: The field at the top of the Dashboard saves a confident entry the moment you submit it — and lets you undo it.
Steps:
1. On **{tab.dashboard}**, type into the bar under the title (`{quickadd.placeholder}` shows an example) and tap the arrow.
2. If Budget Crab is sure, it saves at once and shows **{quickadd.saved.tap_to_edit}** with **Undo** for 30 seconds. Shaking the phone also undoes it.
3. If it isn't sure, you get a preview with **{quickadd.preview.save}** and **{quickadd.preview.edit}**.
4. Choose how sure it must be: **{tab.settings}** → **{settings.general}** → **{settings.quickadd.sensitivity.label}** — Confirm, Balanced or Instant.
Screenshot: Dashboard with the saved toast + Undo visible.
Show me → `dashboardQuickAdd` (tab 0, focus the bar).
Tier: free.
Verified: bar pinned `DashboardView.swift:293–299, 1220–1260`; auto-save ≥ threshold (default 0.75), toast + Undo 30 s, shake `DashboardView.swift:331–353, 455–472`; sensitivity picker `GeneralSettingView.swift` (`settings.quickadd.sensitivity.*`).
Not said: there is no mic on this bar (A3).

**A3 · Say it instead of typing**
Purpose: Tap the microphone and speak the entry; the words are recognised on your iPhone and never sent anywhere.
Steps:
1. Open Quick Entry (**+**) and tap the **microphone** at the right of the field.
2. The first time, allow the microphone and speech recognition when iOS asks.
3. Speak — *"coffee four fifty"*. You'll see **{quick_entry.listening}** and your words appearing.
4. Stop talking; listening ends by itself after a short pause (or tap the button again). Check the card, then **{quick_entry.save}**.
5. Voice follows the app language: English, Русский, Español, Português, Українська. If it isn't available for your language you'll see **{voice.unavailable_for_lang}**.
Screenshot: the recording panel with waveform and live transcript.
Show me → `quickEntry`.
Tier: free.
Verified: mic only in the Quick Entry bar `QuickEntryView.swift:795, 809–823`; permissions `VoiceInputService.swift:179–224`; panel `QuickEntryView.swift:827–872`; auto-stop 1.8 s `VoiceInputService.swift:54, 295–302`; `requiresOnDeviceRecognition = true` `:242`; language chain `:67–134`; unsupported banner `QuickEntryView.swift:1004–1011`.

**A4 · The full form: date, account, note, tax**
Purpose: When an entry needs more than an amount and a name, open the detailed form.
Steps:
1. In Quick Entry tap **{quick_entry.use_form}**. (What you typed comes with you.)
2. Fill in, top to bottom: **{add.type.expense}** / **{add.type.income}** · **{add.section.amount}** (and **{add.tax.placeholder}** if you want) · **{add.section.title}** · **{add.section.category}** · **{add.section.source_optional}** · **{add.section.date}** · **{add.section.note}** · **{addtx.recurring.header}**.
3. Amount and category are the only required fields. The date can be any day from 1990 to a year ahead.
4. Tap **{common.add}**.
All entries use the currency chosen in **{settings.general}** → **{general.currency}**.
Screenshot: the form, scrolled to show Type through Date.
Show me → `addForm` (presents `AddTransactionView`).
Tier: free.
Verified: reached only from Quick Entry / prompts, not the tab bar `QuickEntryView.swift:705–723`; section order `AddTransactionView.swift:122–134`; required = amount + category `:118–120`; date window `:35–36, 544–549`; currency locked to default `:554`.

**A5 · Change or delete an entry**
Purpose: Every entry can be corrected or removed from the Transactions list.
Steps:
1. Open **{tab.transactions}** and tap the entry. The editor opens — change anything and tap **{common.save}**.
2. To delete: swipe the row left and tap **{common.delete}**, then confirm. (Touch and hold a row for the same choices.)
3. Just saved something from the Dashboard bar? Tap the **{quickadd.saved.tap_to_edit}** toast to open it.
Screenshot: a row swiped left showing Delete and Edit.
Show me → `transactions`.
Tier: free.
Verified: tap → editor `TransactionsView.swift:594–598, 118–120`; swipe/context actions `:601–620`; delete confirm `:135–147`; toast → editor `DashboardView.swift:325–335`.
Not said: there is no delete button inside the editor; Dashboard "Recent" rows are not tappable (`DashboardView.swift:1090–1101`) — the card sends users to the list.

**A6 · Find an entry**
Purpose: Search by name, note, category or even amount; move between months; filter to income or expenses.
Steps:
1. On **{tab.transactions}** type in **{transactions.search.prompt}** — words or a number like `12.50`.
2. Use **‹ ›** under the title to change month.
3. Tap **{transactions.filter.all}**, **{transactions.filter.income}** or **{transactions.filter.expense}**.
4. Entries are grouped by day; each day header shows that day's spending.
Screenshot: list with a search term and the month pager.
Show me → `transactions`.
Tier: free.
Verified: search incl. amounts `TransactionsView.swift:359–370`; pager `:88`; chips `:163–187`; day groups + subtotal `:586–662`.

**A7 · Categories: add your own, choose which show first**
Purpose: Thirteen categories are built in; add more, and decide which ones appear as quick picks.
Steps:
1. **{tab.settings}** → **{settings.categories}**.
2. In **{cs.section.expense_categories}** or **{cs.section.income_categories}** tap **{cs.categories.add}** — pick a suggested one or type a name and, optionally, a symbol.
3. Each category has a **{cs.category.shown_by_default}** switch. Switched on, it appears in the row of quick picks when you open Quick Entry (up to six). Every category is always available in the full picker.
4. To remove a category, swipe it left. A category that is used by any entry can't be deleted.
You can also add a category while entering: in the category picker tap **{category.picker.add_new}**.
Categories can't be renamed or reordered yet.
Screenshot: the Expense categories section with one row's switch and the Add Category button ringed.
Show me → `categoriesAndAccounts`.
Tier: free includes 3 custom categories on top of the built-in 13; Premium removes the cap. Existing categories always stay.
Verified: sheet + presets + symbol `AddCategorySheet.swift:169–177`; in-flow add `CategoryPickerSheet.swift:59–75`; toggle only drives Quick Entry chips `CategoriesSourcesView.swift:432–463`, `QuickEntryView.swift:399–405`; delete blocked when used incl. split parts `CategoriesSourcesView.swift:368–389`; 13 seeded `SeedService.swift:57–72`; cap 3 `FreeTierLimits.swift:32`; **no rename/reorder** — grep `onMove|EditButton|rename` in `Views/` → 0.

**A8 · Accounts: which card, bank or wallet**
Purpose: Tag an entry with the account it came from — for expenses and income alike.
Steps:
1. **{tab.settings}** → **{settings.categories}** → under **{cs.section.sources}** tap **{cs.sources.add}**; give it a name (and a note if you like).
2. When adding with the full form, choose it under **{add.section.source_optional}** — or tap **{add.source.add}** right there.
3. Quick Entry and voice don't set an account. To add one to an entry saved that way, open it from **{tab.transactions}** and pick the account.
4. An account used by any entry can't be deleted.
Screenshot: the form's Account picker open.
Show me → `categoriesAndAccounts`.
Tier: free includes 2 accounts; Premium removes the cap. Existing accounts always stay.
Verified: both directions `AddTransactionView.swift:427–452, 557`, `EditTransactionView.swift:397–413, 560`; inline add `AddTransactionView.swift:720–778`; Quick Entry passes `source: nil` `QuickAddSaveService.swift:81`; delete blocked when used `CategoriesSourcesView.swift:294–321`; cap 2 `FreeTierLimits.swift:28`. **See §2 — the brief said income-only; the build says both.**

**A9 · One purchase, several categories (split)**
Purpose: A supermarket run that was part food, part household — assign parts of one amount to other categories.
Steps:
1. Save the purchase, then open it from **{tab.transactions}**.
2. Scroll to **{split.section}** and tap **{split.add_part}**.
3. Enter the part's amount and **{split.pick_category}**. Add more parts if you need.
4. Whatever you don't assign stays in the main category. If the parts add up to more than the total, Save is disabled until you fix it.
5. Tap **{common.save}**. The entry shows a **{transactions.split.badge}** badge; Analytics counts each category's share.
Only expenses can be split.
Screenshot: the editor's split section with two parts and the remainder line.
Show me → `transactions` (the split lives inside an entry; the hint on arrival says "tap an entry").
Tier: free.
Verified: section in editor, expense-only `EditTransactionView.swift:133–135, 302–321`; remainder / over-sum / incomplete rules `:94–125`; badge `CategoryTileRow.swift:104`; shares in Analytics `CategoryAttribution`.
Not said: the "Transaction Details" screen route (Analytics → Pulse → day → row) also offers **{split.add_part}** — true but a longer path; the card teaches the short one.

**A10 · Scan a receipt — PLACEHOLDER, see §5.**

### Group B — Control a budget

**B1 · Set a monthly budget and see what's safe to spend today**
Purpose: Tell Budget Crab how much you want to spend this month, and the Dashboard turns into a single number: what you can spend today and still finish the month under budget.
Steps:
1. On **{tab.dashboard}** tap **{dashboard.budget.cta.title}** (or later, tap the big number's label — it has a pencil). You can also set it in **{tab.settings}** → **{settings.general}** → **{settings.budget.label}**.
2. Enter the amount and save.
3. The Dashboard now shows **{dashboard.safe_today}** — what's left this month divided by the days left — with **{dashboard.days_left}** and a ring of how much of the budget is used.
4. Under it, a pace line tells you whether you're on track. If you go over, the number turns negative and reads **{dashboard.over_budget}**.
Only entries dated up to today count; a future-dated expense doesn't reduce today's number.
Screenshot: Dashboard hero with a budget set; annotation on the label/pencil and the ring.
Show me → `dashboardBudget` (tab 0 + presents `BudgetSetterSheet`).
Tier: free.
Verified: two entry points, same storage `DashboardView.swift:268–272, 762–779, 865–897`, `GeneralSettingView.swift:282–329`; hero modes `DashboardView.swift:155–159, 755–951`; remainder = budget − spent through today, future excluded `SafeToSpend.swift:57–59, 110–123`; per-day = remaining / days left `DailyAllowance.swift:48–90`; over-budget hides pace `DashboardView.swift:803`.

**B2 · A monthly limit for one category**
Purpose: Cap a single category — coffee, eating out — and see the cap on its row; the month report tells you if you went over.
Steps:
1. **{tab.settings}** → **{settings.categories}**.
2. Tap any expense category (income categories have no limit).
3. Enter **{limit.amount.placeholder}** and save. The row now reads **{cs.category.limit_label.format}**. **{limit.clear}** removes it.
4. Where you'll see it: with Premium and **{alerts.toggle}** on, you get one heads-up when a category reaches about 70% of its limit while there's still money in it. The month **{reports.title}** shows a line when categories are over their limit.
Screenshot: Categories & Accounts with an expense row ringed and the limit sheet open.
Show me → `categoryLimits` (Settings → Categories & Accounts, scrolled to expense categories, first expense row pulsed).
Tier: setting a limit is free; the heads-up notification is Premium.
Verified: tap expense row only `CategoriesSourcesView.swift:208, 480–545`; row label `:450`; 70% gain-framed once per month `CategoryLimitPolicy.swift:23–33, 97–100`, `ProactiveAlertPolicy.swift:70–78`; **nothing fires at/over the limit** `CategoryLimitPolicy.swift:30–34`; report line `ReportContentView.swift:98–104`.
Not said, because not true (C2): "see how much is left" — no surface shows a remainder. **This card is honest about that; the shipped footer is not.**

**B3 · A weekly "safe to spend" reminder** *(Premium)*
Purpose: One calm notification a week telling you what's safe to spend for the rest of the month.
Steps:
1. Set a monthly budget first (B1).
2. **{tab.settings}** → **{settings.alerts}** → switch on **{alerts.toggle}**. Allow notifications when iOS asks.
3. Choose **{alerts.day}** and **{alerts.time}**.
Nothing is sent when you're over budget — the reminder only ever tells you what's left. Nothing leaves your phone.
Screenshot: Alerts screen with the toggle on and day/time pickers.
Show me → `alerts`.
Tier: Premium.
Verified: four states `AlertsSettingsView.swift:33–50`; permission only on toggle `:139–150`; silent when remaining ≤ 0 `ProactiveAlertPolicy.swift:51–94`; body text `alerts.notif.body.safe.format`; refresh on every save/foreground `ProactiveAlertRefresher.swift:34–98`.
Not said: tapping the notification opens the app and nothing more (`AppDelegate.swift:46–50`, register D48).

### Group C — See where money goes

**C1 · Reading the Dashboard**
Purpose: One screen for this month: what's safe to spend, where the money went, and the latest entries.
Steps (what each part is, top to bottom):
1. The Quick Add bar (A2).
2. The big number: **{dashboard.safe_today}** if you have a budget; otherwise **{dashboard.safe_to_spend}** (income minus spending) or **{dashboard.hero.spent}**.
3. **{dashboard.spending_by_category}**: a ring of your top categories this month, with the biggest four listed. To dig into a category, use **{tab.analytics}** (C3).
4. One card that changes as you use the app — a tip, or a prompt when you're just starting.
5. **{dashboard.recent}**: the five newest entries; **{dashboard.see_all}** opens the list.
Screenshot: whole Dashboard, numbered callouts 1–5.
Show me → `dashboard`.
Tier: free.
Verified: order `DashboardView.swift:246–370`; hero modes `:155–159`; donut top-5 + Other, legend top-4, not tappable `:216–244`; teaching slot `:1170–1186`; recent 5 + See all `:1090–1101`.

**C2 · Pulse: this month, day by day**
Purpose: A line of your net cash flow for the last 30 days that you can drag across.
Steps:
1. **{tab.analytics}** → **{analytics.pulse.title}** at the top. (Swipe sideways to move between the three views.)
2. Drag along the chart; the number above follows your finger.
3. Tap the highlighted day to open that day's entries, grouped by category. Tap an entry there for its details.
4. Below the chart: **{analytics.earned_total}**, **{analytics.spent_total}** and whether you're spending faster or slower than usual.
Screenshot: Pulse with a scrubbed day and the chevron.
Show me → `analyticsPulse`.
Tier: free.
Verified: picker + swipe `AnalyticsView.swift:102–113, 130–133`; scrub → `DaySpendingSheet` `AnalyticsPulseView.swift`; day sheet rows → `TransactionDetailView` `DaySpendingSheet.swift:100`; pace cue `PaceMetric.swift`.

**C3 · Breakdown: which categories take the most**
Purpose: A ring of this month's spending (or income) by category, with the share of each.
Steps:
1. **{tab.analytics}** → **{analytics.breakdown.title}**.
2. Switch **{analytics.filter.expense}** / **{analytics.filter.income}**.
3. The five biggest categories get their own slice; the rest are **{analytics.breakdown.other}** — tap it to open them up.
4. Tap any category for its **{analytics.category_total}** and every entry in it. A split purchase shows only this category's part.
Screenshot: Breakdown with "Other" expanded.
Show me → `analyticsBreakdown`.
Tier: free.
Verified: filter, fold at 5, expand in place `AnalyticsBreakdownView.swift:78–114, 272–307`; `CategoryDetailView` header = Σ attributed rows.

**C4 · Horizon: the last twelve months**
Purpose: Month by month for a year — net, expenses, income, or both.
Steps:
1. **{tab.analytics}** → **{analytics.horizon.title}**.
2. Choose **{analytics.horizon.mode.net}**, **{analytics.horizon.mode.expenses}**, **{analytics.horizon.mode.income}** or **{analytics.horizon.mode.combined}**.
3. Drag across the bars; tap the label to see that month's entries.
Screenshot: Horizon with a month selected.
Show me → `analyticsHorizon`.
Tier: free.
Verified: modes persisted, scrubbing, tooltip → `MonthDetailSheet` `AnalyticsHorizonView.swift`.
Not said: Analytics has no period picker — Pulse/Breakdown are this month, Horizon is 12 months. Any other period is a Report (C5).

**C5 · Reports: any week, month, year or range — and share it**
Purpose: A one-page report for any period, compared with the period before, that you can read in the app or send as a PDF or spreadsheet.
Steps:
1. **{tab.settings}** → **{reports.title}**, or the magnifier button at the top of **{tab.analytics}**.
2. Pick **{reports.kind.week}**, **{reports.kind.month}**, **{reports.kind.year}** or **{reports.kind.custom}**; use **‹ ›** to move back. Custom takes any range up to five years.
3. Read it: **{reports.section.summary}** (each figure against the previous period), **{reports.section.budget}** (month reports, when a budget is set), **{reports.section.categories}**, **{reports.section.series.day}** or **{reports.section.series.month}**, **{reports.section.largest}**.
4. To share: tap **{reports.share}** → **{reports.share.pdf}** or **{reports.share.excel}**; for the PDF, **{reports.share.include_transactions}** adds the full list. Then tap **{reports.share.last.format}** to send it.
Reports are built on your iPhone when you open them, and nothing leaves your phone.
Screenshot: a month report, summary and comparison visible; the share menu open.
Show me → `reports`.
Tier: viewing any period is free. Sharing a **month** report is free; sharing a week, year or custom report is Premium.
Verified: entry points `SettingsView.swift:62–67`, `AnalyticsView.swift:136–149`; periods + 5-year cap `ReportsView.swift`; sections `ReportContentView.swift`; comparison rules `ReportSnapshot.swift:167–183`; budget section month-only `:200–218`; fold at 8 `ReportsView.swift:68`; gating per period `ReportsView.swift:285–292`; include-transactions default `ReportsView.swift:259–277`; Share row `:87–94`; privacy sentence = `ASC_WHATS_NEW_1_0_6.md` (approved, `STATE.md` §10).

### Group D — Import and export

**D1 · Import a CSV from your bank, Mint, YNAB or Monarch** *(Premium)*
Purpose: Bring in months of history from a spreadsheet export, mapping its columns once.
Steps:
1. **{tab.settings}** → **{settings.data}** → **{data.import.csv}** and pick the file.
2. **{import.map.title}** opens. Budget Crab guesses the **{import.map.preset}** — Mint, YNAB, Monarch, Generic bank or Custom — and shows a **{import.map.preview}** of the first rows. Change the guess if it's wrong.
3. Check **{import.map.section.date}** and **{import.map.section.amount}**. If dates or decimals could be read two ways, Import stays off until you choose the format — so days and months can't be swapped.
4. Map the **{import.map.section.optional}** columns you have (category, merchant, note, account, currency). Unmapped categories go to Miscellaneous.
5. Tap **{import.map.action.import}**. When it finishes you'll see **{data.alert.import_result.title}** with what was imported, skipped or flagged.
A file you exported from Budget Crab imports straight in, skipping rows you already have. Up to 10,000 rows per file. If an import stops part-way, what was saved stays; import the same file again — repeats are flagged, never lost.
Screenshot: Map Columns with the preview and preset picker.
Show me → `dataImport`.
Tier: Premium.
Verified: gate `DataSettingsView.swift:172`; file picker `:52–58`; own-export path `:230–264`; presets + detection `ImportMappingView.swift:167–173`, `CSVImportMapping.swift:369–378`; ambiguity blocks Import `ImportMappingView.swift:156, 237`; result alert `DataSettingsView.swift:361–392`; partial message `:316–330`; 10k `CSVImportService.swift:128`.
Not said: no duplicate-handling switch (none exists); no progress count (the string is unused).

**D2 · Review possible duplicates after an import**
Purpose: When an imported row looks like one you already had, Budget Crab keeps both and asks you.
Steps:
1. After an import, **{tab.transactions}** shows **{duplicates.banner.title}** at the top with a count. Flagged rows also carry a **{transactions.duplicate.badge}** label.
2. Tap the banner. For each pair choose **{duplicates.review.keep}** or **{duplicates.review.delete}** — or **{duplicates.review.keep_all}** / **{duplicates.review.delete_all}**.
Entries you type or say are never flagged — only imported ones.
Screenshot: the banner on the list, and the review sheet.
Show me → `transactions`.
Tier: free to review (reaching it needs a CSV import, which is Premium).
Verified: banner sole entry `TransactionsView.swift:456–506, 132–134`; badge `CategoryTileRow.swift:103`; sheet buttons `DuplicateReviewView.swift`; flag set only on import `CSVImportService.swift:784`; manual never flagged `QuickAddSaveService.swift:23–44`.

**D3 · Export your data: CSV, Excel, PDF**
Purpose: Your entries are yours — take them out any time as a spreadsheet or a PDF.
Steps:
1. **{tab.settings}** → **{settings.data}** → under **{data.section.export}** choose: **{data.export.csv.month}**, **{data.export.csv.all}**, **{data.export.pdf.month}**, **{data.export.pdf.all}**, **{data.export.excel.month}**, **{data.export.excel.all}**.
2. A row **{data.export.share_last.format}** appears — tap it to send the file with the share sheet.
The "Excel" file is a tab-separated table that Excel and Numbers open directly; a split purchase is one row per part. CSV is also what Budget Crab re-imports. For a report with analysis, use **{reports.title}** (C5).
Screenshot: Data screen with the Share row visible after an export.
Show me → `dataExport`.
Tier: CSV free at both scopes; PDF and Excel for this month free; all-time PDF and Excel Premium.
Verified: six buttons and gates `DataSettingsView.swift:110–165`; share row, last export only `:156–164`; TSV columns + split rows `TSVExportService.swift:56–67`; own-export re-import `DataSettingsView.swift:230–264`.

### Group E — Automate

**E1 · Recurring charges: rent, subscriptions, salary**
Purpose: Mark an entry as repeating and Budget Crab reminds you each period and offers to add it.
Steps:
1. In the full form or when editing an entry, switch on **{addtx.recurring.toggle}** and choose **{addtx.recurring.weekly}**, **{addtx.recurring.monthly}** or **{addtx.recurring.yearly}**. Allow notifications when asked.
2. The day before it's due you get **{recurring.notif.title}**.
3. When it's due, opening **{tab.dashboard}** shows **{recurring.prompt.title}** with **{recurring.prompt.add_button}**, **{recurring.prompt.edit_button}** and **{recurring.prompt.skip_button}**. Nothing is added until you tap Add.
4. To stop one: **{tab.settings}** → **{settings.recurring}**, swipe it left, **{recurring.settings.stop}**. The original entry stays.
The first reminder comes one full period after the entry's date; a charge on the 31st stays on the last day of shorter months.
Screenshot: the recurring prompt sheet.
Show me → `recurring`.
Tier: free.
Verified: toggle + three frequencies `AddTransactionView.swift:473–494`, `RecurrenceType.swift:47–51`; permission on toggle `RecurrenceService.swift:351`; notification day-before `:359–386`; Dashboard prompt once/day, queue `DashboardView.swift:355–359, 418–449`; first prompt one period later `RecurrenceService.swift:145–148`; month-end anchoring `RecurrenceType.swift:119–128`; stop `RecurringSettingsView.swift`.
Not said: no daily, no custom interval, no end date.

**E2 · Weekly and monthly reports, delivered** *(Premium)*
Purpose: A notification when the week or month closes; tap it and the report opens.
Steps:
1. Open **{reports.title}** and tap the bell at the top.
2. Switch on **{reports.settings.weekly.toggle}** and choose **{reports.settings.day}** and **{reports.settings.time}**; and/or **{reports.settings.monthly.toggle}** with a time — it arrives on the 1st.
3. The notification names the period, never a figure. Tap it to open that report.
Screenshot: Automatic reports screen.
Show me → `reportsSettings`.
Tier: Premium.
Verified: bell entry `ReportsView.swift:112–118`; locked rows for free `ReportsSettingsView.swift:95–106`; monthly always 1st `ReportNotificationPolicy.swift:63–88`; body without figures `ReportNotificationScheduler.swift:50–84`; tap → report `AppDelegate.swift:40–61`, `ContentView.swift:440–445`.

**E3 · Siri and Shortcuts**
Purpose: Add an entry or open your spending without touching the app.
Steps:
1. Say **"Add expense to Budget Crab"** — Siri asks how much and which category and saves it, app closed.
2. Say **"Open Quick Entry in Budget Crab"** to land in Quick Entry.
3. Say **"Show spending in Budget Crab"** (or **"How much did I spend in Budget Crab"**) for this month; in the Shortcuts app you can set the period to today, this week, last month or this year.
4. Budget Crab appears in the Shortcuts app automatically; there you can change the phrases.
These phrases work in English; "Add transaction", "Open Quick Entry" and "Show spending" also have Russian phrases. The Shortcuts app shows Budget Crab's actions in English whatever language the app is set to.
Screenshot: the Shortcuts app's Budget Crab tile (captured on the simulator; the one screenshot not of our app).
Show me → `setupSiri` (opens the Shortcuts app via `shortcuts://` if it can, else the card stays).
Tier: free.
Verified: three intents + phrases `BudgetCrabShortcuts.swift:27–61`; parameters `AddTransactionIntent.swift:14–19`; periods `ShowSpendingIntent.swift:39–70`; English-only labels — register D24.
Not said (C3): any invented sentence. The phrases in the card are the registered ones, rendered from the same array (§9 — the card reads `AppShortcut.phrases`, not a copy).

### Group F — On your iPhone

**F1 · The Home Screen widget**
Purpose: What's safe to spend, on your Home Screen, updated once a day.
Steps:
1. Touch and hold an empty spot on the Home Screen, tap **+** in the corner, search **Budget Crab**, choose a size (small, medium or large) and add it.
2. It shows the same number as the Dashboard — **Safe to spend**, **Over budget** or **Spent** — with the month's ring and your top categories. Tap it to open the app.
3. Touch and hold the widget → Edit Widget to switch between the **Ambient** and **Minimal** looks.
It refreshes once a day and reads nothing but a summary the app leaves for it.
Screenshot: the medium widget on a Home Screen (simulator).
Show me → none (the card explains; there is no in-app destination). Button hidden.
Tier: free.
Verified: one kind, three sizes `BudgetCrabWidget.swift:662–676`; styles `:33–50`; hero labels `NetSnapshot.swift`; daily refresh `BudgetCrabWidget.swift:76–84`; tap → `budgetcrab://dashboard` `NetSnapshot.swift:29`; no lock-screen family.
**Replaces C1's false "this month's net".**

**F2 · Lock the app with Face ID**
Purpose: Ask for Face ID, Touch ID or your passcode before Budget Crab opens.
Steps:
1. **{tab.settings}** → **{settings.privacy}** → **{auth.setting.title}**.
2. Choose **{auth.setting.always}** or **{auth.setting.after_5min}**. **{auth.setting.never}** turns it off.
Screenshot: the Privacy screen with the picker.
Show me → `privacy`.
Tier: free.
Verified: `PrivacySettingsView.swift:50–58`; `AuthGateView.swift:137–150` (`deviceOwnerAuthentication`); keys `en.lproj:44–47`.

**F3 · Language, currency, look**
Purpose: Budget Crab speaks five languages and any of 21 currencies; choose them without leaving the app.
Steps:
1. **{tab.settings}** → **{settings.general}**.
2. **{general.language}**: System, English, Русский, Español, Português (Brasil), Українська. **{general.language_hint}**
3. **{general.currency}**: the currency every entry uses.
4. **{settings.appearance.label}**: System, Light or Dark.
Screenshot: General → Preferences.
Show me → `general`.
Tier: free.
Verified: `GeneralSettingView.swift:63–74`; `SupportedLanguage.swift:13–43`; `SupportedCurrency.swift:10–31`.

**F4 · Where your data is**
Purpose: Everything is on your iPhone. There is no account, no server and nothing to log into.
Text: the six **{privacy.section.whatwedonot}** lines, rendered from the same keys the Privacy screen uses; then: *"Exports (CSV, Excel, PDF) and reports are created on your phone when you ask for them and shared only when you choose to. Voice entries are recognised on the phone. Support mail is a draft in your Mail app — you send it, or don't."* Link: **{privacy.policy.link}**.
Screenshot: the Privacy screen.
Show me → `privacy`.
Verified: claims `PrivacySettingsView.swift`, `en.lproj:165–176`; voice `VoiceInputService.swift:242`; mail `FeedbackView.swift:20–23`; no analytics SDK in the tree. **This card is re-read at the sync gate** (`GO_LIVE_CHECKLIST.md` §0b) like every other on-device sentence.

**F5 · Free, Premium, and the free preview**
Purpose: What you get without paying, what Premium adds, and what happens when the preview ends.
Text: *"Every new install gets a 14-day preview of Premium — no card, nothing to cancel. When it ends, nothing you added is deleted or hidden."* Then the comparison table, **rendered by the same code as the paywall's** (`PaywallComparison`), so it cannot disagree with it. Then: **{tab.settings}** → **{settings.premium}** for **{premium.restore}** and **{premium.redeem_code}**.
Screenshot: the Premium screen.
Show me → `premium`.
Verified: preview `ReverseTrial.swift:40–53`; table derived from `AppCapability` `PaywallComparison.swift:69–100`; unshipped rows filtered `:106`; restore/redeem `PremiumSettingsView.swift`. Copy rule: "preview", never "trial" (`en.lproj:15–18`).

**F6 · Getting help, and telling me what's missing**
Purpose: Replay the walkthrough, try the app with sample data, or write to me.
Steps:
1. **{settings.tutorial.replay}** runs the first-run walkthrough again, right now.
2. **{settings.demo.add}** adds sample entries so you can explore; **{settings.demo.clear}** removes them.
3. **{feedback.row}** opens a draft in your Mail app addressed to support. You can attach a summary of which features you've used — never amounts, names or dates — and you see exactly what it says before you send.
4. **{settings.learn_tips}** reveals one tip a day.
Show me → `guideRoot` (this is the Guide itself) / `feedback`.
Verified: replay `GeneralSettingView.swift:409`, `ContentView.swift:335–338`; demo `DemoSeeder.swift:116–151`; feedback consent + summary `FeedbackView.swift`, `UsageSummaryBuilder.swift`; tips `TipDeck.swift:73–99`.

---

## 5. The scanning card — a named PLACEHOLDER

**A10 · Scan a receipt or a screenshot** — *no text yet.*

**Why it is empty.** The card's sentences depend on a measurement that has not been made. Per
`DESIGN_RECEIPT_SCAN.md` §7.3, each (type × locale) cell ships as one of four shapes, decided by the
sealed-half run (`STATE.md` §10, held-out set), and the card must describe the shape the user gets:

| sealed result for the user's locale × type | what the card must say |
|---|---|
| exact ≥ 90 %, wrong-prefill ≤ 3 % | "the amount is filled in — check it and save" |
| exact 75–90 %, wrong-prefill ≤ 3 % | the same, plus the permanent *"check the amount"* line the review sheet shows for that locale |
| wrong-prefill > 3 % | "Budget Crab shows the amounts it found — tap the right one" (**hint-only**; the amount is never filled) |
| exact < 75 % | founder decides: hint-only, or the type is not offered for that locale — and the card says so, per locale |

Plus two facts the card can only state after the founder's decisions land: whether paper is
**uncertified** for a locale with < 10 real photos (ships with the permanent "check the amount"
line — second addendum item 3), and whether Ukrainian recognises natively or via ru + en (item 4;
`VisionLanguageSupportTests` says `uk-UA` is present on this SDK, but the device answer is
runtime). The card is therefore **per-locale text**, not one text translated five ways.

**What is already true at HEAD and will not change** (the skeleton the card fills in): the scan
button sits in Quick Entry next to the mic and in the full form's toolbar; it offers
**{scan.menu.camera}** / **{scan.menu.screenshot}**; the result is a review sheet with one button,
**{scan.review.use}**, that fills the form — **nothing is saved until the user taps Add**; the
image is never kept; 5 scans a month are free, then Premium; the camera is used only when you tap
Photograph receipt and the photo is processed on the phone (`ReceiptScanFlow.swift:145–189`,
`ReceiptReviewSheet`, `ReceiptScanQuota.swift`, `FreeTierLimits.freeScansPerMonth`).

**Rule:** until scanning ships, **the card is absent from the Guide** — not "coming soon". A sentence
about a future version is a claim the build cannot verify. The card and the paywall row move in the
same commit that ships scanning (`STATE.md` §12).

---

## 6. The walkthrough (layer 1)

Keep `OnboardingCoordinator` and its overlay; grow the steps from 3 to 5. Every mark is on a real
control (existing `.coachmarkTarget` preference), skippable at every step, and **replayable from
Settings → General and from the Guide root**.

| # | mark on | text (en) | exists today? |
|---|---|---|---|
| 0 | greeting card | *Welcome to Budget Crab* / *Private and on-device — nothing leaves your phone.* / Show me · Skip | yes (`onboarding.greeting.*`) |
| 1 | Dashboard Quick Add bar | *Type or say an expense — like "coffee 5" — and tap Save.* | yes (`.quickAdd`) |
| 2 | "Set your monthly budget" card | *Set a monthly budget here to see what's left to spend.* | yes (`.budget`) |
| 3 | Dashboard hero | *This number is what's safe to spend today. It's your budget, minus what you've spent, spread over the days left.* | **NEW** — needs a `.coachmarkTarget(.safeToSpend)` on the hero; shown with the demo/sample number if no budget is set |
| 4 | Analytics tab | *See your spending breakdown and trends in the Analytics tab.* | yes (`.analyticsTab`) |
| 5 | Settings tab | *Everything else — the guide to every feature, reports, import and export — is in Settings.* | **NEW** — `.coachmarkTarget(.settingsTab)` |
| end | first-win card | unchanged: Add one now / Explore with demo data / Maybe later | yes |

Six screens counting the greeting, within the brief's 4–6. **Step 3 is the one the Eliel case
needed** (`PLAN_TUTORIAL_AND_HELP.md` §1.2): the tour had a budget step and he still did not find
the budget; naming the number the budget produces is the missing sentence.

Instrumentation (before anything else — `PLAN_TUTORIAL_AND_HELP.md` §6 step 1): the coordinator
records `walkthrough.outcome ∈ {completed, skipped@<step>}`, `walkthrough.replays`, and the Guide
records `guide.cards_opened` (set of ids) — in `FeatureUsageSignals`, appended to the usage summary
as new **last** lines (lines 1–9 keep their positions, `STATE.md` §9 `547b85e`). Bucketed on export
like everything else there; on-device only.

---

## 7. "Show me" — how it navigates

**Mechanism: extend the routing the app already has.** `ContentView.handlePendingIntentNavigation`
consumes flags and switches tabs / presents sheets; Siri and report notifications already ride it
(`ContentView.swift:422–446`). "Show me" posts a `GuideDestination` the same way and lets the
existing consumer act.

```swift
enum GuideDestination: String, CaseIterable {
  case quickEntry, addForm, dashboard, dashboardQuickAdd, dashboardBudget
  case transactions, analyticsPulse, analyticsBreakdown, analyticsHorizon
  case reports, reportsSettings, alerts, recurring
  case categoriesAndAccounts, categoryLimits, dataImport, dataExport
  case general, privacy, premium, feedback, guideRoot, setupSiri
}
```

| destination | tab | then | highlight (one-shot, reuses the coach-mark overlay) |
|---|---|---|---|
| `quickEntry` | any | `showAddSheet = true` | the category row once parsed — none; the sheet is the target |
| `addForm` | any | present `AddTransactionView` | — |
| `dashboard` / `dashboardQuickAdd` | 0 | — / focus the bar | bar |
| `dashboardBudget` | 0 | present `BudgetSetterSheet` (Dashboard already owns it) | — |
| `transactions` | 1 | clear search | first row (A5/A9 arrive here with the hint *"tap an entry"*) |
| `analyticsPulse/Breakdown/Horizon` | 3 | set the segmented picker | picker |
| `reports` | 4 | push `ReportsScreen` (Settings row) | share button |
| `reportsSettings` | 4 | push Reports → present settings | first toggle |
| `alerts` / `recurring` / `general` / `privacy` / `premium` / `dataImport` / `dataExport` / `categoriesAndAccounts` | 4 | push the Settings child; `dataImport`/`dataExport` scroll to the section | the section |
| `categoryLimits` | 4 | push Categories & Accounts, scroll to Expense categories | **first expense row** — the row *is* the affordance, which is why nobody finds it |
| `feedback` | 4 | present the mail sheet | — |
| `setupSiri` | — | `UIApplication.open("shortcuts://")` when `canOpenURL`; else no button | — |
| `guideRoot` | 4 | pop to the Guide | — |

**Implementation constraint to verify at build, not assumed:** the Settings tab must own a
`NavigationStack(path:)` so a destination can push a child from outside the view. Memory
`project_edit_stuck_edittx_resolved` records the exact trap — `navigationDestination(item:)` presents
on nil→value only — and `TransactionsView` already uses the path-owned form. If `SettingsView` has a
plain `NavigationStack`, it gets a path bound from `ContentView`, and *that* is the first commit.
Leaving the Settings tab already resets its stack (`ContentView.swift:183–185`); the Guide push must
survive the switch, so the destination is consumed **after** the tab change lands (the same
`DispatchQueue.main.async` hop `.budgetCrabPendingIntent` uses).

**Highlight:** the coach-mark overlay resolves a `.coachmarkTarget` frame to a rect
(`ContentView.swift`, `CoachmarkAnchorKey`). A one-shot "here" pulse on arrival reuses it with a
single tap-anywhere dismissal and no text. Cards whose destination is a whole screen get no pulse.

**Test (rule 2, red first):** `GuideShowMeJourneyTests` — for every `GuideDestination`, from the
Guide card tap Show me and assert **presence** of the destination screen's title or a control unique
to it (rule 4: presence, not "the guide is gone"). Commissioned red by routing every case to
`dashboard`.

---

## 8. Contextual hints (layer 3)

One registry, one rule set, replacing nothing that exists (the two `onboarding.hint.*` one-shots
become entries in it).

```swift
struct ContextualHint { let id: String; let screen: Screen; let usageSignal: String?; let text: LocalizedStringKey; let cardId: GuideCard.ID }
```

Rules, all enforced by `HintPolicy` and tested:
1. **At most one hint visible in the whole app at a time** — a global `activeHintID`; a second screen
   that qualifies waits for the first's dismissal.
2. **Shown only while the capability is unused** — `usageSignal` is a `usage.ever.*` key
   (`FeatureUsageSignals`); a hint for a feature the user has used never appears.
3. **Never after dismissal** — `hint.dismissed.<id>` in `UserDefaults.standard`; also set when the
   user taps through to the card.
4. **Never during the walkthrough, never on a screen with a coach mark active, never under a sheet.**
5. **Each hint links to its card** ("Learn more" → the Guide card, which has Show me).

Initial set (seven; each is a sentence about an affordance already on that screen):

| screen | hint | usage signal | card |
|---|---|---|---|
| Transactions (row visible) | *Tap an entry to change it. Swipe left to delete.* | `usage.ever.edit` | A5 |
| Editor, expense with amount | *Bought several things? Split it across categories below.* | `usage.ever.split` | A9 |
| Categories & Accounts | *Tap an expense category to give it a monthly limit.* | `usage.ever.categoryLimit` | B2 |
| Dashboard, budget set, day ≥ 7 | *There's a widget for this number.* | — (no signal; shown once) | F1 |
| Analytics Breakdown, "Other" present | *Tap Other to open the smaller categories.* | — | C3 |
| Reports | *The bell sets up a weekly or monthly report.* | `usage.ever.scheduledReports` | E2 |
| Data | *A file you exported from Budget Crab imports straight back in.* | `usage.ever.csvImport` | D1 |

The existing footers (`add.category.split_hint`, `cs.category.limit_hint` — corrected per C2,
`add.source.tip`) stay; they are affordance labels, not hints, and cost nothing when ignored
(`PROPOSAL_1_0_5_SCOPE.md` GROUP 2 rule).

---

## 9. Card text that cannot drift from the screens

Three mechanisms, and they are the reason the guide can be trusted after this release:

1. **Control names by key.** A step is a format string whose control names are `{key}` tokens
   resolved at render time through `LocalizedBundle` (memory `project_learn_tips_hub_v102`:
   `Bundle.main` ignores the in-app language for resources). The guide never carries the words on a
   button; it carries the button's key. Rename the button and the guide follows in all five
   languages.
2. **Live data where the app has it.** E3 reads `AppShortcut.phrases`; F5 renders
   `PaywallComparison.rows`; F4 renders the Privacy screen's six keys. No second copy.
3. **A test that fails on a dead key** (`GuideClaimTests`): every `{key}` in every card exists in all
   five `.lproj` **and** has ≥ 1 use in a `.swift` file outside the guide. Commissioned red with
   `{tab.add}` in a card (C5). This is the mechanism that would have stopped C1–C5 from shipping.

What this does not catch: a true key attached to a false sentence ("see how much is left"). That is
what the per-card **Verified** lines are for, and the review before each release re-reads them
(rule: the Guide is updated in the same release as any feature it describes, brief `:252–253`).

---

## 10. Screenshots — generated from the real app

**Source:** `AppStore/capture-screenshots.sh` already drives the simulator through the DEBUG-only
`--screenshot-screen <id>` seam (`Data/ScreenshotMode.swift`) for five locales
(`EN RU ES PT-BR UK`, script `:77, :223`). The Guide adds a `guide.<cardId>` family of screen ids to
`ScreenshotMode.Screen`, each routing to the state the card's screenshot describes (seeded by
`DemoSeeder`'s screenshot path, which already seeds a budget and limits — `DemoSeeder.swift:63–70`),
and a sibling `AppStore/capture-guide-screenshots.sh` that loops cards × locales into
`FinanceTracker/Resources/GuideScreenshots/<locale>/<cardId>.heic`.

**Annotation** is drawn by the app at capture time, not in an image editor: a DEBUG-only overlay
that rings the `.coachmarkTarget` frame named by the card (the same frames "Show me" pulses). So the
ring is on the real control, in the real locale, and moves with the layout.

**Size, measured before deciding** (an estimate here, marked as one): 26 cards × 5 locales = 130
images. At 2× for a 390-pt canvas in HEIC, ~80–120 KB each → **~10–16 MB** added to the bundle
(the 1.0.6 IPA size is the baseline to read from the archive; not stated here because not
measured). Two options for Dmitry (§14): full per-locale set, or English screenshots with the
localised ring only (~3 MB) — the second is a claim mismatch in four languages and is **not
recommended**.

**Animations:** out of 1.0.7. Screenshots first; an animation is a video file per card per locale
and the same drift problem five times over.

**Tests:** `GuideScreenshotPresenceTests` — every card has an image for every locale (presence);
and each `guide.*` screen id is routable (`ScreenshotMode` walk, DEBUG). The Release binary is
checked for the absence of the `--screenshot-screen` argument as `ReleaseDebugAffordanceTests`
already does for the scan seam (`STATE.md` §12).

---

## 11. Five languages

- Card purposes and step *sentences* are new strings (`guide.<card>.purpose`, `guide.<card>.step.<n>`),
  translated for es, pt-BR, ru, uk in the same pass as always; control names arrive by key (§9.1),
  so translators never retype a button.
- Premium's name per locale comes from the paywall strings, as the What's New did (`STATE.md` §10).
- The scanning card is per-locale text (§5) and is written after the sealed run.
- Locale parity test: the existing string-parity guard (`FrozenArtifactLanguageTests` /
  `LocalizedCallSiteGuardTests`) covers the new keys; the baseline count moves and is recorded.

---

## 12. Test plan

### 12.1 The acceptance test — pre-registered, unchanged, now operational

`PLAN_TUTORIAL_AND_HELP.md` §4, verbatim: *a new user, from a cold install, answers "how much do I
have and how much am I spending" and reaches BOTH the monthly budget AND a per-category limit,
without writing to support, in Spanish at least once.*

Two instruments, because a UI test cannot answer "did a person understand":

- **Human run (the test).** One Spanish-speaking tester who has never seen the app, a fresh install
  on a device, the question verbatim, no help from us. Pass = both destinations reached; the path
  taken is written down (walkthrough / Guide / hint / found it unaided — all count, per §4 clause
  4 and §5). **Null result reportable** (§4 clause 5). Recorded in `PLAN_TUTORIAL_AND_HELP.md` §6
  with the date.
- **Regression guard (UI test, es locale, erased simulator):** `GuideAcceptanceJourneyTests` —
  launch → skip the walkthrough → Settings → Guide → B1 → Show me → assert `BudgetSetterSheet`
  present → set budget → Dashboard shows `dashboard.safe_today` (es) → Guide → B2 → Show me →
  assert the limit sheet present → set limit → row shows `cs.category.limit_label.format`. Presence
  at every step. Commissioned red by breaking the `categoryLimits` route.

### 12.2 Guards, each observed red before green (rule 2)

| test | guards | red by |
|---|---|---|
| `GuideClaimTests` | every `{key}` exists ×5 and is used in Swift | a card citing `tab.add` |
| `GuideShowMeJourneyTests` | every destination lands (presence) | all routes → dashboard |
| `GuideScreenshotPresenceTests` | image per card per locale | delete one |
| `GuideAcceptanceJourneyTests` | §12.1 path in es | break `categoryLimits` |
| `WalkthroughInstrumentationTests` | completed / skipped@step / replays recorded; usage summary lines 1–9 unchanged, new lines last | reorder a line |
| `HintPolicyTests` | one at a time; never after dismissal; never when used; never during walkthrough | drop the global lock |
| `ReleaseDebugAffordanceTests` (extend) | `guide.*` screenshot routing absent from Release | already guarded pattern |

Full suite from an erased simulator at the end; `EXPECTED_TOTAL_RUN` from the observed count (rule 9).

---

## 13. Release cut, sizing, what is out

- **Ships in 1.0.7 with scanning**, as the brief cuts it. If scanning slips (corpus-gated, `STATE.md`
  §12), the Guide can ship alone in 1.0.7 with the scanning card absent (§5 rule) — **proposal**, not
  a decision.
- Order of work: (1) walkthrough instrumentation + usage-summary lines; (2) Settings path binding +
  `GuideDestination` routing + journey test; (3) Guide root + card screens rendering from keys +
  claim test; (4) the 26 cards' strings ×5; (5) screenshot ids + capture script + presence test;
  (6) hints + policy test; (7) walkthrough steps 3 and 5; (8) the 1.3 string corrections C1–C5
  (delete the dead strings, fix `help.widget.body` / `cs.category.limit_hint` / `help.siri.body`
  — or delete the two help articles once absorbed).
- **Out:** animations (§10); a second walkthrough for Premium; a per-category remainder anywhere in
  the UI (that is a feature, and B2 says the truth instead); any sentence about scanning before the
  sealed run; the savings balance (`PLAN_TUTORIAL_AND_HELP.md` §2).

---

## 14. Decisions for Dmitry

1. **Accounts (§2):** the guide says "expenses and income alike", which is what the build does. Confirm — or say income-only is the intended product and that becomes a separate change.
2. **Absorb the six existing help articles into the Guide** and drop "Set up Widget & Siri" (§1.2)? Recommended yes.
3. **Screenshots per locale (~10–16 MB est., recommended) vs English-only (~3 MB)** (§10).
4. **Walkthrough step 3 (the safe-to-spend sentence) when no budget is set:** show it over the empty hero with sample wording, or skip it until a budget exists? Recommended: show it (it is the sentence the evidence says was missing).
5. **Fix C1–C5 in the same release** (recommended) — they are §2.8 defects in shipped copy; the strings pass is small.
6. **Hint set (§8):** the seven proposed, or fewer. Each costs attention once.
7. **If scanning slips, does the Guide ship alone in 1.0.7?** (§13)

---

## 15. Filed by this pass (not fixed; doc only)

| what | where it goes |
|---|---|
| C1–C5: five false / dead shipped teaching strings (§1.3) | `DEFECT_REGISTER.md` §3.1b as one row (claim class), fixed under 1.0.7 with the Guide |
| Brief vs build on accounts (§2) | `STATE.md` §4 contradiction row once Dmitry answers §14.1 |
| `help.siri.body`'s unregistered phrase — unverified whether Siri resolves it | same row as C3; a device check is one sentence to Siri |
| Category limits have no remainder surface anywhere (B2) | not a defect — a feature absence; recorded here so nobody re-derives it |

*Nothing above is a status; status lives in `STATE.md`, defects in `DEFECT_REGISTER.md`.*
