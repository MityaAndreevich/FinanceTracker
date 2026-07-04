# BRIEF (Claude Code) — Screenshot slot 08: paywall-with-prices → no-price close

**Paste into Claude Code.** Model: **Sonnet**. Skill: `/ui-ux-pro-max` recommended for the visual.

## Problem
`AppStore/capture-screenshots.sh` routes screen id **`lifetime` (slot 08)** to the **mock paywall showing prices** ($4.99/$34.99/$99.99, "Save 42%", CTAs). This contradicts `AppStore/screenshots-storyboard.md` slot 8, which specifies a **calm "yours to keep" close with NO price text**. Prices-in-screenshots are also fragile (break on every price change — we just hit that) and off-brand vs Quiet Premium.

**Decision (CEO, 2026-07-02):** replace slot 08 with a no-price ownership close.

## Goal
When launched with `--screenshot-screen lifetime`, the app should render a **calm, no-price "ownership close"** screen (raw capture; marketing caption "Yours to keep, for life" is composed later in Figma — do NOT bake captions in-app).

## Steps
1. **Investigate** (grep/read, don't guess):
   - `FinanceTracker/Data/ScreenshotMode.swift` — `Screen` enum (`case lifetime // 08 — paywall / ownership close`) + `usesMockPaywall`.
   - Find where `usesMockPaywall` / the `lifetime` screen decides to show `PaywallView` (mock). That routing is what to change.
2. **Build the close screen** — a lightweight SwiftUI view for screenshot mode:
   - Content: app icon / Budget Crab crab mark + generous whitespace, single sage accent (#3DDC97 family, per DESIGN_SYSTEM), warm cream background to match the storyboard's cohesive shelf.
   - **NO prices, NO "Save %", NO plan cards, NO CTA buttons.** A composed "yours to keep" panel or a clean dashboard glimpse (storyboard slot 8 allows either).
   - No baked caption text (Figma adds it). Keep it visually calm — this is the Ruler ownership close.
   - Reuse existing brand assets/colors; don't introduce new dependencies.
3. **Route** `--screenshot-screen lifetime` to this new view instead of the mock paywall. Keep `usesMockPaywall` for any real in-app paywall use unaffected — only the screenshot slot changes.
4. **Regenerate** screenshots: `AppStore/capture-screenshots.sh ALL` (redoes 8×4; 01–07 identical, 08 now no-price). If a simulator device name error appears, set `DEVICE=` to an installed Pro Max sim.
5. **Verify:**
   - Open `AppStore/screenshots/EN/08_lifetime.png` (and RU/ES/PT-BR) → confirm **no $ amounts, no "Save 42%", no CTA**.
   - `grep`-free visual check; the four 08 files should look calm and consistent.
6. **Build** must pass (`xcodebuild`). **Commit + push** (conventional):
   ```
   feat(screenshots): slot 08 = no-price ownership close (was mock paywall)

   Storyboard slot 8 specifies a calm no-price close; the capture script was
   routing to the mock paywall with prices — off-brand + fragile to price
   changes. Reroute lifetime screenshot screen to a no-price close; regen 8x4.
   ```
   (Note: `AppStore/screenshots/` may be untracked — if so, the PNGs won't commit; that's fine, the code change is what matters. Confirm whether screenshots are tracked and tell me.)

## Report back (≤6 lines)
1) what changed, 2) files changed, 3) build status, 4) commit hash, 5) confirm the four 08 PNGs have no prices, 6) whether AppStore/screenshots/ is git-tracked.

## Guardrails
- Only slot 08 changes. Do NOT touch slots 01–07, real paywall pricing, `.storekit`, or ASC.
- No prices/CTAs on the close screen. No baked captions.
- If building a new view is heavier than expected, the minimal acceptable fallback is: render the existing paywall view in a "no-price" screenshot variant (hide price labels + CTAs). Tell me which approach you took.
