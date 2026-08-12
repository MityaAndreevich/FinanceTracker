# BRIEF (Claude Code) — first-run mascot greeting: kill the "sticker" look. Model: Sonnet. Skills: apple-hig-expert, high-end-visual-design, emil-design-eng (motion). Branch `main`. Small, isolated, no data paths touched.

## The problem
`Views/Onboarding/MascotGreetingView.swift` (mounted at `ContentView.swift:80`) renders the crab as a **square image with a visible edge** floating on the screen. It reads as a sticker pasted on a page — cheap. This is the **first thing every new user sees**, so it sets the quality expectation for everything after it.

## The fix — and what NOT to do
**Do NOT add a full-screen multi-colour gradient.** That is the fintech default (see WalletIN, Cently) and it makes us look like a template. The apps in the same scan that read premium (Atlas, Formation, CraftedLogicLab) use a restrained, near-flat background with one strong element and a lot of air. Our own research says: calm base, **single mint accent**, no rainbow, System/Light/Dark switcher with dark as the data-viz default.

Do this instead:
1. **Remove the edge.** The crab must sit on the app's own surface, not inside a visible box — transparent asset (no baked background, no letterboxed bounding box). If the current asset has a background baked in, that's the actual defect; fix the asset, not the layout.
2. **Full-bleed background** in the canonical surface colour for the active theme (`Color.bcBackground` / whatever the design system's base is — use the existing token, do not hand-pick a hex).
3. **Crab centred, generous whitespace**, sized by proportion of the safe area rather than a magic point value; must not clip on the smallest supported device or at the largest Dynamic Type.
4. **Optional, at most:** a very soft radial glow behind the crab in the single mint accent, low opacity. One accent. If it reads as decoration rather than depth, drop it.
5. **Both themes are mandatory.** Verify Light and Dark and System. A treatment that only works in dark is the same cheapness from the other side. Render both via ImageRenderer and check.
6. Motion, if any: restrained — a soft fade/scale on appear. No bounce, no confetti. Quiet Premium.

## Constraints
- Do not touch the onboarding flow logic, `Day0EducationalCard`/tip precedence (`DashboardTeachingSlot.decide`), or any data path. This is presentation only.
- Localized strings unchanged unless the copy itself moves; if it does, all 5 locales.
- No new assets from third parties; no new dependencies.

## Verify
- ImageRenderer captures of the greeting in **Light and Dark**, smallest device width, and largest Dynamic Type — attach or describe what you saw. No clipping, no visible asset edge, no banding in any glow.
- Build + full unit suite green.

## Report (≤6 lines): what the asset actually was (baked background? bounding box?), what you changed, the Light/Dark verification result, files, build/test, commit.
