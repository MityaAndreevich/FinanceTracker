# BRIEF (Claude Code) — v1.0.1 Widget: real glass on the container + 2 polish fixes. Model: Sonnet. Skills: apple-hig-expert (WidgetKit Liquid Glass / glassEffect), swiftui-design-skill. Run find-skills if unsure which fits.

**v1.0.1 (1.0 in App Review — don't touch the submitted build).** `main`, commit per item, push, `xcodebuild … build` before commit. Visual pass only — do NOT change the NetSnapshot data contract, hero precedence, spendSeries, contentSignature, or localization. Localize any new strings in all 5 locales.

## Evidence (device, photo wallpaper — don't re-derive)
Screenshot over a real photo wallpaper (forest): the **dock is translucent and refracts the wallpaper**, but the **Budget Crab widget is a fully opaque white plate** — the trees do NOT show through it. Conclusion: the current `.containerBackground` using `.regularMaterial` is rendering **opaque, not as Liquid Glass**. (Over the previous flat-color wallpaper this was invisible; the photo wallpaper proves it.)

## Item 1 — Put real glass on the widget CONTAINER (not just the icon chip)
- Under `#available(iOS 26, *)`, give the widget container a real **`glassEffect(_:in:)`** (SwiftUICore) so the wallpaper refracts through it like the system dock/controls — instead of the opaque `.regularMaterial` plate. The container's shape should be the widget's rounded rect.
- Keep content (hero number, ambient chart, category rows, chip) **opaque and legible on top** of the glass — glass is the material layer, content stays solid (HIG).
- Verify the API against the installed SDK before building (last time `.liquidMaterial` didn't exist — confirm the exact `glassEffect` signature/shape API in the iOS 26.5 SDK swiftinterface, don't guess).
- **Fallback `< iOS 26`:** keep the current calm opaque card (that path is correct for older OS).
- If, after applying `glassEffect` to the container, the wallpaper still does not show through in the simulator over a photo wallpaper, STOP and report what you tried + the API you used — don't ship another opaque plate calling itself glass.

## Item 2 — Ambient chart must not fight the subtitle
The green ambient line/area crosses the "из … дохода" subtitle, hurting legibility (worst in dark mode + small). Fix: keep the ambient layer clearly **behind** the text with enough separation — lower the chart's opacity under text, and/or reserve the text band (nudge the chart baseline down / add a subtle scrim behind the subtitle), so the subtitle is always cleanly readable. No ellipsis, no overlap.

## Item 3 — Dark-mode ambient chart too faint
On small/medium in dark mode the ambient green chart nearly disappears. Raise its contrast in dark mode (brighter stroke / slightly higher fill opacity) so it reads as an intentional element, not a smudge — while staying calm (not neon). Light mode already reads fine.

## Tests (targeted)
- `#available(iOS 26)` branch applies `glassEffect` to the container; `< iOS 26` uses the opaque card; both compile in the one binary.
- Ambient chart guards unchanged (isFinite, clamp, empty → no chart).
- Subtitle legibility: assert the chart layer is behind the text (z-order) and the reserved-band/opacity change is applied.
- No regression to hero precedence, formatCompact, or longest-locale truncation.

## Report (≤6 lines/item): the exact glass API used (verified against the SDK), the container change, the two polish fixes, files, build status, commit hash per item. **MANDATORY:** attach simulator screenshots over a **PHOTO wallpaper** (iPhone 17 / iOS 26.5), all 3 sizes, light + dark — the wallpaper MUST be visible through the glass, or the item isn't done. If simctl still can't place home-screen widgets, say so and the human will capture; but the glass must be demonstrable in the Xcode preview canvas over a photo background at minimum.
