# BRIEF (Claude Code) — Host the Privacy Policy + return a working URL

Paste into Claude Code. **Model: Sonnet.** **Skill:** none.
Goal: get the Budget Crab privacy policy live at a working public URL under the CURRENT repo (github.com/MityaAndreevich/FinanceTracker) and return it for App Store Connect (required for external TestFlight + submission).

## Context (already in repo)
- Policy content exists: `docs/PRIVACY_POLICY.md` (public-facing) and `_web-files-for-upload/PRIVACY_POLICY.html` (ready-to-host HTML). Also `APP_PRIVACY_ANSWERS.md` (label answers).
- A STALE url is referenced in `TESTFLIGHT_CHECKLIST.md` (`dmitrylogachev.github.io/Vela/...`) — wrong username + repo. Do not reuse it.
- Guide available: `.studios/AppStudio/templates/github-pages-setup.md`.

## ⚠️ REQUIRED TEXT CORRECTIONS (Cowork audit 2026-07-02 — fix BEFORE hosting)
`docs/PRIVACY_POLICY.md` is out of sync with the app + the privacy label (`APP_PRIVACY_ANSWERS.md` = "Data Not Collected", v1.0 local-only). Fix these — they are alignment corrections, but confirm the iCloud/OCR call with the user:
1. **Brand: replace ALL "Vela" → "Budget Crab"** (title, effective-date line, §1, §2, everywhere). The app's public name is Budget Crab.
2. **iCloud sync + camera Receipt OCR are NOT in v1.0** (privacy answers §1.4 + §3.7; the privacy manifest declares no camera). The policy currently describes both as available (§2, §10, in-plain-language). For the v1.0 launch policy: **REMOVE the iCloud-sync and camera/Receipt-OCR/Vision passages** (describe only what ships). Re-add them when those features actually ship (and re-audit the label per APP_PRIVACY_ANSWERS §6). [User decision: remove for launch (recommended) vs reframe as "features we may add later".]
3. **ADD on-device VOICE disclosure** (v1.0 has voice entry, currently NOT in the policy): microphone + speech are used only on tap, transcribed **on-device** (`requiresOnDeviceRecognition=true`), audio never persisted or uploaded. (Matches NSMicrophone/NSSpeechRecognition usage strings.)
4. **ADD support-email line** (required by privacy answers §3.7): "If you contact us by email, we receive the information you choose to send."
5. Keep the "Data Not Collected" summary table + DNT/ATT sections (they're correct).
6. Do NOT invent new claims; keep it aligned to APP_PRIVACY_ANSWERS.md exactly.

## Steps
1. Check if GitHub Pages is enabled for this repo (`gh api repos/MityaAndreevich/FinanceTracker/pages` or repo Settings → Pages).
2. If not enabled: publish the policy. Simplest — put `PRIVACY_POLICY.html` (and `support.html` if it exists) into a `/docs` folder on `main`, commit, push, then enable GitHub Pages with **source = main / /docs**.
3. Wait for the Pages build, then `curl -sI <url>` and confirm **HTTP 200** + `curl -s <url> | head` shows the privacy content (not a 404 / not the repo README).
4. **Before publishing, sanity-check the policy text** matches reality: offline, on-device, no data collection, no bank connection, no accounts. If `docs/PRIVACY_POLICY.md` contradicts `APP_PRIVACY_ANSWERS.md`, flag it — do NOT silently edit legal text; report the discrepancy.
5. Update the stale URL in `TESTFLIGHT_CHECKLIST.md` (and any other doc) to the new working URL. Commit + push.

## Report back (≤6 lines)
1) final working Privacy Policy URL (+ Support URL if hosted), 2) HTTP status confirmation, 3) whether Pages was already on or newly enabled, 4) files/commits changed, 5) any text discrepancy found (do not fix legal copy without asking).

## Guardrails
- Don't alter the legal/policy TEXT to make it fit — if it's wrong, report and we fix deliberately.
- Don't touch app code, pricing, or ASC.
- The repo is public-facing via Pages — confirm no private/secret files are exposed by the /docs publish.
