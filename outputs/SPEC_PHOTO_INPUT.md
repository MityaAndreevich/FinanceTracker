# Spec — Photo / Receipt input (on-device OCR)

**Status:** spec-ready (target v1.1, after redesign + launch). Not a build brief yet — convert when scheduled.
**Build model when scheduled:** **Opus** for the Vision + parsing architecture, then **Sonnet** for the UI/wiring. **Skills:** `/ui-ux-pro-max` (entry UX), `/security-review` (privacy pass).
**Traces to:** NotebookLM 73afc9a4 ("AI-assisted entry / receipt+screenshot import, LOCAL" = top manual-app request), ff5e0abc (friction = #1 churn), review mining (logging_friction). Local-first fit: 100% on-device.

## 1. Why (the pitch)
Snap a receipt → a filled transaction, **without the photo ever leaving the iPhone.** Solves our #1 churn risk (entry friction) while reinforcing the privacy moat (Apple Vision runs fully on-device — no server, no upload). A real gap: aggregators avoid manual entry via bank-sync; privacy/manual apps rarely offer OCR. This is a headline differentiator + a premium upsell.

## 2. User flow (MVP)
1. In the Add / Quick-entry sheet, add a **camera / photo** button next to voice.
2. User captures a photo (camera) or picks from library (PhotoKit).
3. **On-device OCR** (Vision `VNRecognizeTextRequest`, `.accurate`) extracts text in-memory.
4. **Parse** → prefill the Add sheet: amount, merchant, date (best-effort). Category defaults to "Uncategorized" (no speculative modal — anti-"Mint pattern").
5. User reviews/edits the prefilled fields → **Save** (reuses existing `QuickAddSaveService` so merchant-learning + side-effects fire like normal entry).
6. Optional: attach the image to the transaction (local only) — behind a toggle; default OFF to keep storage lean.

Fallback: if parsing confidence is low, prefill the amount field empty + show the recognized text as a hint; never block the user.

## 3. Parsing heuristics (on-device, no ML server)
- **Amount:** prefer a line containing a "total/итого/total/importe/total" keyword (localized); else the largest currency-formatted number. Respect `@AppStorage("defaultCurrencyCode")` + `Shared/Money.swift` formatting. Handle thousands/decimal separators per locale.
- **Merchant:** top 1–2 non-numeric lines (store name usually at top).
- **Date:** regex for common date formats; else default to today.
- Keep heuristics simple + transparent; the user confirms everything. Do NOT over-engineer an ML pipeline in MVP.

## 4. Privacy (must reinforce our positioning)
- Image + recognized text processed **in memory**; not persisted unless the user explicitly attaches it. **No network calls.** Confirm in `/security-review`.
- Info.plist: `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` — honest, on-device wording (localized ×5). Example EN: "Budget Crab reads receipts on your device to fill in a transaction. Photos are never uploaded."
- Privacy manifest: no new data collection categories (still all on-device). Verify `PrivacyInfo.xcprivacy` unchanged / accurate.
- Marketing line (true + strong): "Snap a receipt. It's read on your iPhone and never uploaded."

## 5. Scope
**MVP (v1.1):** single-receipt capture → parse amount/merchant/date → prefill → confirm → save. EN/RU/ES/PT-BR/UK strings + parsing keywords.
**Later (v1.2+):** batch import (multiple receipts), screenshot-of-bank-app parsing, attach-image gallery, smarter ML parsing via Foundation Models (ties to NL quick-add #6).

## 6. Monetization
Candidate **Premium** feature (advanced entry) — aligns with hybrid access model. Free users get manual + voice; photo OCR is a premium unlock. Decision: confirm against conversion data; could also offer N free scans as a taste. Flag for pricing review, don't hardcode.

## 7. Edge cases
Multiple amounts (tip/subtotal/total) → pick total-keyword line; non-receipt photo → low confidence → graceful fallback; blurry/low-light → prompt retake; very long receipts → scroll recognized text; non-Latin scripts → Vision supports many, verify per launch locale.

## 8. Acceptance criteria
- Capture → filled Add sheet in one flow, offline (airplane mode works).
- No network request fires during OCR (verify with a network-activity check / `/security-review`).
- Amount/merchant correct on a set of ~10 real receipts across locales (manual QA).
- Permission strings present + localized ×5; no crash on permission denied.
- Reuses `QuickAddSaveService`; merchant-learning fires; currency via `defaultCurrencyCode`.
- Build passes; behind a feature flag if partially done.

## 9. Originality guardrail
On-device receipt OCR is a common technique — free to build. Do NOT copy any competitor's receipt-scanner UI, iconography, or copy. Our flow = our Add-sheet + our crab/mint styling + our wording.

## 10. Ready-to-build checklist (when scheduled)
- [ ] Convert this spec into a Claude Code build brief (English, model per §top).
- [ ] Confirm premium-gating decision with pricing.
- [ ] Add camera/photo entry point to the (redesigned) Add sheet — do AFTER the redesign so it inherits new tokens.
