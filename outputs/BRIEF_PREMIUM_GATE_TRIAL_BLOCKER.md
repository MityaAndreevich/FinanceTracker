# BRIEF (Claude Code) — Premium gate locks out active-trial users from Export/Import. Model: Sonnet + systematic-debugging.

**Priority: LAUNCH BLOCKER.** A user on the active 30-day free trial (= Premium under our HYBRID access model) is shown the paywall when using Export All, and tapping Subscribe deadlocks with StoreKit's "you already have a subscription." Result: a trialing/paying user cannot use the premium feature they're entitled to — guaranteed 1-star + broken core promise. Do NOT touch save/parser/CSV mechanics. Build green, commit, push.

## Confirmed evidence (don't re-derive)
Device repro: made transactions → started the free-trial subscription → Export All → **paywall shown** → tap Subscribe → StoreKit alert **"already subscribed."** The "already subscribed" alert PROVES StoreKit holds an active entitlement (`Transaction.currentEntitlements` contains it). Therefore this is an **app-side gating bug**, not a StoreKit purchase failure: the premium gate is not reading/reacting to the active entitlement, or an active trial (introductory offer) is not being mapped to premium = true.

## Token discipline
Sonnet. Grep-first to find the entitlement/premium manager + the Export/Import gate. Read only those. **Targeted tests only** (below). No suite-wide runs, no UI-presentation tests.

## Investigate (report what you find)
1. How does the Export/Import gate decide "premium"? Which property/manager (e.g. `isPremium`, `PremiumManager`, an `@AppStorage` flag, a specific product check)?
2. How is entitlement computed? Does the manager read **`Transaction.currentEntitlements`** on launch AND listen to **`Transaction.updates`**? Is the result refreshed after a purchase/trial start without an app relaunch?
3. Is an **active trial / introductory-offer period** treated as premium? A common bug: the gate checks for a *paid* state or a specific product and excludes the trial, even though StoreKit reports the entitlement.
4. Does the gate require a specific product (e.g. lifetime, or a single tier) instead of **any** active entitlement (monthly OR yearly-in-trial OR yearly-paid OR lifetime non-consumable)?

## Fix
- **Premium = ANY active entitlement:** any non-revoked `Transaction.currentEntitlements` — auto-renewable in trial or paid, OR the lifetime non-consumable. An active trial MUST unlock premium.
- **Refresh reactively:** compute entitlement from `currentEntitlements` at launch and update live via a `Transaction.updates` listener, so unlocking happens immediately after the trial/purchase starts (no relaunch needed).
- **Paywall must not appear for an already-entitled user.** The Export/Import action should proceed directly when premium.
- **Kill the deadlock:** if the user somehow reaches the paywall while already entitled, the purchase path must recognize the existing entitlement (unlock / dismiss / offer "Manage Subscription") rather than dead-ending on "already subscribed."

## Tests (targeted only)
- Entitlement mapping: a StoreKit `.storekit` test transaction in **trial** → premium == true → Export/Import ungated.
- Paid (post-trial renewal) → premium == true. Lifetime non-consumable → premium == true. No entitlement → gated (paywall shows).
- If feasible in the StoreKit test harness: after starting a trial, the gate flips to unlocked without relaunch (updates listener).

## Verify + report
- Report the exact root cause (which flag/check was wrong).
- **Environment note:** verify in the local `.storekit` config AND flag that final confirmation must be in **Sandbox** (real sandbox Apple ID, StoreKit config OFF) — the local test env can misreport trial/entitlement state.
- Files changed, build status, commit hash, test output. Target: v1.0 (blocker — before the final clean-reinstall QA pass).
