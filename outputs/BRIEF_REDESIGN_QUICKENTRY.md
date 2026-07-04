# BRIEF (Claude Code) — Redesign Quick Entry + Voice screen

Paste into Claude Code. **Model: Opus** for the interaction design (it's the core loop) → Sonnet to execute. **Skill:** `/ui-ux-pro-max`. Source: `outputs/DESIGN_DIRECTION_v2.md`.

## Problem
The current Quick-entry / Add screen is a near-empty black void — a floating "$5.50 Starbucks" placeholder + mic + Save. It looks unfinished next to the redesigned rest, and it under-sells our two best things: **speed** and **on-device privacy**. This is the CORE interaction (fast logging = our #1 retention lever, ff5e0abc) — it must look intentional and premium.

## Goal
Keep the "magic" one-line NL entry ("$5.50 Starbucks" → parsed) FAST (72-second rule — no new required steps), but fill the screen with a **live parsed preview** and premium structure so it reads as crafted, not empty.

## Layout (top → bottom), all tokens (dark default), solid surfaces, mint accent
1. **Top bar:** `X` close (left) + a small trust chip "Stays on your iPhone" with a lock/phone glyph (right). Keep.
2. **Amount, front-and-center:** as the user types or dictates, show the parsed **amount large** (e.g. `$5.50`) in `bcTextPrimary`, currency from `@AppStorage("defaultCurrencyCode")` + Money.swift. Before input: a calm prompt ("Type or say an amount"). This is the hero of the screen.
3. **Live parse preview card** (fills the old void): below the amount, a `bcCard` showing what was parsed — **merchant** + a tappable **category tile** (CategoryIconTile, colored, from the on-device suggestion) + account. Updates live as they type. Tapping the category tile opens the picker. If nothing parsed yet, show a subtle skeleton/hint, not blank.
4. **Category quick-chips:** a horizontal row of 4–6 most-used categories as colored CategoryIconTiles for one-tap assignment.
5. **Input bar:** the existing NL text field (reuse `QuickAddParser` + `CategorySuggestionService` — on-device), styled to tokens.
6. **Mic button — prominent, with a real recording STATE:** idle = mint circle with mic; recording = animated waveform/pulse in mint + "Listening… on-device" caption + live transcription flowing into the amount/preview. Reuse `VoiceInputService` (on-device, `requiresOnDeviceRecognition=true`). Voice is a headline feature — make it feel alive, not a tiny grey button.
7. **Primary Save** (full-width, mint) + **"Use detailed form"** link below. Save auto-commits via `QuickAddSaveService` (merchant-learning fires) with haptic + checkmark.

## Constraints
- FAST first: preview/chips are accelerators, not required steps — a user can type "$5.50 Starbucks" → Save in 2 taps. Don't add friction.
- No predictive modal pop-ups during entry ("Mint pattern" anti-pattern).
- Solid layered surfaces + 1px borders, no gradients on chrome (a mic waveform animation is fine — it's data-viz/feedback, not chrome). No emoji.
- Currency via defaultCurrencyCode; localize all new strings ×5; ForEach keyed by UUID.
- Reuse existing services (QuickAddParser, CategorySuggestionService, VoiceInputService, QuickAddSaveService, CategoryIconTile) — don't reinvent the parse/save/voice logic, only the UI.
- Both Light + Dark must look right.
- No SwiftData change (STOP + report if one seems needed).

## Build / commit / report
`xcodebuild` passes per unit; commit `feat(design): redesign Quick Entry + voice screen`; push. Report (≤6 lines): what changed, files, build status, commit hash, whether the fast 2-tap path is preserved, screenshots of idle + recording states (light + dark).

## Guardrails (originality)
Common patterns (amount-forward entry, category chips, mic waveform) — free to use. Do NOT clone a specific competitor's entry screen. Our crab/mint styling + our layout.
