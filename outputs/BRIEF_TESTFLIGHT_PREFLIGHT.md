# BRIEF (Claude Code) — TestFlight pre-flight check

**Paste into Claude Code.** Model: **Sonnet**. Skill: `/release-review` recommended.
Goal: catch anything that would fail or embarrass the first TestFlight archive — BEFORE the user does the GUI Archive+Upload. Do NOT attempt the signed upload (needs the user's Apple ID); this is verification + safe fixes only.

## Known good (already verified 2026-07-02)
- MARKETING_VERSION 1.0, CURRENT_PROJECT_VERSION 1 (fine for build #1).
- CODE_SIGN_STYLE Automatic, DEVELOPMENT_TEAM 2867U8T596.
- Bundle `com.dmitrylogachev.budgetcrab` (+ `.widget`). PrivacyInfo.xcprivacy present. AppIcon 1024 present.

## Checks + safe fixes
1. **Release compile (no signing needed):** run
   ```
   xcodebuild -scheme FinanceTracker -configuration Release \
     -destination 'generic/platform=iOS' -derivedDataPath build/release \
     CODE_SIGNING_ALLOWED=NO clean build
   ```
   Must succeed. Fix any Release-only compile errors (warnings-as-errors, unavailable API, etc.).
2. **DEBUG-only demo/screenshot code must NOT ship in Release.** Confirm `ScreenshotMode`, `--demo-mode-debug-only`, DemoSeeder, and any screenshot launch-arg handling are wrapped in `#if DEBUG`. If any is reachable in Release, gate it. (capture-screenshots.sh claims demo mode is DEBUG-only — verify it's true.)
3. **Encryption export compliance:** add to the app's Info.plist (if not present):
   `ITSAppUsesNonExemptEncryption = NO`
   Justification: app is offline/local-first, uses only standard OS encryption (if any), no custom/non-exempt crypto. This skips the manual "export compliance" prompt on every upload. ⚠️ Confirm the app makes no network calls using non-exempt crypto before setting this; if unsure, tell me and leave it.
4. **Widget builds** in Release too (it's part of the archive). Confirm no widget-only Release errors.
5. **Privacy manifest sanity:** open `FinanceTracker/PrivacyInfo.xcprivacy` — confirm it declares required-reason APIs actually used (e.g., UserDefaults, file timestamp) and no data-collection we don't do. Flag mismatches, don't guess-fill.
6. Optional: run `/release-review` for a final pass.

## Report back (≤8 lines)
1) Release build result, 2) any fixes applied (files + why), 3) demo/screenshot DEBUG-gating status, 4) whether ITSAppUsesNonExemptEncryption was set, 5) privacy manifest OK?, 6) commit hash if anything changed (conventional `chore:`/`fix:`), 7) anything that will block the GUI archive.

## Do NOT
- Do not archive/sign/upload (user does this in Xcode GUI).
- Do not bump the build number yet (build 1 is correct for the first upload; only bump on a re-upload).
- Do not touch ASC, prices, or IAPs.
