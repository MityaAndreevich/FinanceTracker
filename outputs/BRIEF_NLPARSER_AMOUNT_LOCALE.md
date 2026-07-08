# BRIEF (Claude Code) — QuickAdd NL parser: wrong amount on large/decimal/kopeck input (LAUNCH BLOCKER). Model: Sonnet + systematic-debugging + TDD.

**Priority: LAUNCH BLOCKER — the parser silently records the WRONG amount on the marquee entry feature.** Worse than a crash (data corruption, user doesn't notice). This is a deliberate change to the amount-extraction logic of the QuickAdd parser (previously off-limits — now the target). Keep the save path, the `amountCents > 0` invariant, dedup/UUID, and CSV untouched. Build green, commit, push. TDD: write the parse table first, watch it fail, then fix.

## Confirmed device evidence (ru_RU) — do NOT re-derive
| Input (text or voice) | Parsed (WRONG) | Expected |
| --- | --- | --- |
| text `10143,15` | `15,00 ₽` | `10143.15` |
| text `10 143,15 руб.` | `1 014 315,00 ₽` | `10143.15` |
| voice «тысяча триста сорок два рубля 15 копеек» (Speech ≈ `1342 рубля 15 копеек`) | `15 ₽` | `1342.15` |
| voice amounts ≤ 1000 | OK | OK |
Diagnosis: (1) decimal comma is being dropped/mis-handled and grouping separators (space/NBSP/period) concatenated; (2) wrong numeric token selected as the amount (it grabs the minor-unit group); (3) major+minor units not combined (rubles+kopecks).

## Fix — one robust locale-aware amount tokenizer
Replace the amount-extraction with a single function that, given the raw NL string + the active currency/locale (`@AppStorage("defaultCurrencyCode")` / user locale):
1. **Grouping vs decimal separators, locale-correct:**
   - Comma-decimal locales (ru, uk, pt-BR, es-ES…): decimal = `,`; grouping = space / NBSP / `.`. `10 143,15` and `10143,15` → `10143.15`. Never drop the decimal comma; never concatenate groups.
   - Period-decimal locales (en-US, es-MX…): decimal = `.`; grouping = `,` / space. `10,143.15` → `10143.15`.
   - Strip only true grouping separators; keep exactly one decimal separator; cap minor units at 2 digits.
2. **Correct token selection:** when multiple numeric tokens exist (amount + minor units, or stray digits), pick the amount as the primary quantity and treat a trailing minor-unit group as fractional (below). Don't pick the last/smallest token by accident.
3. **Combine major+minor unit words → one amount:**
   - ru: `руб/рубль/рубля/рублей/₽/р` + `коп/копеек/копейки/копейка` → `major + minor/100`. `1342 рубля 15 копеек` → `1342.15`.
   - en: `dollar(s)/$` + `cent(s)/¢`. es: `peso(s)/$` + `centavo(s)`. pt-BR: `real/reais/R$` + `centavo(s)`. uk: `грн/гривня/гривень/₴` + `коп/копійки/копійок`.
   - If only a decimal number is given (no unit words), use it directly.
4. **Spelled-out numbers (voice):** iOS Speech usually returns digits for ru/en; if word-number fragments slip through (e.g. `тысяча`), map the common scale words. Verify with the device example — likely Speech already gave `1342 …` and the bug is token-selection, so prioritize (2)+(3); add word-number mapping only if needed.
5. Preserve the name/merchant extraction (the non-numeric remainder → name), and keep `amountCents > 0` guard.

## Tests (targeted, TDD — write first)
A parse table asserting `parse(input, locale) == expectedCents`, covering **all 5 launch locales**:
- ru_RU: `10143,15`→1014315¢; `10 143,15 руб.`→1014315¢; `1342 рубля 15 копеек`→134215¢; `50 коп`→50¢; `1000`→100000¢.
- en_US: `10,143.15`→1014315¢; `10143.15`→1014315¢; `12 dollars 5 cents`→1205¢; `$1,342.15`→134215¢.
- es_MX (period-decimal): `10,143.15`→1014315¢; `1342 pesos 15 centavos`→134215¢.
- pt_BR (comma-decimal): `10 143,15`→1014315¢; `1342 reais 15 centavos`→134215¢; `R$ 10.143,15`→1014315¢.
- uk_UA (comma-decimal): `10 143,15`→1014315¢; `1342 гривні 15 копійок`→134215¢.
- Edge: no decimals `500`; decimals only `,15`/`.15`→15¢; trailing period `10 143,15 руб.`; category name with no digits doesn't perturb the amount.
Run under the matching locale. No suite-wide runs.

## Report
The exact defect(s) found in the current extractor, the new tokenizer approach, the full green parse table, files changed, build status, commit hash. Device-verify the three evidence rows above (voice needs a device). Target: v1.0 (data-correctness blocker on the core feature).
