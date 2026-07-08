# BRIEF (Claude Code) — v1.0.1 follow-ups: money-parser consolidation, ambiguous-date safety, + 2 widget tails. Model: Sonnet + TDD.

`main`, commit per item, push, `xcodebuild … build` before each commit. Localize new strings in all 5 locales. No blind fixes — if you disagree with an item, say why with evidence instead of implementing it.

---

## Item 1 (HIGH) — One money-parsing core, not two
You wrote: *"a dedicated tokenizer (not `Money.parseCents`, which mangles grouped numbers)"*. That means Budget Crab now has **two independent implementations of "money string → cents"**: the QuickAdd NL tokenizer (fixed in `e219c15`) and the new CSV mapper tokenizer.

We have already shipped **two separate production bugs in exactly this area** — CSV locale decimal separator (`16f8b75`) and the QuickAdd amount parser (`e219c15`). A third implementation will diverge. Money parsing is where silent data corruption lives.

The *top-level semantics* legitimately differ (NL phrase in the **user's** locale vs a CSV field in the **file's** declared format). The *numeric core* does not.

Do this:
- Extract ONE pure function into `Shared/` (e.g. `AmountParsing.parseAmount(_ s: String, decimalSeparator: Character, groupingSeparators: Set<Character>) -> Int?` returning cents).
- Make **both** the QuickAdd NL tokenizer and the CSV column mapper call it, each supplying its own separators. Delete the duplicated numeric logic.
- If `Money.parseCents` "mangles grouped numbers," that is **a bug in `Money`** — fix it there rather than routing around it with a copy. Report what exactly it mangled.
- Tests: one shared parse table exercising the core (`1,234.56` / `1.234,56` / `10 143,15` / NBSP grouping / `.15` / `1234` / garbage → nil), plus the existing QuickAdd + CSV suites still green through the shared core.
- If you believe the core genuinely cannot be shared, do NOT implement — reply with the concrete counter-example that breaks it.

## Item 2 (HIGH) — Ambiguous dates must not be guessed silently
`.auto` infers day/month order "only from a component > 12." So what happens with a file where **every** date is ambiguous (`03/04/2026`, `05/06/2026`, …)? If it silently defaults to US order, we transpose day and month across an entire European bank file — the user will never notice. That is worse than a crash.

The brief required: *"surface the detected format in the preview so the user can correct before import. Never silently guess wrong."* Your report doesn't mention it.

Do this:
- In the mapping sheet, **display the detected date format** next to the date column, with the parsed preview values visible.
- When the order is genuinely ambiguous (no component > 12 anywhere in the sample), **require the user to pick the order** (or default visibly with a clearly labelled, one-tap-switchable control). Never proceed on an unconfirmed guess.
- Tests: (a) a fixture where all dates are ambiguous → the mapper reports `ambiguous` rather than choosing; (b) user-declared order applied correctly; (c) preset-declared order wins over `.auto`; (d) a `>12` component still auto-resolves.
- Report the exact behaviour that existed **before** this change (did it default to US?) — I want to know whether the shipped code could have transposed dates.

## Item 3 — Verify the widget `contentSignature` root cause (from `412e17a`)
The observed device symptom was a **1,000,000 ₽ "Квадроцикл" transaction missing from the widget**. Your root cause was that rebuild was keyed on `transactions.count`, which is invariant under **edits**. But a plain **add** changes `count` — so count-keying would have caught it.

- Confirm the original scenario reproduces on the commit **before** `412e17a` and passes **after**.
- Add tests covering all three paths: **add / edit / delete** each update the snapshot.
- If the offending transaction was a plain add (not an edit), the root cause is **incomplete** — there is a second cause. Say so explicitly rather than closing the item.

## Item 4 — Localize the AppIntent widget-configuration labels
"Ring / Minimal / Style" are currently English-only. Correction to the rule you recorded: the bake-the-language decision governs **snapshot content** (category names have no localization keys, chrome follows the *app's* language). **AppIntent configuration labels are static extension chrome** shown in iOS's widget edit sheet and correctly resolve against the **system** language — exactly like Apple's own widget config.

- Add a small `.strings` table to the **widget target**: 3 keys × 5 locales (Ring / Minimal / Style, plus any other visible parameter names).
- This does **not** reintroduce key-based snapshot localization — do not touch the baked snapshot path.
- Update your recorded rule so it doesn't ossify as "never add .strings to the extension."

---

## Report
Per item: what changed (or why you disagree), files, build status, commit hash. For Item 2, state plainly whether the previously shipped code could silently transpose day/month. Do NOT touch marketing copy — "switch from Mint" claims stay gated until the human device-verifies the mapping sheet.
