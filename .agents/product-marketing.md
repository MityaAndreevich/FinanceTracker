# Product Marketing Context — Budget Crab

This file is the foundation context for all marketing skills (`aso`, `copywriting`, `paywalls`, `onboarding`, `marketing-plan`, `marketing-psychology`, `pricing`, `competitor-profiling`, `launch`). Every other skill checks this file first.

**Status:** Pre-launch v1.0. Submitted to App Store Connect July 2026.

---

## Product

**Name:** Budget Crab Money Tracker
**Display name:** Budget Crab
**Category:** Finance (primary) / Utilities (secondary)
**Platforms:** iOS 17+ (iPhone), Apple Watch via Siri (no dedicated Watch app v1.0)
**Bundle ID:** `com.dmitrylogachev.budgetcrab` (internal codename "Vela" — do not surface to users)
**Languages:** EN (P0), es-MX (P0/P1), pt-BR/DE/FR (P1), JA/zh-Hans/RU (P2)

## One-liner

Budget Crab is the private way to track your money — no banks, no cloud, no account. Your data stays on your iPhone.

## What makes Budget Crab different

1. **Architecture is the privacy promise.** Budget Crab cannot collect your financial data because there's no system to collect it. No servers. No analytics. No ad SDKs.
2. **Voice entry that never leaves the iPhone.** Apple's SFSpeechRecognizer with `requiresOnDeviceRecognition = true`. Audio never reaches a server. Availability depends on the languages your iPhone supports for on-device dictation — don't promise specific languages (e.g. Spanish) in copy; frame it as "works in the languages your iPhone supports for dictation."
3. **Smart entry without AI hype.** Quick Entry parses "$5 coffee" or "67 gas" via on-device rule-based matcher. Foundation Models NL parsing arrives v1.1.
4. **Siri + Shortcuts + Widget native.** First-class App Intents integration. Say "Hey Siri, add ten dollars groceries" and the transaction lands locally.
5. **Independent by design.** No investor pressure to monetize data. No bank sync ever forced in for growth metrics.

## Target user

**Primary segment (60% of expected installs):**
- Age 25-45
- Income $40K-$150K USD
- Owns iPhone 3+ years (values native polish, upgrades device)
- Has tried Mint/YNAB/Copilot и felt the friction of bank connections, accounts, or cloud sync
- Concerned about a data breach exposing financial life
- US, EU, LATAM (especially Mexico, Brazil)

**Secondary segment (30%):**
- Privacy-conscious tech professionals (developers, designers, journalists, security researchers)
- Reads Hacker News, follows DuckDuckGo / Signal / Proton
- Will pay premium for verifiable privacy
- Often dual-uses с Obsidian, 1Password, Bear

**Tertiary segment (10%):**
- Crypto-adjacent users wanting "personal balance sheet" without exchanges/wallets
- International workers managing multiple currencies on single device

## Positioning statement (DuckDuckGo template)

For privacy-conscious people who want clarity about their money without bank-linking risk, Budget Crab is the personal finance tracker that lives entirely on your iPhone. Unlike YNAB, Copilot, or Monarch — which require account sync — Budget Crab works without uploading anything, ever.

The architecture is the privacy promise — not a policy, not a pledge.

## Pricing

| Tier | Price | Trial | Notes |
|---|---|---|---|
| Free | — | — | Up to 10 transactions per month |
| Monthly | $4.99/mo | None | |
| Yearly | $34.99/yr | 14-day free trial | "Save 42%" framing |
| Lifetime | $99.99 one-time | n/a | Non-consumable, secondary option (not main default) |

Regional pricing: 40-50% of US prices в LATAM (set via Apple price points).

## Brand archetype + voice

**Archetype:** Caregiver (protective shell metaphor) + Jester (mascot warmth) **executed as** Sage+Ruler in copy. The crab does warmth visually; copy stays calm-confident expert.

**Voice characteristics (5):**
1. **Calm, confident, precise** — say more with less
2. **Warm but never folksy; expert but never cold** — peer-to-peer tone with smart user
3. **Lead with outcome, then mechanism** — "See where your money goes" before "stored only on your device"
4. **Show, don't tell, on privacy** — never say "we care about your privacy" — design + architecture do the work
5. **Premium but human** — think private banking aesthetic with independent founder warmth

**Vocabulary to use:**
- on-device, locally, your iPhone, stays on your phone
- private, deliberate, calm, clear
- track, see, understand
- "designed for", "made for", "independently built"

**Vocabulary to avoid (anti-patterns confirmed by 5-source research):**
- Buzzwords: streamline, seamless, powerful, smart (avoid "AI" noun until v1.1 Foundation Models)
- Exclamation points
- "We care about your privacy" / "Your privacy matters to us" — passive virtue-signaling
- "Made with love" / "One guy built this" — sympathy appeals undermine premium pricing
- "Support my indie journey" / "Pay lifetime to support development" — emotional pressure
- "We're a solo team" — use "Built independently" instead
- Bank/fintech language: account, institution, sync, connect, link
- Anything implying cloud: backup, sync, restore from cloud
- "Free forever" / "Unlimited free" — we're metered at 10 tx
- "End-to-end encrypted" / "Bank-grade security" / "Data Not Collected" (last ONLY after ASC confirms label)
- "Budget Crab Inc" / "Budget Crab Financial Services" — faux corporate forbidden

**Channel-specific positioning (CRITICAL — research-validated):**

| Surface | Voice | Example |
|---|---|---|
| App Store description | SILENT on team | "Budget Crab is the private way to track..." |
| App Store subtitle | SILENT on team | "Private expense tracking" |
| Paywall | SILENT on team | "Unlock private money tracking" + trust line: "Built independently. No ads. No data business." |
| About / Support | Founder VISIBLE as feature | "Budget Crab is built independently by Dmitry. I read every support email myself." |
| Reviewer Notes | "I" + architecture first | "I built Budget Crab independently. The architecture means I literally cannot see your data — there are no servers." |
| Press kit | "Independent developer" | Factual for journalists |
| Product Hunt / HN / IH | LOUD INDIE (first-person founder) | "I built Budget Crab because I couldn't find a finance app that didn't sync to a bank..." |
| App Store reviews response | First-person personal | "Thanks — really appreciate it. — Dmitry" |

**Architecture-first claim (DuckDuckGo template):**
> "Your data can't reach us — there's no server to receive it."

Describe what CAN'T happen, not what we promise. Architecture > biography for privacy claims.

**Taglines (A/B test post-launch):**
1. **"Your money. Protected sideways."** (primary — crab metaphor reinforces brand)
2. "Track money. Stay private." (subtitle candidate)
3. "Independent by design. Private by default." (about/marketing)

## Competitive landscape

| Competitor | Price | Privacy stance | Vulnerability we exploit |
|---|---|---|---|
| YNAB | $14.99/mo | Bank sync via Plaid | Plaid breach paranoia + price ($180/yr vs $34.99) |
| Copilot Money | $13/mo | AI on Apple Silicon, bank sync | "AI" hype fatigue + bank sync structural privacy gap |
| Monarch | $14.99/mo | Bank sync, household focus | Singles + privacy users not served |
| Rocket Money | $4-12/mo | Aggressive negotiation, bank sync | Privacy + simplicity demand |
| Bobby | $1.99/mo | Subscription tracker only | Limited scope — Budget Crab is full tracker |
| Spendee | $1.99/mo | Manual + optional sync | Outdated UX, no voice, no Siri |
| Mint | Discontinued | — | Refugee market — мы serve them |

**Our wedge:** "All the convenience of voice + smart categorization, none of the cloud risk. iOS-native, independently built, premium-priced."

**Never mention by name** в App Store copy. Comparison works implicitly in any user who tried bank-sync apps.

## Anti-claims (forbidden in any user-facing copy)

Per legal/compliance + App Review safety + 5-source positioning research:
- End-to-end encrypted
- Bank-grade security
- Zero data collection (use "Data Not Collected" ONLY after ASC label confirms)
- AI-powered (until v1.1 actually ships Foundation Models)
- Unlimited free transactions (free tier IS metered at 10)
- We never see your data ("We don't collect, store, or transmit" instead)
- Auto-categorizes everything perfectly (it's pattern-based, has failures)

## Distribution channels (planned)

**Pre-launch (now):**
- ASA $50-100 launch-day burst on brand + 2-3 long-tail keywords
- Apple Editorial Featuring nomination submitted at ASC submission time

**Launch + 7 days:**
- Personal Twitter/LinkedIn announcement (LOUD INDIE voice OK here — right audience)
- Indie Hackers post (LOUD INDIE)
- Submit to AlternativeTo (Mint alternatives section)

**Launch + 7-21 days:**
- Product Hunt Tuesday morning launch (LOUD INDIE founder voice)
- Reddit r/personalfinance soft post (only if rated 4.0+)
- Hacker News "Show HN" (if Product Hunt traction)

**Post-launch ongoing:**
- ASO iteration based on first 30 days data
- Custom Product Pages — build 2-3 after baseline CVR established (P2 per LAUNCH_READINESS_GAPS_v2)
- 6-week mark: v1.1 release with Foundation Models = second marketing moment

## North Star metrics

- **Day 30: Trial-to-paid conversion ≥ 25%** (industry baseline; stretch 40%+ for privacy-premium segment)
- **Day 180: $10K MRR** (per skill-validated pricing math + LATAM expansion)
- **Day 90: Apple App Store rating ≥ 4.5** (required for most Editorial Featuring)

## Marketing assets needed

| Asset | Owner | Status |
|---|---|---|
| App icon 1024×1024 (Budget Crab Mint Primary) | Designer | ✅ Delivered |
| 6 App Store screenshots с captions | Brief 26B (Figma + simctl) | Pending capture |
| App Preview video 15-30s | Brief 27 | Pending recording |
| App Store description EN | Brief 26A v3 | ✅ Drafted (Budget Crab + Quiet Premium copy) |
| App Store description es-MX | Brief 26A v3 | ✅ Drafted |
| Editorial Featuring pitch (1-page) | Brief 26C | Pending |
| Privacy Policy page | dmitrylogachev.github.io/BudgetCrab/PRIVACY_POLICY.html | URL slug update needed |
| Support page | dmitrylogachev.github.io/BudgetCrab/support.html | URL slug update needed |
| Launch landing page | budgetcrab.app (recommended domain) | Optional, P2 |

## Skills cross-reference

When other marketing skills run, they pull from this file:
- `aso` → title/subtitle/keywords above
- `copywriting` → voice characteristics + vocabulary + channel rules above
- `paywalls` → pricing section + Quiet Premium copy guidance
- `onboarding` → target user + brand voice
- `marketing-psychology` → Caregiver+Jester archetype + DuckDuckGo positioning template
- `pricing` → pricing tier table above
- `competitor-profiling` → competitive landscape section
- `launch` → distribution channels + North Star metrics
- `marketing-plan` → all sections above
- `marketing-ideas` → "Our wedge" + anti-claims (negative space)

---

## Document changelog

- **2026-06-25 (initial Tuvra version):** Created post-Tuvra-decision. Later superseded.
- **2026-06-25 (Budget Crab final):** Rewritten after 5-source positioning research consensus on Quiet Premium + Visible Indie Layer (Option B+). Budget Crab brand finalized. Pricing $4.99/$34.99/$99.99 with 14-day trial. Channel-specific positioning rules locked. Architecture-first DuckDuckGo template adopted. All anti-claims documented.
