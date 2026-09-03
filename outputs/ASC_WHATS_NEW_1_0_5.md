# App Store "What's New" — 1.0.5 (build 10)

**Build 10 adds one user-visible fix to build 9's list: PDF reports printed some amounts wrong.**
That is what a TestFlight tester reported and what she will look for, so it is called out on its
own rather than buried in the bullets. The migration fix still leads: someone stuck on a screen
that would not go anywhere should still recognise themselves in the first sentence.

**These notes are UI copy, so the ARCHITECTURE.md rule applies: every sentence is a claim.**
Each line below was verified against build 10 — the PDF wording against rendered pixels
(a 4 000,00 ₽ expense really did print as "−4"), the totals line against a real launch on a
ledger that could not be summed, the import line against a real import of a 22-digit amount.
Nothing here describes work that is only filed.

**Ship-only rule applied:** every line below is in build 9 and was verified in the code, not in a
plan. Nothing about iCloud sync, nothing about receipt capture.

**The migration fix leads, deliberately.** Someone who hit it saw an app that would not open, and
was told their data was safe by a screen that then went nowhere. The fix is the single most
consequential change in this release, and a person still stuck on that screen should be able to
recognise their own situation in the first sentence.

Wording note: the first paragraph avoids "migration", "schema" and "store". The user's experience
was *"I updated and the app stopped opening"*, and that is the phrase they will scan for.

---

## 🇺🇸 en-US

```
Fixed: the app wouldn't open after updating from a very early version.

If you updated from one of the first releases and got stuck on a screen saying your data
was safe — while the app never went any further — this update gets you in, with everything
you entered still there. Nothing was lost while you were waiting.

That screen is also more honest now: if an update ever can't finish, it warns you not to
delete the app (which would erase the data on your device) and can still export a copy.

Also fixed: PDF reports printed some amounts incorrectly — part of a number could be
missing, and the currency symbol could disappear. Every amount now prints in full.

Also in this release:
• Imports that stop partway now tell you how many transactions were saved, instead of just
  saying the import failed. Re-importing is safe.
• Repeating transactions set for the end of the month stay at the end of the month.
• Deleting a large number of transactions is dramatically faster.
• A new Settings entry shows how to set up the Widget and Siri shortcuts.
• The Categories screen now mentions that you can set a monthly limit on any expense category.
• A very large amount could stop the app showing this month's totals. It now says so, and
  points you to the entry, instead of leaving you without a screen.
• Importing a file now refuses an amount it can't store, telling you which line, instead of
  saving something different from what the file said.
• Wording and translation fixes across all five languages.
```

## 🇷🇺 ru

```
Исправлено: приложение не открывалось после обновления с очень ранней версии.

Если вы обновились с одной из первых версий и застряли на экране, где написано, что ваши
данные в безопасности, — а дальше приложение не шло, — это обновление вас впустит, и всё,
что вы вводили, останется на месте. За время ожидания ничего не потерялось.

Этот экран стал честнее: если обновление вдруг не сможет завершиться, он предупредит, что
удалять приложение нельзя (это сотрёт данные с устройства), и всё равно даст выгрузить копию.

Ещё исправлено: в PDF-отчётах некоторые суммы печатались неверно. Сумма с разделителем
тысяч теряла всё после него — 4 000,00 ₽ могло напечататься как 4, — а знак валюты мог
пропасть. Теперь в отчёте каждая сумма печатается полностью.

Также в этой версии:
• Если импорт прервался, приложение теперь сообщает, сколько операций уже сохранено, вместо
  простого «не удалось». Повторный импорт безопасен.
• Повторяющиеся операции, назначенные на конец месяца, остаются в конце месяца.
• Удаление большого количества операций стало значительно быстрее.
• В настройках появился раздел о том, как настроить виджет и команды Siri.
• На экране категорий теперь видно, что любой категории расходов можно задать месячный лимит.
• Очень большая сумма могла помешать приложению показать итоги за месяц. Теперь оно об этом
  сообщает и указывает, где искать запись, а не оставляет вас без экрана.
• При импорте файла сумма, которую невозможно сохранить, теперь отклоняется с указанием строки,
  а не сохраняется искажённой.
• Правки формулировок и переводов во всех пяти языках.
```

## 🇲🇽 es-MX

```
Corregido: la app no abría después de actualizar desde una versión muy antigua.

Si actualizaste desde una de las primeras versiones y te quedaste en una pantalla que decía
que tus datos estaban a salvo —mientras la app no avanzaba—, esta actualización te deja
entrar, con todo lo que registraste intacto. No se perdió nada durante la espera.

Esa pantalla ahora también es más honesta: si una actualización no puede completarse, te
avisa que no elimines la app (eso borraría los datos del dispositivo) y aun así permite
exportar una copia.

También corregido: los informes en PDF imprimían algunos importes de forma incorrecta:
podía faltar parte de la cifra y desaparecer el símbolo de moneda. Ahora cada importe se
imprime completo.

También en esta versión:
• Las importaciones que se detienen a medias ahora indican cuántas transacciones se
  guardaron, en lugar de decir solo que fallaron. Volver a importar es seguro.
• Las transacciones periódicas fijadas a fin de mes se quedan a fin de mes.
• Eliminar muchas transacciones a la vez es mucho más rápido.
• Una nueva sección en Ajustes explica cómo configurar el widget y los atajos de Siri.
• La pantalla de categorías ahora indica que puedes ponerle un límite mensual a cualquier
  categoría de gastos.
• Un importe muy grande podía impedir que la app mostrara los totales del mes. Ahora lo avisa
  y te indica dónde está la transacción, en vez de dejarte sin pantalla.
• Al importar un archivo, un importe que no se puede guardar ahora se rechaza indicando la
  línea, en lugar de guardarse alterado.
• Correcciones de redacción y traducción en los cinco idiomas.
```

## 🇧🇷 pt-BR

```
Corrigido: o app não abria depois de atualizar de uma versão muito antiga.

Se você atualizou de uma das primeiras versões e ficou preso em uma tela dizendo que seus
dados estavam seguros — enquanto o app não avançava —, esta atualização deixa você entrar,
com tudo o que você registrou intacto. Nada se perdeu na espera.

Essa tela também ficou mais honesta: se uma atualização não conseguir terminar, ela avisa
para você não excluir o app (isso apagaria os dados do aparelho) e ainda permite exportar
uma cópia.

Também corrigido: os relatórios em PDF imprimiam alguns valores de forma incorreta: parte
do número podia faltar e o símbolo da moeda podia sumir. Agora cada valor é impresso por
completo.

Também nesta versão:
• Importações interrompidas agora informam quantas transações foram salvas, em vez de apenas
  dizer que falharam. Importar de novo é seguro.
• Transações recorrentes marcadas para o fim do mês continuam no fim do mês.
• Excluir muitas transações de uma vez ficou bem mais rápido.
• Uma nova entrada em Ajustes mostra como configurar o widget e os atalhos da Siri.
• A tela de categorias agora lembra que você pode definir um limite mensal para qualquer
  categoria de despesa.
• Um valor muito grande podia impedir o app de mostrar os totais do mês. Agora ele avisa e
  indica onde está o lançamento, em vez de deixar você sem tela.
• Ao importar um arquivo, um valor que não pode ser guardado agora é recusado com a linha
  indicada, em vez de ser salvo alterado.
• Correções de texto e tradução nos cinco idiomas.
```

## 🇺🇦 uk

```
Виправлено: застосунок не відкривався після оновлення з дуже ранньої версії.

Якщо ви оновилися з однієї з перших версій і застрягли на екрані, де сказано, що ваші дані
в безпеці, — а далі застосунок не йшов, — це оновлення вас впустить, і все, що ви вводили,
залишиться на місці. Поки ви чекали, нічого не втратилося.

Цей екран став чеснішим: якщо оновлення раптом не зможе завершитися, він попередить, що
видаляти застосунок не можна (це зітре дані з пристрою), і все одно дасть експортувати копію.

Ще виправлено: у PDF-звітах деякі суми друкувалися неправильно: частина числа могла
зникнути, а разом із нею — знак валюти. Тепер кожна сума друкується повністю.

Також у цій версії:
• Якщо імпорт перервався, застосунок тепер повідомляє, скільки операцій уже збережено,
  замість простого «не вдалося». Повторний імпорт безпечний.
• Повторювані операції, призначені на кінець місяця, залишаються в кінці місяця.
• Видалення великої кількості операцій стало значно швидшим.
• У налаштуваннях з'явився розділ про те, як налаштувати віджет і команди Siri.
• На екрані категорій тепер видно, що будь-якій категорії витрат можна задати місячний ліміт.
• Дуже велика сума могла завадити застосунку показати підсумки за місяць. Тепер він про це
  повідомляє й підказує, де шукати запис, а не лишає вас без екрана.
• Під час імпорту сума, яку неможливо зберегти, тепер відхиляється із зазначенням рядка, а не
  зберігається спотвореною.
• Виправлення формулювань і перекладів у всіх п'яти мовах.
```

---

## Provenance — every claim mapped to the commit that ships it

### Build 10 additions (2026-09-02)

| Claim in the notes | Where it was verified |
|---|---|
| PDF amounts lost everything after the thousands separator; "4 000,00 ₽" printed as "−4" | `PDFExportRenderTests` — reproduced out of a real rendered PDF, then fixed with a 0-pixel difference against an unconstrained render. Commits `891bcb1`, `f7dde93` |
| the currency symbol could go missing | same suite: "−250,00 ₽" rendered as "−250,00" at the old 56pt column |
| every amount now prints in full | ink-diff 0 px across ru_RU/en_US/de_DE, including a 3-page render |
| a very large amount could stop the app showing this month's totals | `PoisonedAmountLaunchTests` — before the fix the app did not survive launch on such a ledger; it now shows an explanation. Commit `1b6be14` |
| it points you to the entry | the card names Transactions, and the journey test walks there and deletes the row |
| import refuses an amount it can't store, naming the line | `ImportOverflowChainTests` — a 22-digit amount previously imported as **0** with no error; now rejected with the line number via the existing partial-import disclosure |
| **the worked example ("4 000,00 ₽ could print as 4") appears in ru ONLY** | it is a MEASURED claim about ONE locale's rendering, and it is false elsewhere. `PDFExportLayoutTests`/`PDFExportRenderTests` measured ru_RU, de_DE, en_US and ja_JP: with a space separator (ru_RU) the cell keeps only the digits before it; with a period separator (de_DE) it char-wraps MID-number; in en_US the cell renders a BARE MINUS SIGN and nothing else. pt-BR and uk were never measured. The other four locales therefore say only what is true everywhere — part of the amount could be missing, the symbol could disappear — and name no figure. **Do not "helpfully" restore the example across locales.** |

**Not claimed anywhere in these notes**, because it is filed and not fixed: Analytics can still
fail on such a ledger (`outputs/DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md`), and the voice-input
teardown abort (`outputs/DEFECT_VOICE_INPUT_DEINIT_ABORT.md`). The in-app card had a sentence
promising "every other screen works normally" and it was removed for exactly this reason; the
release notes must not reintroduce the same promise.

| Claim | Commit |
|---|---|
| app wouldn't open after updating from a very early version | `8c748b7` |
| the stuck screen warns about deleting + can still export | `8c748b7` |
| partial import reports what was saved | `fa6bfeb` |
| month-end recurrence stays at month-end | `2bb8f2e` |
| bulk delete far faster | `a487658` (148× on a realistic store) |
| Settings entry for Widget & Siri | `e9393e1` |
| category monthly-limit hint | `e9393e1` |
| wording / translation fixes | `7ec2595`, `9167a2c` |

**Deliberately not mentioned:** the reverse-trial clock-rewind fix (`1368ec1`) — describing it tells
users where a loophole was; the App Store link fix (`315b019`) and the removed "Restart onboarding"
button (`6d8de9d`) — too small to spend a line on; and every DEBUG-seam change, which no user can
reach. Nothing about sync, which does not exist in this build.
