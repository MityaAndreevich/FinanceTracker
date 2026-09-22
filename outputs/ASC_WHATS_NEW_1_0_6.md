# App Store "What's New" — 1.0.6 (build 11)

**Status: APPROVED by the founder 2026-09-21, FINAL.** Submitted by Dmitry in App Store Connect;
this file is what he pastes. No annotation markers remain in the blocks — they go to the store literally.

**Two changes from the draft, both the founder's:** the annotation markers are gone; and the
share/reminder sentence now states the free/premium line truthfully — **verified against the build
2026-09-21**: a month report's PDF and Excel go through `exportPDFMonth` / `exportExcelMonth`
(`requiresPremium == false`); week/year/custom go through `exportPDFAll` / `exportExcelAll`, and the
weekly/monthly reminders through `scheduledReports` — all premium (`ReportsView.swift:283–291`,
`FreeTierLimits.swift`). "Premium" is the paywall's own word in all five locales
(`paywall.compare.premium`). The music sentence ships because the device run confirmed it
(`STATE.md` §8.2, closed 2026-09-21).

**Every sentence is a claim**; the Provenance table at the end names the test or commit that proves
each one on this tree.

**Names verified against the app's own strings 2026-09-21** (`tab.analytics`, `tab.settings`,
`reports.title`, `paywall.compare.premium` in all five `.lproj`): es "Analíticas" → **"Análisis"**
(twice) and pt-BR "Ajustes" → **"Definições"** were wrong in the first final and are corrected
below; everything else matched. The Excel column names are English literals in every locale
(`TSVExportService.swift:65–66`), so "(Split, Transaction ID)" is what a Russian user's file
actually says.

---

## 🇺🇸 en-US

```
New: Reports. Pick a week, a month, a year or your own date range and see
where your money went — income, expenses, what changed since the previous
period, your biggest categories and your largest purchases. Open Reports
from Analytics or from Settings.

Share a monthly report as a PDF with the analysis on the first page, or
as an Excel file. With Premium: reports for any period, and a weekly or
monthly reminder when the period closes — tap it to open the report.
Reports are built on your iPhone when you open them, and nothing leaves
your phone.

Also fixed: music and podcasts resume after you dictate an entry.

Also in this release:
• Analytics no longer stops working on a ledger with an amount it cannot
  add up — it tells you instead.
• Excel export: a split purchase is now one row per part, so totals by
  category in your spreadsheet match the app. Two columns were added at
  the end (Split, Transaction ID); the first eight are unchanged.
• Excel export dates are always plain year-month-day.
• Wording and translation fixes across all five languages.
```

## 🇷🇺 ru

```
Новое: Отчёты. Выберите неделю, месяц, год или свой период и посмотрите,
куда ушли деньги — доходы, расходы, что изменилось по сравнению с прошлым
периодом, крупнейшие категории и самые большие покупки. Отчёты открываются
из Аналитики и из Настроек.

Месячный отчёт можно отправить как PDF с анализом на первой странице
или как файл Excel. С Premium — отчёты за любой период и напоминание
раз в неделю или в месяц, когда период закончится; нажмите на него,
чтобы открыть отчёт. Отчёты строятся на вашем iPhone в момент открытия,
и ничего не покидает телефон.

Также исправлено: музыка и подкасты возобновляются после голосового ввода.

Также в этом выпуске:
• Аналитика больше не перестаёт работать, если в записях есть сумма, которую
  невозможно сложить, — вместо этого она сообщает об этом.
• Экспорт в Excel: разделённая покупка теперь выгружается по одной строке на
  каждую часть, поэтому итоги по категориям в таблице совпадают с приложением.
  В конец добавлены две колонки (Split, Transaction ID); первые восемь не
  изменились.
• Даты в экспорте Excel всегда в виде год-месяц-день.
• Исправления формулировок и переводов на всех пяти языках.
```

## 🇲🇽 es-MX

```
Nuevo: Informes. Elige una semana, un mes, un año o tu propio rango de
fechas y mira a dónde se fue tu dinero: ingresos, gastos, qué cambió
respecto al período anterior, tus mayores categorías y tus compras más
grandes. Abre Informes desde Análisis o desde Ajustes.

Comparte el informe mensual como PDF con el análisis en la primera página,
o como archivo de Excel. Con Premium: informes de cualquier período y un
recordatorio semanal o mensual cuando cierre el período; tócalo para abrir
el informe. Los informes se generan en tu iPhone cuando los abres, y nada
sale de tu teléfono.

También corregido: la música y los podcasts se reanudan después de dictar
un registro.

También en esta versión:
• Análisis ya no deja de funcionar cuando hay un importe que no se puede
  sumar: ahora te lo indica.
• Exportación a Excel: una compra dividida ahora es una fila por cada parte,
  así los totales por categoría en tu hoja de cálculo coinciden con la app.
  Se añadieron dos columnas al final (Split, Transaction ID); las primeras
  ocho no cambian.
• Las fechas de la exportación a Excel siempre van como año-mes-día.
• Correcciones de redacción y traducción en los cinco idiomas.
```

## 🇧🇷 pt-BR

```
Novidade: Relatórios. Escolha uma semana, um mês, um ano ou seu próprio
intervalo de datas e veja para onde foi seu dinheiro: receitas, despesas,
o que mudou em relação ao período anterior, suas maiores categorias e
suas maiores compras. Abra Relatórios em Análises ou em Definições.

Compartilhe o relatório mensal como PDF, com a análise na primeira página,
ou como arquivo Excel. Com o Premium: relatórios de qualquer período e um
lembrete semanal ou mensal quando o período fechar — toque nele para abrir
o relatório. Os relatórios são gerados no seu iPhone quando você os abre,
e nada sai do seu telefone.

Também corrigido: músicas e podcasts voltam a tocar depois de ditar um
lançamento.

Também nesta versão:
• Análises não para mais de funcionar quando há um valor que não dá para
  somar — agora ela avisa.
• Exportação para Excel: uma compra dividida agora é uma linha por parte,
  assim os totais por categoria na planilha batem com o app. Duas colunas
  foram adicionadas no final (Split, Transaction ID); as oito primeiras não
  mudaram.
• As datas da exportação para Excel são sempre ano-mês-dia.
• Correções de texto e tradução nos cinco idiomas.
```

## 🇺🇦 uk

```
Нове: Звіти. Оберіть тиждень, місяць, рік або власний період і подивіться,
куди пішли гроші — доходи, витрати, що змінилося порівняно з попереднім
періодом, найбільші категорії та найбільші покупки. Звіти відкриваються з
Аналітики та з Налаштувань.

Місячний звіт можна надіслати як PDF з аналізом на першій сторінці або як
файл Excel. З Premium — звіти за будь-який період і нагадування раз на
тиждень або на місяць, коли період закінчиться; натисніть на нього, щоб
відкрити звіт. Звіти будуються на вашому iPhone у момент відкриття, і ніщо
не залишає телефон.

Також виправлено: музика та подкасти відновлюються після голосового введення.

Також у цьому випуску:
• Аналітика більше не перестає працювати, якщо в записах є сума, яку
  неможливо додати, — натомість вона повідомляє про це.
• Експорт в Excel: розділена покупка тепер вивантажується по одному рядку на
  кожну частину, тому підсумки за категоріями в таблиці збігаються із
  застосунком. У кінець додано два стовпці (Split, Transaction ID); перші
  вісім не змінилися.
• Дати в експорті Excel завжди у форматі рік-місяць-день.
• Виправлення формулювань і перекладів усіма п’ятьма мовами.
```

---

## Provenance — what proves each claim on this tree

| claim | proof |
|---|---|
| week / month / year / custom periods | `ReportPeriodTests` (17), `ReportBuilderTests.granularity` |
| income, expenses, change vs previous period | `ReportBuilderTests.comparison`, `ReportEqualityCanaryTests.previousEqualsMonthTotals` |
| biggest categories, largest purchases | `ReportBuilderTests.monthFigures`, `ReportEqualityCanaryTests.categoriesEqualBothScreens` |
| "open from Analytics or Settings" | `PoisonedAnalyticsJourneyTests` (Analytics toolbar → Reports); Settings row `settings_reports_row` in `SettingsView` (`cff1dbf`) |
| monthly report as PDF / Excel is FREE; any period and the reminders are Premium |  `ReportsView.exportCapability`, `AppCapability.requiresPremium`, `CapabilityMatrixTests`, `PaywallComparisonTests` |
| PDF with the analysis on the first page | `ReportPDFRenderTests` — pixels, 7 locales × 7 currencies |
| Excel file | `TSVSplitEqualityTests`, `TSVExportServiceTests` |
| weekly / monthly notification, tap opens the report | `ReportNotificationPolicyTests`, `ReportNotificationSchedulerTests` (incl. `tapHandOff`), `FrozenArtifactLanguageTests.reportNotificationHonorsTheOverride` |
| "built on your iPhone when you open them" | `ReportsView.rebuild` builds on open; the notification body carries no figure (`bodyCarriesNoFigure`) |
| "nothing leaves your phone" | no network code in the feature; `cloudKitDatabase: .none` (`SharedModelContainer.swift`); re-read at the sync gate |
| music resumes after dictation | `VoiceAudioSessionControllerTests`, `AudioSessionCallSiteGuardTests` (`b3ca3ef`) — **and the founder's device run, iPhone 14 Pro, Debug `b3ca3ef`: music resumed by itself (STATE §8.2)** |
| Analytics tells you instead of stopping | `PoisonedAnalyticsJourneyTests`, `ImportOverflowChainTests.testAnalyticsSeriesReportsOverflowInsteadOfTrapping` (`f2ae0a9`) |
| Excel: one row per part, totals match, two columns appended, first eight unchanged | `TSVSplitEqualityTests` (red on the old file: 12 700 vs 9 400), `TSVExportServiceTests.everyRowHasTenCells` (`c02b8b0`) |
| Excel dates plain year-month-day | `TSVExportServiceTests.dateIsGregorianISODay` (`83da3ce`) |

**Not claimed anywhere in these notes:** D1 (voice teardown abort, still filed); the two overflow
sites off the Analytics/Reports surface (`EditTransactionView`, `CSVImportService`); the pre-1.0.6
"Every other screen works normally" sentence (still deleted, and stays deleted); anything about
sync or family.

**Deliberately not mentioned:** that automatic reports are premium — the paywall says it
(`paywall.compare.row.scheduled_reports`); release notes are not the place to announce a gate.
