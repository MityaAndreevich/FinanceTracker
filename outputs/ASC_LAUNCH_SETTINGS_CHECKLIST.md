# Budget Crab — Pre-launch settings checklist (set while QA runs)

⚠️ = common first-submission rejection landmine.

## A. App Store Connect — app-level
- [ ] **Primary language** set; **Category** Finance (secondary Productivity/Utilities).
- [ ] **Pricing & Availability:** app = Free (IAP inside). Select territories (our 15+ targets or all).
- [ ] ⚠️ **Support URL + Privacy Policy URL + Marketing URL = budgetcrab.app, and the site actually RESOLVES with a live privacy page.** A dead/placeholder privacy URL = instant reject. Open it in a browser and confirm.
- [ ] ⚠️ **App Privacy label completed** = **Data Not Collected** (can't submit without finishing this section). Tracking = No.
- [ ] **Age Rating** questionnaire done → 4+.
- [ ] **Content Rights:** "contains third-party content?" → No.
- [ ] ⚠️ **App Review Information:** contact name/phone/email filled; **"Sign-in required?" → No**; review notes pasted (no login, demo mode, "not financial advice").
- [ ] **App Store localizations added for all 5** (en, ru, es-MX, pt-BR, uk) so metadata fields exist to paste into.
- [ ] **1024×1024 marketing icon** uploaded (no alpha/transparency).
- [ ] ⚠️ **Version release = "Manually release this version"** — you return to LA 20 Aug; manual release lets you approve now and flip live when you choose (don't let it auto-release while traveling).

## B. IAP / Subscriptions (⚠️ heavy rejection area)
- [ ] All 3 products **attached to this app version** and status **Ready to Submit**.
- [ ] **Localized display name + description for each IAP in all 5 locales.**
- [ ] Annual: intro offer = **1 Month free** (done). Monthly $4.99, Lifetime $99.99.
- [ ] ⚠️ **Lifetime (non-consumable): enable Family Sharing** — our copy says "Shareable via Family Sharing"; if the toggle is OFF, the claim is false (2.3 reject). Turn it ON for that product.
- [ ] ⚠️ **Subscription review screenshot** — Apple requires a paywall screenshot for auto-renewable subs; upload the Premium/paywall shot + short review note.
- [ ] **Subscription group** has a localized display name.

## C. Xcode / build settings (verify before Archive)
- [ ] Bundle ID = `com.dmitrylogachev.budgetcrab` (matches ASC). Version **1.0**, **increment build number** each upload.
- [ ] ⚠️ **Export Compliance:** `ITSAppUsesNonExemptEncryption = NO` in Info.plist (already set) → avoids the per-build encryption prompt. Confirm it's there.
- [ ] Signing: Distribution cert + App Store provisioning (Automatic signing is fine). **Widget extension** embedded + its own signing OK.
- [ ] App icon: all asset-catalog sizes present. LaunchScreen set (done).
- [ ] DEBUG-only test seams (`--seed-onboarding-demo`, StoreKit local config) are `#if DEBUG` gated → NOT in Release. (Confirmed.)
- [ ] No unused entitlements needing justification (we do NOT ship Push for v1.0 — trial reminder is v1.0.1; don't enable Push now).
- [ ] `PrivacyInfo.xcprivacy` present (CA92.1; NSPrivacyTracking=false) — done.

## D. Order of operations
1. Set A + B + C now (parallel to QA).
2. Clean-reinstall device QA green (+ Sandbox purchase) → paste metadata + upload screenshots.
3. Archive → upload build → **select build on the version**.
4. Submit for Review (with **Manual release** chosen).

## Notes
- IAP + app binary are reviewed together on first submission — have all 3 products attached before you hit Submit.
- Standard Apple EULA is fine (no custom EULA needed); Terms/Privacy links are already in the paywall.
