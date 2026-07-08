# BRIEF (Claude Code) — CSV export/import data-integrity + import dedup. Model: Sonnet + systematic-debugging.

**Priority: LAUNCH BLOCKER.** We advertise "exports CSV/PDF/Excel" and "unlimited CSV import" in App Store metadata + paywall. A finance app that rounds money on CSV export and corrupts categories/names + duplicates on import = guaranteed 1-star reviews and a §2.3 accuracy risk. Fix before submission.

Device QA (real iPhone, multiple locales) found these — several are ONE root cause. Do NOT touch the save/parser (QuickAdd) mechanics; this is the export/import subsystem only. Build green, commit per item with conventional prefixes, push, before/after evidence.

## Token discipline (per standing agreement)
Sonnet only. **Targeted tests only** — the round-trip fidelity test + dedup test described below. NO suite-wide runs, NO UI-presentation tests. Grep-first to locate the CSV writer/reader; Read only those files.

## Item 1 — CSV export corrupts the file via locale decimal separator (CONFIRMED root cause — do NOT re-investigate as "rounding")
**Confirmed from a real device export (ru_RU).** The "rounding" and "EUR in name/category" symptoms are ONE bug in the CSV **writer**: it formats the amount with the **user's locale decimal separator**. In ru_RU `1.52` is written as `1,52`. The file is comma-delimited, so `1,52` splits into two cells (`1` and `52`), shifting every subsequent column one to the right.

Evidence — the exported header is:
`date,type,amount,currency,category,source,tax,note,merchant`  (`source` = Account, `merchant` = name)
and a row that should be `1.52 EUR, Еда и напитки, Круассаны` came out as:
`2026-07-05,expense,1,52,EUR,Еда и напитки,,,Круассаны`
→ `amount`=1 (integer part only — looks "rounded"), `currency`=52 (the lost decimals), `category`=EUR, `source`=Еда и напитки, `merchant`=Круассаны. On re-import the naive reader then maps `EUR` into category/name. That is the whole bug. **Do NOT look for a NumberFormatter rounding / Int cast — the decimals are not lost to rounding, they spilled into the next column.** PDF/Excel are unaffected because they don't serialize through comma-delimited text.

A second, same-class trigger is already visible in the same export: a name with a comma, `Картошка, лук`, will split its column exactly the same way.

**Fix (writer + reader):**
- **Writer — amount:** format locale-invariant with **"." as the decimal separator** and full precision. Use `Decimal` + a fixed formatter (e.g. `Locale(identifier: "en_US_POSIX")`), never the user's locale separator.
- **Writer — RFC-4180:** quote any field that can contain a comma, quote, or newline (names like `Картошка, лук`, notes, categories); escape embedded quotes by doubling (`""`).
- **Reader — RFC-4180:** parse quote-aware, not `split(",")`. Respect quoted fields and doubled-quote escapes.
- **Stable schema:** keep the documented column order; writer and reader share one schema. A Crab-exported file must re-import **field-for-field identical**.

**Test (targeted):** create tx amount `1.52`, currency EUR, category `Еда и напитки`, name `Картошка, лук` → export CSV → import into an empty store → assert amount == 1.52 (exact), currency/category/name preserved, exactly ONE row. Run under **ru_RU** (comma-decimal) — this reproduces BOTH the separator split and the comma-in-name split, the two real device triggers.

## Item 2 — Import dedup + native conflict resolution
Re-importing a file that contains transactions already in Crab silently duplicates them. Users expect the OS-style copy behavior.
- Define a **stable transaction identity** for dedup (e.g. hash of date + amount + currency + name + category + type). Document the choice.
- On import, detect rows whose identity already exists. Instead of silently inserting, present a **native-style conflict choice**, mirroring macOS/iOS file-copy: **"Skip duplicates" / "Import all (keep both)" / "Cancel"**. Show the count of detected duplicates.
- If a full dialog is more than low effort, ship the **safe default first**: skip duplicates by default + a short summary ("N duplicates skipped, M imported"), and add the 3-way choice as the follow-up. Report effort so we decide. Non-destructive behavior is the non-negotiable part.
- **Test (targeted):** import a file whose rows already exist → assert no duplicate rows created under the "skip" path; assert "import all" path creates the duplicates intentionally.

## Item 3 — Voice-entry hint text collapses to one-char-per-line (CONFIRMED, polish, rides along)
On QuickEntry during voice input, the hint "Введите или скажите сумму" (localized) **loses its width and wraps one character per line** — device shows it stacked vertically ("Введ / ите / или / скаж / ите / сумм / у") while entering the "Слушаю… на устройстве" (listening) state, then snaps back to normal. All locales. The text container's available width is collapsing when the listening pill / layout changes. Fix: give the hint label a stable width/frame so it does not reflow when the recording state toggles (e.g. fixed max-width, `.fixedSize(horizontal: false, vertical: true)` with a proper frame, or reserve the space). No data impact. Screenshot before/after.

## NOT in this brief — do NOT fix blind
- **Intermittent crash on entry** (app closed once during entry; the transaction WAS saved on reopen). Per our rule, no blind fix for a non-reproduced crash. If you spot an obvious main-thread hazard in the entry path while working, note it in the report, but do not refactor. We will capture a device Console.app log (filtered to `com.dmitrylogachev.budgetcrab`) if it recurs and brief it separately.

## Report back
Root cause of the CSV rounding and the column-corruption (as found, not assumed). The chosen column schema. Dedup identity definition + whether the 3-way dialog landed or the safe-default-first. Files changed, build status, commit hashes, and the round-trip test output. Target: v1.0 (these are blockers — land before the final clean-reinstall QA pass).
