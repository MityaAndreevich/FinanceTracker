# Budget Crab — Submission Runway (to 20 Aug, hard-first)

**Context:** Today 2026-07-04. CEO returns to LA 20 Aug. **UPDATED TARGET: submit ASAP — within ~2-4 days — as soon as ONE clean device-QA pass is green.** ("1 Aug" was a ceiling, not a floor; earlier submit = more rejection-cycle buffer + earlier data/revenue.) Track A came back essentially clean (paywall already compliant, theme→System, manifest ok, screenshots regenerated + RU/UK localization bug fixed). The ONLY non-negotiable gate before submit: a full device-QA pass — because a LOT changed fast on 2026-07-04 (visual rewrite, save-bug fix, onboarding, theme-default flip, 30d trial copy, localization fix, new screenshots); that's exactly when regressions hide. Gate QA, don't skip it.
**Principle:** App Review rejection is the biggest unknown → **de-risk compliance BEFORE polish.** Onboarding (Brief 28) is done.
Owner tags: **[You]** hands-on (device/ASC) · **[CC]** Claude Code · **[Me]** Cowork (metadata/checklists/research).

## TRACK A — RISK / COMPLIANCE (hardest, front-load — do these first)
1. **[CC] Paywall compliance (3.1.2 rejection risk):** total ANNUAL price is the most prominent element ("$4.99/mo" subordinate); add **Terms/EULA link + Privacy Policy link + Restore Purchases button**; show the trial timeline text ("30-day free trial, then $X/yr"). Verify current PaywallView has all of these.
2. **[You] ASC: annual intro offer → 1 Month (30-day) free trial — ✅ DONE 2026-07-04.** Matches the "30-day trial" copy (3.1.2). Monthly/Lifetime unchanged.
3. **[CC] Privacy manifest verify:** `PrivacyInfo.xcprivacy` declares CA92.1 (UserDefaults), C617.1 (file-timestamp), `NSPrivacyTracking=false`, empty `NSPrivacyTrackingDomains`; `ITSAppUsesNonExemptEncryption=NO`.
4. **[Me→You] Metadata de-risk (§3.2.1 / 2.3):** apply ASO_COPY_PACK to ASC; **NO "money management/investing/banking" language** (we submit as Individual — position as "expense tracker / private notes"); app name ≤30 chars, no price in name; add "not financial advice" disclaimer in description.
5. **[Me] App Review notes + demo:** reviewer notes; the onboarding demo-data path already gives a fully-featured demo (no login) — call it out for the reviewer.

## TRACK B — QA (your hands, after A#1-3 land)
6. **[You] DEVICE_QA in all 5 locales** (en/ru/es/pt-BR/uk) + one small device (SE/mini) + Dark & Light. Run the core loop (Reset→budget→"50 coffe"→Save = 1 clean tx), onboarding, paywall, export. Use DEVICE_QA_CHECKLIST.md.
   - ⚠️ **GATE — CLEAN REINSTALL FIRST (stale-build gotcha):** round-2 device symptoms (edit won't open, transactions "vanish") were traced to a STALE BUILD — the code is fixed at HEAD. Before every QA pass: delete the app from the phone → `git pull` → Xcode Product ▸ Clean Build Folder (⇧⌘K) → Rebuild & Run → THEN test. Don't re-report device bugs without a verified fresh build.
   - **Purchase alert:** the English "You're all set… [Environment: Xcode]" is Apple's StoreKit LOCAL-TEST sheet (does NOT ship). Verify the real flow in **Sandbox** (real sandbox Apple ID, StoreKit config OFF) → system sheet is localized. Nothing to fix in code (no app-owned success strings exist).

## TRACK C — ASSETS (automatable — CC, in parallel)
7. **[CC] Regenerate screenshots** via the DEBUG seams (`--onboarding-step`, `--seed-onboarding-demo`) + simctl → run `compose-screenshots.py`; 5-locale captions; real UI + fictional data. (PH "Featured" badge can be added post-launch.)

## TRACK D — SHIP
8. **[You/CC] Archive build N → TestFlight (internal)** → quick external pass → **Submit for Review.** Target: ~1 Aug.

## DECISIONS (locked 2026-07-04)
- **Theme default → System** (light theme works; dark reserved for paywall). 1-line change → Track A.
- **Trial-expiry reminder → v1.0.1** (not a submission blocker; Apple's own reminder + paywall timeline cover v1.0). Keeps the ~1-Aug date.
- **Submission target: ~1 Aug.**

## QA round 1 (device 2026-07-04) → BRIEF_QA_FIXES_ROUND1.md (pre-submit, in progress)
7 fixes: black-launch, live re-localization, coach-mark pointer/layout, title clip, hint polish, expense=coral, "recent" label. Paywall 3.1.2 compliance VERIFIED on device (Restore/Privacy/Terms present, 30d, annual prominent; RU localized). ASC intro offer must = 1 month to match copy.

## v1.0.1 BACKLOG (deferred to protect submit date)
- "Custom" quick-category chip (create category name+icon from the QuickEntry chip row).
- **Future/scheduled expenses + reminders** (upcoming one-off transactions + notification reminders). Recurring already exists in Settings; future one-offs + reminders = new (needs notification permission) → v1.0.1.
- Extra coach-marks/hints for Analytics + Settings.
- **Visual Help & Tips**: annotated screenshots (arrows/circles showing where to tap) in Settings → Help & Tips. Cheap to build with existing tooling (simctl pipeline + compose-screenshots.py Pillow overlays). Partly redundant with the live coach-marks → lower priority.
- User-controlled trial-expiry reminder + notification priming (conversion lift for 30d trial).
- **Localized privacy policy + site pages** (per-locale Support/Marketing URL, or language switcher on budgetcrab.app). NOT a submit blocker — single EN URL is accepted; localize post-launch to reinforce the privacy wedge (our #1 conversion lever) in RU/ES/PT/UK. Metadata + URLs change without a new build.
- **Daily finance tips** — 365 original tips, random per user, optional toggle. Own-authored (no copied book text = no copyright), generic/public-domain methods only (NO trademarked names: Ramsey/YNAB/EveryDollar), educational not advice (§3.2.1). Candidate Premium hook (tip-of-day free, full library behind paywall). VALIDATE demand + calm-vs-gamification fit via NotebookLM before building.
- **iPad support** — device-family iPad + adaptive layouts + iPad screenshots (Apple requires them if iPad enabled) + QA. Then Mac (runs the iPad build) only AFTER iPad is polished. Additive via normal update; keeps ratings/subs. Have CC scout current device-family/layout readiness post-launch.
- **Import/migration roadmap** (outputs/MIGRATION_IMPORT_ROADMAP.md) — v1.1: flexible CSV import + column-mapping + source presets (Mint/YNAB/bank CSV, handle 2-column debit/credit) → unlocks "switch from Mint" claim + keywords. v1.2+: on-device AI/OCR PDF statement import (privacy moat, ties to AI roadmap). Dedup (hard part) already solved. Claims strictly follow build (2.3).
- **Analytics v1 redesign + color system + TipKit help** (outputs/ANALYTICS_COLOR_RESEARCH_SYNTHESIS.md) — Safe-to-Spend hero (gain-framed) + Pace; donut 3–5+Other+icons; kill blank state; calm-default color scheme (green=income only) + optional classic picker; TipKit contextual help > static annotated screens.

## POST-20-AUG BACKLOG (set up now so it coasts)
- v1.0.1: user-controlled trial reminder + notification priming (conversion lift for 30-day trial); AI photo/voice entry polish (our monetization lever).
- Content: Crab Tech cadence (strategy chat).
- Studio: next-niche via Opportunity Gate (strategy chat).
