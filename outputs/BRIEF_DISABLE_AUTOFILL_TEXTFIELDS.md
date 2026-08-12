# BRIEF (Claude Code) — stop text fields offering Passwords/Contacts autofill. Model: Sonnet. Branch `main`. Presentation only. Small but on-brand (we sell privacy).

## The problem
Tapping a search field (and other text fields) pops iOS autofill for **Passwords and Contacts**. For a privacy-positioned budgeting app this reads careless/alarming ("why does my budget app want my passwords?"). Cause confirmed by grep: **no `TextField` or `.searchable` in the app sets `.textContentType`**, so iOS heuristically offers credentials/contacts.

## Fix — set the right content type on every text-input surface
Suppress the credential/contact autofill on fields that are not logins (all of ours — the app has no accounts). The correct suppressor is `.textContentType(nil)` (SwiftUI) — verify it actually kills the Passwords key on device; if a stubborn field still shows it, that field's heuristic is triggered by an adjacent field or label, so also set the neighbours.

Surfaces to cover (from grep — confirm the full set, don't rely only on this list):
- **Search fields (highest priority — this is what the founder hit):**
  - `TransactionsView.swift:83` `.searchable`
  - `LearnAndTipsView.swift:122` `.searchable`
  - `CategoryPickerSheet.swift:77` `.searchable`
  - `SFSymbolPicker.swift:79` `.searchable`
  - `SearchablePickerSheet.swift:41` `.searchable`
  - `ElevatedSelectionList.swift:65` search `TextField`
  Note: a SwiftUI `.searchable` field is harder to reach than a `TextField` — determine the correct way to set content type / disable autofill on `.searchable` specifically (it may need a different approach than a plain TextField). Report what works.
- **Name / note / merchant text fields** (should not offer contacts): AddCategorySheet, AddTransactionView (title/note/source name+note), EditTransactionView (merchant/note), CategoriesSourcesView (source name+note), QuickEntryView input, DashboardView QuickAdd.
- **Amount/budget fields** already use `.decimalPad` so autofill isn't offered, but set content type for consistency if trivial.

## Constraints
- Do not add password/credential content types anywhere — we never want AutoFill offering to *save* anything either.
- Consider a small shared modifier (e.g. `.plainTextEntry()`) applied across fields so this can't regress field-by-field — but don't over-engineer; if a one-liner per field is clearer, do that.
- No data paths, no logic. Presentation only. Localized strings unchanged.

## Verify
- On device: tap each search field and each name/note field → **no Passwords key, no Contacts bar** in the QuickType row. Confirm the QuickType autocorrect suggestions (normal typing) still work where wanted.
- Build + suite green.

## Report (≤6 lines): how you disabled it on plain TextFields vs on `.searchable` (if different), the full list of fields touched, whether you used a shared modifier, device-verified no-passwords-key result, build/test, commit.
