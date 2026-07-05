# Quick Entry UX polish — design (v1.0)

Date: 2026-07-05
Scope: two friction fixes on the transaction-entry surfaces. Target v1.0 (lands before
final clean-reinstall QA pass). **Save / parser / rollback mechanics are NOT touched.**

## Inspection (current behavior, as found)

Two entry surfaces exist and behave differently:

- **QuickEntryView** (`Views/QuickEntry/QuickEntryView.swift`) — hero NL sheet, default `+`
  destination.
  - Save: `handleSave()` → `QuickAddSaveService.save(...)` → `dismiss()`. Single save,
    dismisses to list. Re-entrancy guarded by `isSaving`.
  - Category: pre-parse 6-chip quick-row; once parsed, preview card's category row opens
    `CategoryPickerSheet` — already a native bottom sheet (`.presentationDetents([.medium,
    .large])`), searchable, full kind-list, add-new. **Item 2 already satisfied here.**
- **AddTransactionView** (`Views/AddTransactionView.swift`) — detailed form (via "Use
  detailed form" + recurring edit).
  - Save: `add()` → `modelContext.save()` → `dismiss()`. `resetFormKeepType()` exists but
    is unused.
  - Category: `Picker` bound to `displayedCategories` (**primary subset**) + "Show all (N)"
    toggle → two-step "where did they go" jump. **This is the Item 2 friction.**

`QuickAddSaveService.save` throws-and-rolls-back on failure (removes the pending insert),
so the guarded save path is intact and reused verbatim.

## Decisions

- Item 1 → **QuickEntry only**.
- Item 2 → **reuse `CategoryPickerSheet`** in AddTransactionView.
- Target **v1.0**.

## Item 1 — "Save & add another" (QuickEntryView)

- Refactor `handleSave()` → `handleSave(addAnother: Bool = false)`. Body and the
  `QuickAddSaveService.save(...)` call are identical; only the success tail branches:
  `addAnother ? resetForNextEntry() : dismiss()`. Failure path unchanged (rollback,
  `saveError = true`, `isSaving = false`). Existing call sites keep calling `handleSave()`.
- `resetForNextEntry()`: clear `inputText`, `parsed`, `categoryOverride`,
  `categoryManuallyPicked`, `saveError`; cancel `parseTask`; `voice.stop()`;
  `isSaving = false`; set `savedToast`; `isInputFocused = true`.
- Success toast: new `@State savedToast: LocalizedStringKey?` +
  `.confirmationToast($savedToast, duration: 2.0, style: .success)`.
- Button: plain tinted **text** button below filled Save, shown only when `parsed != nil`,
  disabled while `isSaving`. Hierarchy: filled Save → "Save & add another" → outlined
  "Use detailed form".
- New string `quick_entry.save_add_another` in all 5 locales.

## Item 2 — Category reveals ALL inline (AddTransactionView)

- Replace the subset `Picker` + "Show all (N)" with a tappable row (icon + selected name +
  chevron) opening `.sheet { CategoryPickerSheet(currentType: typeRaw) { ... } }`. onPick
  moves the old `categoryPickerBinding.set` logic (set uuid, mark chosen, clear
  suggestion/tip/prefill).
- Keep: suggestion pill, auto-detected pill, "pick Other" tip, empty-state branch, inline
  "Add category" button.
- Remove dead: `displayedCategories`, `hasSecondaryCategories`, `showAllCategories`
  (+ its reset in `onChange(of: typeRaw)`), `categoryPickerBinding`.
- Preserves selection highlight, Other/uncategorized reachable, user-created included,
  auto-detected pre-selection. No new strings.

## Tests

- Single-row persist via the add-another save path; forced-failure (`_forceSaveFailureForTesting`)
  rolls back to 0 rows.
- `CategoryPickerSheet.filtered` returns the complete kind-filtered set including a
  user-created category.
- `ensureValidCategorySelection` still defaults to "Other".

## Risk

- Item 1: low-med effort, low risk — additive, save mechanics untouched.
- Item 2: low effort, low risk — component swap + dead-code deletion, no new strings.
