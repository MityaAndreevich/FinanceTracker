# App Store "What's New" — 1.0.6 (build TBD at submission)

**Status: DRAFT for the founder's review, 2026-09-21.** Nothing below is submitted.

**Every sentence is a claim** (ARCHITECTURE.md, "UI copy that asserts behaviour is a CLAIM"). The
Provenance table at the end names the test or commit that proves each one on this tree. A sentence
whose proof is not green at submission is deleted, not softened. **Ship-only rule applied:** nothing
here describes work that is filed but not in the build.

**Two sentences are conditional and marked ⚠️:**
- *"Music and podcasts resume after you dictate an entry"* — the fix is in the tree and pinned by
  tests, but the mechanism has **not been confirmed on a device** (`STATE.md` §8.2). It ships in the
  notes only if the founder's device run shows `othersPlayingAfterRelease=true`. Otherwise delete
  the paragraph in all five languages.
- *"Nothing leaves your phone"* — true of this build; it is re-read at the sync gate
  (`GO_LIVE_CHECKLIST.md` §0b) and must not be copied forward to a release that syncs.

**Wording note.** "Report" is the word users scan for (review corpus: 53 mentions of *report(s)* vs 17
of *summary*, `DESIGN_REPORTS_1_0_6.md` §0). The Excel line names the format change plainly
because it changes a paid file's shape: a spreadsheet formula written against the old eight columns
still works (the eight are unchanged); one that summed a split purchase now sees its parts.

---

## 🇺🇸 en-US

```
New: Reports. Pick a week, a month, a year or your own date range and see
where your money went — income, expenses, what changed since the previous
period, your biggest categories and your largest purchases. Open Reports
from Analytics or from Settings.

Share any report as a PDF with the analysis on the first page, or as an
Excel file.

Turn on a weekly or monthly report and Budget Crab will remind you when
the period closes — tap the notification to open it. Reports are built on
your iPhone when you open them, and nothing leaves your phone.

⚠️ Also fixed: music and podcasts resume after you dictate an entry.

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

Любой отчёт можно отправить как PDF с анализом на первой странице или как
файл Excel.

Включите еженедельный или ежемесячный отчёт — Budget Crab напомнит, когда
период закончится; нажмите на уведомление, чтобы открыть отчёт. Отчёты
строятся на вашем iPhone в момент открытия, и ничего не покидает телефон.

⚠️ Также исправлено: музыка и подкасты возобновляются после голосового ввода.

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
grandes. Abre Informes desde Analíticas o desde Ajustes.

Comparte cualquier informe como PDF con el análisis en la primera página,
o como archivo de Excel.

Activa un informe semanal o mensual y Budget Crab te avisará cuando cierre
el período; toca la notificación para abrirlo. Los informes se generan en
tu iPhone cuando los abres, y nada sale de tu teléfono.

⚠️ También corregido: la música y los podcasts se reanudan después de dictar
un registro.

También en esta versión:
• Analíticas ya no deja de funcionar cuando hay un importe que no se puede
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
suas maiores compras. Abra Relatórios em Análises ou em Ajustes.

Compartilhe qualquer relatório como PDF, com a análise na primeira página,
ou como arquivo Excel.

Ative um relatório semanal ou mensal e o Budget Crab avisa quando o período
fechar — toque na notificação para abri-lo. Os relatórios são gerados no
seu iPhone quando você os abre, e nada sai do seu telefone.

⚠️ Também corrigido: músicas e podcasts voltam a tocar depois de ditar um
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

Будь-який звіт можна надіслати як PDF з аналізом на першій сторінці або як
файл Excel.

Увімкніть щотижневий або щомісячний звіт — Budget Crab нагадає, коли період
закінчиться; натисніть на сповіщення, щоб відкрити звіт. Звіти будуються на
вашому iPhone у момент відкриття, і ніщо не залишає телефон.

⚠️ Також виправлено: музика та подкасти відновлюються після голосового введення.

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
| PDF with the analysis on the first page | `ReportPDFRenderTests` — pixels, 7 locales × 7 currencies |
| Excel file | `TSVSplitEqualityTests`, `TSVExportServiceTests` |
| weekly / monthly notification, tap opens the report | `ReportNotificationPolicyTests`, `ReportNotificationSchedulerTests` (incl. `tapHandOff`), `FrozenArtifactLanguageTests.reportNotificationHonorsTheOverride` |
| "built on your iPhone when you open them" | `ReportsView.rebuild` builds on open; the notification body carries no figure (`bodyCarriesNoFigure`) |
| "nothing leaves your phone" | no network code in the feature; `cloudKitDatabase: .none` (`SharedModelContainer.swift`); re-read at the sync gate |
| ⚠️ music resumes after dictation | `VoiceAudioSessionControllerTests`, `AudioSessionCallSiteGuardTests` (`b3ca3ef`) — **device confirmation pending, STATE §8.2** |
| Analytics tells you instead of stopping | `PoisonedAnalyticsJourneyTests`, `ImportOverflowChainTests.testAnalyticsSeriesReportsOverflowInsteadOfTrapping` (`f2ae0a9`) |
| Excel: one row per part, totals match, two columns appended, first eight unchanged | `TSVSplitEqualityTests` (red on the old file: 12 700 vs 9 400), `TSVExportServiceTests.everyRowHasTenCells` (`c02b8b0`) |
| Excel dates plain year-month-day | `TSVExportServiceTests.dateIsGregorianISODay` (`83da3ce`) |

**Not claimed anywhere in these notes:** D1 (voice teardown abort, still filed); the two overflow
sites off the Analytics/Reports surface (`EditTransactionView`, `CSVImportService`); the pre-1.0.6
"Every other screen works normally" sentence (still deleted, and stays deleted); anything about
sync or family.

**Deliberately not mentioned:** that automatic reports are premium — the paywall says it
(`paywall.compare.row.scheduled_reports`); release notes are not the place to announce a gate.
