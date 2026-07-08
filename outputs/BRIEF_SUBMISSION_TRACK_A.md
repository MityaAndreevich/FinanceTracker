# BRIEF (Claude Code) — Submission Track A (compliance + theme). Model: Sonnet.

De-risks App Review rejection before we submit (~1 Aug). Build green, commit per item, push, report.

## 1. Theme default → System
Change the app's default appearance from Dark to **System** (follow the device setting). Light theme is already implemented and works. Keep the Settings System/Light/Dark toggle. **Reserve dark specifically for the paywall/Pro screen** (force dark there for the premium look) regardless of the app default.

## 2. Paywall compliance (Guideline 3.1.2 — rejection risk). Verify/fix PaywallView:
- The **total annual price** ($34.99/yr) must be the **most prominent** pricing element; any "$4.99/mo"-style breakdown must be visually subordinate (smaller/lighter).
- Add a visible **trial-timeline line**: "30-day free trial, then $34.99/year" (localized).
- Must include tappable **Terms of Use (EULA)** link + **Privacy Policy** link (privacy is live at budgetcrab.app) + a **Restore Purchases** button.
- Localize any new/changed strings in ALL 5 locales (en/ru/es/pt-BR/uk); bump parity baseline.

## 3. Privacy manifest verify (first-submission static-analysis)
Confirm `PrivacyInfo.xcprivacy` declares Required-Reason APIs: **CA92.1** (UserDefaults), **C617.1** (file-timestamp) as used; `NSPrivacyTracking=false`; `NSPrivacyTrackingDomains` empty. Confirm `ITSAppUsesNonExemptEncryption=NO` in Info.plist. Report what's present vs added.

## 4. Regenerate App Store screenshots
Use the DEBUG seams (`--onboarding-step`, `--seed-onboarding-demo`) + simctl to capture the current UI (redesign + onboarding), then run `AppStore/compose-screenshots.py`. **Force DARK appearance for capture** (premium look) even though the app default is now System. Real UI + fictional data. 5-locale captions. Output the 1320×2868 set.

## Report
Per item: files changed, build status, commit hash. For #2 list exactly which of {annual-prominent, trial-timeline, Terms link, Privacy link, Restore button} were already present vs added. For #3 the before/after manifest entries.
