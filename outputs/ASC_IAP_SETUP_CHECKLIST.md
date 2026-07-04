# App Store Connect — IAP Setup Checklist (Guided Walkthrough) — PATH A

**App:** Budget Crab Money Tracker · Bundle `com.dmitrylogachev.budgetcrab`
**Date:** 2026-07-02 · **Pricing:** ⚠️ **PATH A (LOCKED 2026-07-02, reversed from Path B)** · **Positioning:** Quiet Premium + billing transparency
**Every value below traces to memory/decisions — nothing improvised. Drafted text flagged 🟡.**

> **What changed vs the old Path B checklist:** prices reverted to **$4.99 / $34.99 / $99.99** (was $3.99/$29.99/$79.99). Reason: two research rounds + 7× LTV + real review data (price-rage is about dark patterns, not level). Full rationale: `outputs/RESEARCH_SYNTHESIS_2026-07-02.md` + memory `budget_crab_decision`.
> **Per-territory:** the old Path B per-market table was research-backed at a $3.99 base — it does NOT apply to Path A. We use **Apple's auto-generated price tiers** from the US base (charm-priced by Apple). A Path A per-market research pass is optional (see §6).

Sources: `budget_crab_decision` (Path A reversal, Family Sharing), `RESEARCH_SYNTHESIS_2026-07-02` (why), `BRIEF_26A_v4` + `*.lproj/Localizable.strings` (plan-name localizations, code-verified).

---

## 0. Pre-flight — verify/fix Monthly (5 min)

Path: **App Store Connect → Apps → Budget Crab → Monetization → Subscriptions → Budget Crab Premium group → `bc_premium_monthly`**

- [ ] Set base price = **$4.99** (USD, Level for $4.99). ⚠️ If it was set to $3.99 (Path B) earlier — **change it to $4.99 now.**
- [ ] Price → Edit → $4.99 base → let per-territory auto-populate (Apple auto-map).
- [ ] Status should be **Ready to Submit** (or needs a localization — see §2f pattern).

---

## 1. Scope

| IAP | Product ID | Type | Where in ASC | Base (USD) | Family Sharing | Trial |
|---|---|---|---|---|---|---|
| Monthly | `bc_premium_monthly` | Auto-Renewable | Subscriptions (Premium group) | **$4.99** | OFF | — |
| **Yearly** | `bc_premium_annual` | Auto-Renewable | Subscriptions (Premium group) | **$34.99** | OFF | **7-day free** |
| **Lifetime** | `bc_premium_lifetime` | **Non-Consumable** | **In-App Purchases** (NOT Subscriptions) | **$99.99** | **ON** | — |

Savings math (for copy): $4.99×12 = $59.88 vs $34.99 → **Save 42%** · yearly = **$2.92/month billed annually**.

---

## 2. YEARLY — `bc_premium_annual` (Subscriptions)

Path: **Monetization → Subscriptions → Budget Crab Premium group → `bc_premium_annual`**
(If missing: **＋** → Reference Name `Budget Crab Premium Yearly` → Product ID `bc_premium_annual` → Duration **1 Year**.)

### 2a. Duration
- [ ] Subscription Duration: **1 Year**

### 2b. Base price + per-territory
- [ ] **Subscription Prices → Add Price** → United States → **$34.99** (Level for $34.99) → Next.
- [ ] Accept Apple's **auto-generated per-territory table** (charm-priced tiers). Do NOT hand-edit rows — no Path A research override exists (see §6 for optional pass).
- [ ] **Russia: leave OFF / excluded** (App Store payment restrictions post-2022).

### 2c. 7-day Introductory Offer ⚠️ CRITICAL (review-reject risk if missing)
App paywall promises "7-day free trial" (`paywall.plan.yearly.subtitle`, `paywall.trial.disclosure`) — must exist in ASC.
Path: `bc_premium_annual` → **Introductory Offers → Create**.
- [ ] Countries: All eligible (same as base; Russia excluded).
- [ ] Start: immediately / no start date. End: None (ongoing).
- [ ] **Type: Free** · **Duration: 1 week (7 days)** → Save.

### 2d. Family Sharing
- [ ] **OFF** for Yearly (Family Sharing is a Lifetime/Founder perk).

### 2e. Localization (Display Name + Description) — all 5
⚠️ **Description max = 45 chars for subscriptions** (Apple limit). Keep it short. Display Name = code-backed plan name. Group display name: **Budget Crab Premium**.

| Locale | Display Name | Description (≤45) |
|---|---|---|
| EN | Yearly | Save 42% · 7-day free trial |
| RU | Годовой | Экономия 42% · 7 дней бесплатно |
| es-MX | Anual | Ahorra 42% · 7 días gratis |
| pt-BR | Anual | Economize 42% · 7 dias grátis |
| uk | Річний | Економія 42% · 7 днів безкоштовно |

*(These match what's already entered in ASC per 2026-07-02 screenshots.)*

- [ ] Add each localization → Review Information (paywall screenshot + notes if prompted) → Status **Ready to Submit**.

---

## 3. LIFETIME — `bc_premium_lifetime` (In-App Purchases, NOT Subscriptions)

⚠️ Create under **Monetization → In-App Purchases** → Type **Non-Consumable** → Reference Name `Budget Crab Lifetime` → Product ID `bc_premium_lifetime`.

### 3a. Base price + per-territory
- [ ] **Price Schedule → United States → $99.99** (Level for $99.99) → accept Apple auto-map table.
- [ ] **Russia: excluded.**

### 3b. Family Sharing
- [ ] **ON** for Lifetime (Founder's Edition perk).

### 3c. Localization — all 5
⚠️ **Description max = 55 chars for non-consumables** (Apple limit, verified in ASC dialog). Keep short.

| Locale | Display Name | Description (≤55) |
|---|---|---|
| EN | Lifetime | Founder's Edition. Pay once, yours forever. |
| RU | Навсегда | Founder's Edition. Разовый платёж, навсегда. |
| es-MX | De por vida | Founder's Edition. Pago único, para siempre. |
| pt-BR | Vitalício | Founder's Edition. Pagamento único, para sempre. |
| uk | Назавжди | Founder's Edition. Разовий платіж, назавжди. |

*(Alt EN emphasizing the wedge, 45 chars: "Pay once, yours forever. No ads, no tracking." — if used, apply across all 5.)*

- [ ] Add each localization → Review Information → Status **Ready to Submit**.

---

## 4. Post-setup verification
- [ ] All 3 IAPs **Ready to Submit**, none "Missing Metadata".
- [ ] Base prices read **$4.99 / $34.99 / $99.99** (NOT the old $3.99/$29.99/$79.99).
- [ ] Yearly has **7-day Free intro offer** live, all eligible territories.
- [ ] Family Sharing: OFF Monthly+Yearly, ON Lifetime.
- [ ] Russia excluded on all three.
- [ ] IAPs attached to the app version being submitted (version's "In-App Purchases and Subscriptions" section).

## 5. ⚠️ Blocker — code must match ASC before submit
The in-app paywall was synced to **Path B** last session ($29.99 / Save 37% / $2.50-mo). It now **contradicts** Path A. **Do Step 2 (Claude Code price-revert brief `BRIEF_PATHA_PRICE_REVERT.md`) before submission** or the store and the app disagree = review risk + user confusion.

## 6. Optional later — Path A per-territory research pass
The old research-backed per-market table was for $3.99. To tune Path A per market by purchasing power (instead of Apple auto-map), run pricing playbook 02 / NotebookLM `0e5f6bb9` at a $4.99 base. Not required for launch — Apple auto-map is fine to ship.

## 7. Roadmap post-IAP (unchanged)
Xcode Archive → TestFlight → real-device test (redeem, voice ×5, StoreKit purchase, 7-day trial appearance) → Sprint C polish → external TestFlight soak → submit → review → LIVE.
