# Paywall Analysis — Budget Crab

**Skill:** `paywalls` (in-app CRO)
**Date:** 2026-06-28 · **Files:** `Purchases/PaywallView.swift`, `en.lproj/Localizable.strings` (paywall block)
**Method:** Source read. Analysis only — no code changed.

> ⚠️ **Data gap:** I have no live conversion/trial-start/ARPU numbers. Per the project's data-driven rule, every quantitative claim below is flagged as a hypothesis to validate, not a fact. Where social proof is recommended, it must use *truthful* numbers or be omitted.

---

## Current state (what the paywall is)

- **Model:** Freemium. Three products, sorted Yearly → Lifetime → Monthly.
  - **Yearly** — `$34.99/yr`, 7-day free trial. Visually the hero: mint border + filled-mint CTA "Start free trial."
  - **Lifetime** — one-time, **"Founder's Edition"** + "Shareable via Family Sharing," subline *"Lock in today's price. Includes all future features. Subscription pricing may rise."* Outline CTA "Get Lifetime."
  - **Monthly** — compact row, de-emphasized, outline CTA.
- **Gated features (the "Every plan includes" list):** Unlimited transactions, Unlimited CSV import, Custom fields, Advanced filters.
- **Trust/legal:** Restore, Privacy, Terms, auto-renew disclosure — all present and **App Store compliant**. Close button top-trailing (no dark pattern). ✅
- **Headline:** "Go Premium" / "Unlock import & full export, and future power features."

---

## What's working (keep)

1. **Compliant + honest.** Auto-renew disclosure, restore, terms/privacy, visible close. No hidden dismiss, no guilt copy. Maintains trust. ✅
2. **Lifetime "Founder's Edition" copy is the strongest asset on the screen.** It stacks **identity** (founder), **scarcity/price-lock** ("lock in today's price"), **loss aversion** ("subscription pricing may rise"), and **value** ("all future features"). This is textbook good.
3. **Yearly anchored as default** via color weight, with the free trial led on the CTA ("Start free trial," not "Pay $34.99"). Correct CRO instinct.
4. **Family Sharing badge** on Lifetime — concrete added value, well placed.

---

## Gaps vs. CRO best practice (by impact)

### P0 — No "Show, don't tell." The paywall is 100% text.
The skill's #1 lever is value demonstration: preview, before/after, screenshot, or "With Premium you could…". Budget Crab's paywall is icon + title + plan cards + a checklist. The user never *sees* what they unlock. For a visual app with strong charts and a clean Dashboard, shipping a screenshot strip or a one-line outcome preview is the highest-upside change.

### P0 — Headline & feature list sell plumbing, not outcomes.
"Go Premium," "Unlock import & full export," "Custom fields," "Advanced filters" are low-emotion mechanics. The skill format is **"Unlock [feature] to [benefit]."** Reframe around outcomes the median user feels: *own your whole history, never hit a limit, peace of mind, no data selling.* "Custom fields / advanced filters" are power-user terms that likely under-resonate — demote them below the emotional benefits.

### P1 — The brand's #1 differentiator (privacy) is absent from the paywall.
The whole app leans on "Stays on your iPhone / on-device." The paywall — the one screen asking for money — never mentions it. Privacy *is* the premium trust story here; surfacing it ("Your data never leaves your device — and never will") is a free, on-brand trust signal.

### P1 — No price framing on Yearly.
No "Best value" badge, no savings vs. monthly ("Save 42%"), no per-month equivalence ("$34.99/yr ≈ $2.92/mo"). These are among the most reliable paywall CRO wins. Monthly price is shown but not *used* as an anchor.

### P1 — No social proof / trust block.
Zero ratings, count, or testimonial. Indie-appropriate, **truthful** options: App Store rating once it exists, "Join the people who own their finances," or a privacy seal. Omit entirely rather than fabricate — but the current total absence leaves conversion on the table.

### P2 — Trial mechanics aren't explained.
"Start free trial" with no "how it works" timeline (Day 0 access → Day 5 reminder → Day 7 charge, cancel anytime). A 3-step trial timeline measurably reduces trial-start anxiety and post-trial chargeback/refund complaints.

### P2 — Context of arrival is dropped.
In-app gates say "Available in Premium" (good), but the paywall headline is always the generic "Go Premium" regardless of whether the user came from Export, an import limit, etc. A contextual headline ("Export your data with Premium") converts better than a generic one.

### P3 — Lifetime CTA is visually weakest of the three.
If Lifetime is the high-margin / cash-now product for an indie, its plain outline button under-sells it. This may be a *deliberate* push toward recurring revenue — flag to confirm against actual margin/LTV data before changing.

### P3 — Another hardcoded `paywallMint`.
`Color(red:0.239,0.863,0.592)` re-declared here too (ties into the design-system token finding). Cosmetic/maintenance.

---

## TOP 5 ACTIONABLE IMPROVEMENTS

1. **Add value demonstration (P0).** Insert a compact screenshot strip or a single "before/after" outcome line above the plan cards (e.g., the Analytics chart + "See where every dollar goes"). Turn the paywall from a price list into a value preview.

2. **Rewrite headline + feature list around benefits (P0).** Headline → outcome ("Own your entire money history"). Reorder the includes list: lead with *unlimited/forever* + *privacy*, demote *custom fields/advanced filters*. Keep claims truthful and non-comparative.

3. **Put privacy on the paywall (P1).** One line tying the on-device differentiator to the purchase ("Your data stays on your iPhone — forever"). On-brand, free, high-trust.

4. **Add price framing to Yearly (P1).** "Best value" badge + savings vs. monthly + per-month equivalence. Pure copy/layout, no model change.

5. **Add a 3-step trial timeline (P2).** "Today: full access · Day 5: reminder · Day 7: $34.99, cancel anytime." Reduces trial anxiety, supports honest expectations.

---

## Validation plan (data-driven)
Before/after each change, watch: paywall impression→tap rate, trial-start rate, trial→paid, and Lifetime mix. The headline/value-preview (P0) and price-framing (P1) are the two changes most likely to move trial starts; A/B them first. Do not add social-proof numbers until real ones exist.
