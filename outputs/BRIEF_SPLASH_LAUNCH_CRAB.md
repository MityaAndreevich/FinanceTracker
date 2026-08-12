# BRIEF (Claude Code) — LaunchScreen storyboard only: drop the navy square around the crab. Model: Sonnet. Skills: apple-hig-expert. Branch `main`. Presentation only. Scope is TIGHT.

## Scope — read this first
- **LEAVE `SplashView.swift` exactly as it is.** The founder likes the animated post-launch splash. Do not touch it.
- **Only change `LaunchScreen.storyboard`** — the static OS launch screen. Today it shows `LaunchLogo` (the 1024² app-icon PNG with a **baked navy-gradient square background**) as a bare 120² square. The founder wants the square gone around the crab.

## The key fact
The navy square is **baked into the `LaunchLogo` image itself**, not a layout container. So you cannot remove it by changing constraints — you must change which asset the storyboard shows. Preferred, and we already have the asset:

- **Use the transparent `MascotCrab.imageset`** (extracted in fab9c37 — halo-free, no baked background) in the storyboard's `imageView`, centered on `systemBackground`. Result: crab on the plain launch background, no navy field, no hard edge. This matches the greeting card we shipped → one coherent product.
- Fallback only if the transparent asset doesn't read on the static screen: keep `LaunchLogo` but clip to a continuous-corner squircle in the storyboard. This ROUNDS the square but the navy stays — inferior, use only if the transparent crab fails the check below.

## The one constraint that matters
A static launch screen is rendered by the OS **before the app runs**, so it **cannot switch colours by light/dark at runtime** — it uses `systemBackground`, which resolves to white in Light and near-black in Dark. The crab asset must therefore read on **both** white and near-black. Verify the transparent `MascotCrab` (mint) has enough contrast on both; if it vanishes on one, add the smallest treatment that fixes it (a subtle contrast-safe container or a mint that works on both) — report what you did.

## Also confirm
- No colour flash on the launch → `SplashView` → content transition. `SplashView` uses `systemBackground`; the storyboard must stay `systemBackground` too so the handoff is seamless.
- Do not touch onboarding, the greeting, `SplashView`, or any data path.

## Verify
- Cold launch on device, **Light and Dark**: the static launch screen shows the crab with **no navy square**, readable in both themes, no flash into the splash.
- Build + suite green.

## Report (≤6 lines): transparent crab or squircle-fallback + why, the Light/Dark contrast result on the static screen, files, build/test, commit.
