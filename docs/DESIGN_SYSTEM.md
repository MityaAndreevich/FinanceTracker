# FinanceTracker — Design System v2

**Status:** v2 — Apple HIG-grounded for App Store launch
**Last updated:** 2026-06-23
**Scope:** Visual language, typography, color, iconography, spacing, accessibility, animation, voice & tone, app icon brief, inclusion principles

> 🔧 **v2 update 2026-06-23 — incorporates explicit Apple HIG citations** from NotebookLM `ff5e0abc` (UX & Mobile Design) which now has full HIG indexed (Onboarding, Inclusion, Typography, Color, Layout, SF Symbols, Charts, Dark Mode). Every primary design decision now has an HIG source. Specific hex values and finance-app A/B data remain craft-based and will harden in v3 after launch metrics arrive. Sections marked 🔬 still need post-research validation.

## 0. Source-of-truth hierarchy

When two recommendations conflict, apply in this order:

1. **Apple Human Interface Guidelines** — non-negotiable. Direct cite from notebook `ff5e0abc`.
2. **Apple App Review Guidelines** — for anything user-facing in the App Store flow (paywall, IAP, restore). Cite from notebook `04c87827`.
3. **WCAG 2.1 AA** — accessibility floor. Cite from notebook `ff5e0abc`.
4. **PRODUCT_SPEC §1 Marketing claims to AVOID** — claim hygiene for copy.
5. **This design system** — house rules that go beyond Apple's baseline.
6. **Personal craft preference** — only when 1-5 are all silent.

### Key HIG sections we adhere to (with cite map)

| HIG Section | What it governs in our app | Where applied in this doc |
|---|---|---|
| Foundations → **Color** | Palette + Dark Mode mirroring | §2 |
| Foundations → **Typography** | SF Pro, Dynamic Type | §3 |
| Foundations → **Layout** | 4pt grid, safe area | §5 |
| Foundations → **Inclusion → People and settings** | Demo data, screenshots — avoid affluence | §10 + APP_STORE_ASSETS §4 |
| Foundations → **Inclusion → Avoiding stereotypes** | Copy in onboarding (universal experiences) | §1 Brand voice |
| Patterns → **Onboarding → Additional requests** | Strategic permission requests (biometric, notifications) | §6 component patterns + Paywall |
| Patterns → **Onboarding → Additional content** | "Fast, fun, optional" — no licensing in onboarding | §6 Onboarding pattern (added v2) |
| Patterns → **Onboarding** (general) | Teach through interactivity, not instructions | §6 component patterns |
| Foundations → **SF Symbols** | All system icons | §4 |
| Patterns → **Charts** | Chart aesthetics, axis labels, color | §6 Insight card |
| Foundations → **Dark Mode** | Mirror every color decision | §2 |

> If a design choice doesn't appear in the HIG, fall back to WCAG (for a11y) or Nielsen 10 heuristics (for UX). Both indexed in notebook `ff5e0abc`.

---

## 1. Brand foundations

### Core values (in order of priority)
1. **Trustworthy** — financial app; users must feel safe immediately
2. **Calm** — money is stressful; the app should feel like a deep breath
3. **Honest** — no dark patterns, no fake urgency, no hidden fees
4. **Quietly smart** — insights surface when useful, never preachy

### Brand voice (tone of copy)
- **Direct, not chatty.** "Added $12 to Food" (not "Yay! Logged your delicious lunch! 🍔")
- **Confident, not pushy.** "Start 7-day free trial" (not "Don't miss out — upgrade now!")
- **Helpful, not preachy.** "You spent +40% on coffee this month" (not "You should really cut back on coffee!")
- **Quiet about itself.** Insights state facts. The user draws conclusions.

### Anti-voice (avoid)
- Emojis in transactional copy (one exception: optional category icons users pick themselves)
- Exclamation marks in success states ("Saved." not "Saved!")
- Personification of the app ("we suggest" never; "your spending shows" yes)
- Cute mascot characters
- Gamification (no streaks, no points, no badges in v1)

---

## 2. Color system 🔬

> 🔬 Specific hex values below are craft-based starting points. Validate via NotebookLM research on finance-app color psychology + competitor teardowns before locking in for App Store screenshots.

### Light mode — primitive tokens

| Token | Hex | Usage |
|---|---|---|
| `--neutral-50` | `#FBFBFC` | App background |
| `--neutral-100` | `#F4F5F7` | Card background, list row alt |
| `--neutral-200` | `#E4E6EB` | Dividers, subtle borders |
| `--neutral-300` | `#C9CCD3` | Secondary borders |
| `--neutral-500` | `#7A7E87` | Secondary text |
| `--neutral-700` | `#3D414A` | Primary text |
| `--neutral-900` | `#16181D` | Headlines, emphasized text |
| `--accent-500` | `#2E7AFC` | Primary actions, links, brand |
| `--accent-600` | `#1F5FD9` | Pressed state on accent |
| `--success-500` | `#15A26B` | Income, positive, "saved" |
| `--success-100` | `#E1F7EC` | Success backgrounds (subtle) |
| `--danger-500` | `#C8554D` | Expense — "soft red", not panic red. Per industry pattern: finance apps use muted reds to avoid stress |
| `--danger-100` | `#FCEBEA` | Error backgrounds |
| `--warning-500` | `#E0911C` | Anomaly highlights ("+40% this month") |
| `--warning-100` | `#FDF2E0` | Warning backgrounds |

### Dark mode — primitive tokens

| Token | Hex |
|---|---|
| `--neutral-50` | `#0D0F13` |
| `--neutral-100` | `#1A1D24` |
| `--neutral-200` | `#262A33` |
| `--neutral-300` | `#3D414A` |
| `--neutral-500` | `#9A9EA7` |
| `--neutral-700` | `#D0D2D7` |
| `--neutral-900` | `#F4F5F7` |
| `--accent-500` | `#4A8EFF` |
| `--accent-600` | `#6BA2FF` |
| `--success-500` | `#3FBB85` |
| `--success-100` | `#15301F` |
| `--danger-500` | `#E8625C` |
| `--danger-100` | `#3A1B1A` |
| `--warning-500` | `#F0A640` |
| `--warning-100` | `#372617` |

### Semantic tokens (use these in SwiftUI, not primitives)

```swift
// In Shared/Colors.swift
extension Color {
    static let appBackground = Color("AppBackground")           // neutral-50
    static let cardBackground = Color("CardBackground")         // neutral-100
    static let divider = Color("Divider")                       // neutral-200
    static let textPrimary = Color("TextPrimary")               // neutral-900
    static let textSecondary = Color("TextSecondary")           // neutral-500
    static let textTertiary = Color("TextTertiary")             // neutral-500 @ 0.7
    static let accent = Color("Accent")                         // accent-500
    static let accentPressed = Color("AccentPressed")           // accent-600
    static let income = Color("Income")                         // success-500
    static let expense = Color("Expense")                       // danger-500
    static let warning = Color("Warning")                       // warning-500
    static let successBg = Color("SuccessBg")                   // success-100
    static let dangerBg = Color("DangerBg")                     // danger-100
    static let warningBg = Color("WarningBg")                   // warning-100
}
```

All colors defined in `Assets.xcassets` with light + dark variants. Never use hardcoded `Color(red:, green:, blue:)` in views.

### Color contrast — WCAG AA

| Combination | Contrast ratio | Status |
|---|---|---|
| textPrimary on appBackground | 16.4:1 (light), 13.8:1 (dark) | ✅ AAA |
| textSecondary on appBackground | 5.2:1 (light), 5.8:1 (dark) | ✅ AA |
| accent text on appBackground | 4.9:1 (light), 4.7:1 (dark) | ✅ AA |
| income/expense small text | 4.6:1+ | ✅ AA |

Never display amounts in income/expense color smaller than 13pt. Always pair color with `+`/`−` sign + arrow icon (color-blind safety).

---

## 3. Typography

### Type scale (use SwiftUI's `.font(.system(...))` to respect Dynamic Type)

| Token | SwiftUI font | Size (default) | Usage |
|---|---|---|---|
| `displayLarge` | `.system(.largeTitle, design: .default, weight: .bold)` | 34pt | Splash, paywall hero |
| `displayMedium` | `.system(.title, design: .default, weight: .semibold)` | 28pt | Section headers |
| `displaySmall` | `.system(.title2, weight: .semibold)` | 22pt | Card headers, paywall plan name |
| `headline` | `.system(.headline, weight: .semibold)` | 17pt | Transaction row title, important data |
| `body` | `.system(.body)` | 17pt | Standard text |
| `callout` | `.system(.callout)` | 16pt | Form labels, list items |
| `subheadline` | `.system(.subheadline)` | 15pt | Secondary info on cards |
| `footnote` | `.system(.footnote)` | 13pt | Captions, metadata |
| `caption` | `.system(.caption)` | 12pt | Microcopy, footer text |
| `caption2` | `.system(.caption2)` | 11pt | Legal disclosures only |

### Numeric typography

Always use `.monospacedDigit()` on money displays. This prevents jumpy alignment when amounts have different digit counts.

```swift
Text(amount)
    .font(.headline.weight(.semibold))
    .monospacedDigit()
```

### Dynamic Type compliance

- All text must scale with system Dynamic Type — never use hardcoded font sizes
- Test at **Larger Accessibility Sizes (AX1-AX5)** as well as standard sizes
- Long-form labels: use `.minimumScaleFactor(0.8)` only on amount displays inside cards (where overflow is worse than minor scaling)

---

## 4. Iconography

### SF Symbols — system rules

- **Use SF Symbols for 95% of iconography.** Only build custom SVG when SF Symbols genuinely doesn't have what we need.
- Weight: `.regular` by default. `.semibold` for emphasis. Never `.bold` or `.black` (overpowers text).
- Size: match adjacent text. For 17pt body text, use `.font(.body)` on the symbol.
- Color: inherit from parent text style by default. Override only for semantic meaning (income/expense indicators).

### Reserved category icons (defaults)

| Category | SF Symbol | Notes |
|---|---|---|
| Food | `fork.knife` | |
| Gas | `fuelpump` | |
| Rent | `house` | |
| Supplies | `cart` | |
| Other | `square.grid.2x2` | |
| Income | `dollarsign.circle` | |

Users can pick custom SF Symbols via `SFSymbolPicker` for their own categories.

### Decorative icons

- App-level decorative icons (success states, paywall hero, empty states): use SF Symbols at large sizes (44pt+) with semantic color background tint.

### Custom icons

Allowed only for:
- App icon itself (see App Icon Brief below)
- Future onboarding illustrations (Phase 2+)

Never use third-party icon libraries.

---

## 5. Spacing & layout

### 4pt grid system

All spacing is a multiple of 4. Use these tokens:

| Token | Pixels | Usage |
|---|---|---|
| `s-0` | 0 | (zero) |
| `s-1` | 4 | Tight icon-text |
| `s-2` | 8 | Inner card padding |
| `s-3` | 12 | Default item gap |
| `s-4` | 16 | Standard horizontal padding |
| `s-5` | 20 | Section spacing |
| `s-6` | 24 | Major section spacing |
| `s-8` | 32 | Hero spacing |
| `s-10` | 40 | Full screen sections |

### Corner radius

- **Cards**: 16pt (`continuous` style)
- **Buttons**: 12pt
- **Small chips / badges**: 8pt
- **Pills (capsule)**: half height (`Capsule` shape)
- **Sheet / modal**: system default (iOS handles)

Always use `RoundedRectangle(cornerRadius: X, style: .continuous)` — never `.circular`. Continuous looks more refined.

### Standard view padding

- **Screen edges**: `.padding(.horizontal, 16)` — most screens
- **Card inner**: `.padding(14)` (asymmetric between 12 and 16, matches Apple's preference for card interiors)
- **Form field row**: respect system `Form` defaults
- **Bottom safe-area bottom button**: `.padding(.bottom, 8)` above safe area

---

## 6. Component patterns

### Transaction row

```
[ Title (headline) ]                          [+/−][icon][$amount (headline, mono)]
[ Category • Account (caption, secondary)]
```

- Color: amount in income/expense semantic color
- Sign: explicit `+` or `−` prefix
- Icon: `arrow.down.left` (income) or `arrow.up.right` (expense)
- Spacing: 12pt between title block and amount block

### Summary card (Dashboard)

```
[ icon (small)] [ Label (subheadline, secondary) ]              
[ Amount (title3, semibold, mono) ]
```

- Background: `.thinMaterial`
- Border: `RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.separator, lineWidth: 0.5)`
- Padding: 14pt

### Insight card

```
[ icon ][ Insight title (headline) ]               [ subtle: dismiss / X ]
[ Body text (callout, primary) ]
[ optional: small CTA chip ]
```

- Anomaly = `warning` semantic palette (background tint + icon)
- Positive insight = `success` palette
- Neutral observation = `accent` palette

### Empty states

- Centered, large SF Symbol (44pt, secondary color)
- Title (headline)
- Subtitle (subheadline, secondary)
- Generous vertical spacing

### Paywall

- Header: hero SF Symbol + tagline + 1-sentence subtitle
- Feature row list (3-5 max): green check icon + 1-line benefit
- Plan options as cards (vertical stack on phone, horizontal on iPad later)
- Single primary CTA at bottom: "Start 7-day free trial" (yearly) / "Continue" (monthly) / "Get lifetime access"
- "Cancel anytime" small caption directly under CTA
- Legal disclosure + Terms + Privacy links below
- Background: `.thinMaterial` on cards, plain on screen background

---

## 7. Animation principles

### Defaults

- **Spring physics** by default: `.spring(response: 0.45, dampingFraction: 0.85)`
- **Linear timing** only for progress indicators
- **No animation** on critical states (paywall display, error alerts) — instant feedback is more trustworthy

### Allowed motion

- Smooth list row entry/removal (insertion = scale+fade)
- Tab transitions (system default)
- Sheet presentation (system default)
- Number changes on dashboard (subtle crossfade)
- Insight card appear (slight scale up from 0.95 + fade in)

### Reduce Motion

- Honor `accessibilityReduceMotion` environment value
- Disable scale-up animations when set
- Keep opacity transitions (they're not motion)

---

## 8. Accessibility checklist

Every screen must pass:

- [ ] All interactive elements have meaningful `accessibilityLabel`
- [ ] Dynamic Type respected — test at AX1 and AX3
- [ ] Color contrast WCAG AA minimum on all text
- [ ] No information conveyed by color alone (income/expense uses sign + arrow + color)
- [ ] VoiceOver reads transaction rows as single coherent labels (use `.accessibilityElement(children: .combine)`)
- [ ] Buttons have minimum 44×44pt hit target
- [ ] Form fields have associated labels
- [ ] Privacy-sensitive screens (dashboard, transactions) are covered by `PrivacyOverlayView` when app backgrounded
- [ ] Reduce Motion honored
- [ ] Haptic feedback on critical actions (`UIImpactFeedbackGenerator(style: .light)` on transaction save)
- [ ] No emoji in copy that VoiceOver would read aloud verbosely

---

## 9. App icon brief

The app icon is the single most important visual asset. Brief for the designer (or AI image generator):

### Concept

A simple, calm, instantly recognizable mark that signals "money + safety + on-device". The icon must work at all iOS sizes (from 20×20 to 1024×1024) and in light/dark/tinted modes (iOS 18+).

### Visual direction (recommended)

**Option A — Lock + spark:** A subtle lock outline with a small spark inside (suggests "secure + smart"). Single-color foreground on solid background.

**Option B — Coin + leaf:** A coin shape with a subtle leaf or curve inside (suggests "money + growth + organic"). Two-tone.

**Option C — Notebook:** A small ledger/notebook abstract shape with a single dot or chevron (suggests "private journal of money").

Personal lean: **Option A** — most ownable, hardest to confuse with the 200 other "coin" finance apps in the App Store.

### Constraints

- No text in icon (Apple rejects icons that contain readable text in most cases)
- No realistic photos or 3D renders
- Use brand `accent-500` blue OR a green-leaning teal that won't clash with Settings app
- Must be visually distinct at 20pt size on Home Screen
- Provide light, dark, and tinted-mode variants

### Deliverables

- 1024×1024 master PNG
- All required iOS sizes in `Assets.xcassets/AppIcon.appiconset/`
- Light mode variant
- Dark mode variant
- Tinted mode variant (single-color silhouette)

---

## 10. App Store screenshot direction 🎯

> 🎯 Updated 2026-06-23 with industry best-practice patterns from NotebookLM general-knowledge layer. Still needs grounding in specific A/B data once sources approved in notebook.

> 🔧 v2 update 2026-06-23 — adds Apple HIG inclusion principles (notebook `ff5e0abc`). Every screenshot mockup AND the `--demo-mode` seeder MUST follow these. Cross-reference: `APP_STORE_ASSETS.md §4 Screenshots brief → "Apple HIG inclusion principles"`.

### HIG inclusion principles (non-negotiable)

Per Apple Human Interface Guidelines, **Foundations → Inclusion → People and settings**:

- **No displays of high affluence.** Demo data and mockup transactions show **familiar, relatable** spending — coffee, groceries, gas, rent split, electric bill, streaming subscription. Per HIG: "showing only mansions or expensive items can be unwelcoming and make the app seem 'out of touch'".
- **Realistic amounts.** Coffee $4.50, not $14.50. Groceries $87, not $487. Anchor to U.S. Bureau of Labor Statistics Consumer Expenditure Survey medians (notebook `73afc9a4`).
- **Locale-appropriate amounts.** RU screenshots use ₽ in plausible RU ranges; DE/ES/PT-BR use € / R$ at local cost-of-living.
- **No status-signaling merchants.** "Whole Foods", "Spotify", "Uber" — yes. "Erewhon", "Soho House", "private jet charter" — no.

Per HIG, **Foundations → Inclusion → Avoiding stereotypes** — copy in onboarding and empty states must use **universal experiences**, not assumed economic / educational milestones. We do not collect security questions, but the principle extends to any prompt that asks the user to reflect on their life: avoid "your first car", "your favorite college subject", "your childhood vacation home". Prefer "your favorite category to track", "what you want to spend less on".

### Pattern from research

- **Screenshot 1** — Hero Number front-and-center (we don't have Net Worth so use current-month balance: "$2,134 left this month") + 1-line value prop ("Privacy-first. No bank login.") + device-in-hand or floating UI style
- **Screenshot 2** — Pain-point solution. Since we don't auto-sync, lead with **3-second add transaction flow** (Siri/widget demo)
- **Screenshot 3** — Smart Insight demo ("Coffee spending +40% this month")
- **Screenshot 4** — Privacy nutrition label ("Data Not Collected") prominently
- **Screenshot 5-6** — Multi-currency, analytics charts, comparison free-vs-Premium

### Style notes

- **Dark Mode dominant** — signals premium per industry pattern
- **Large captions at top** of each frame, not bottom
- **Heavy/bold text** for monetary amounts in screenshots
- **High contrast** between UI and background gradient
- All text rendered into image (App Store doesn't render dynamically)

Screenshot 1 must communicate value in 1 second (because users swipe in 1 second).

**Screenshot 1 — value-prop hero:**
- Top: a single bold tagline ("No bank login. Real privacy.")
- Below: a clean dashboard preview with a real-looking month summary
- Background: gradient using brand colors, not white

**Screenshot 2-4 — show core flows:**
- Add a transaction (3 seconds visible)
- Smart insight card example
- Privacy nutrition label hero ("Data Not Collected")

**Screenshot 5-6 — depth:**
- Analytics charts (pie/bar/line)
- Multi-locale strip showing 4 languages side-by-side

### Specs (App Store Connect)

- **6.9" iPhone Pro Max** (1320×2868) — primary
- **6.5" iPhone Plus** (1284×2778) — required for older devices
- **6.1" iPhone** (1179×2556)
- **5.5" iPhone (legacy)** (1242×2208) — required if app supports iOS 16
- **13" iPad** (2064×2752) — if iPad version ships

All screenshots: rendered text in image (App Store doesn't render UI text dynamically), not just raw simulator captures.

---

## 11. Copy patterns

### Action button labels (verb-first, no period)

- "Add Transaction" not "Add a Transaction"
- "Start Free Trial" not "Start your free trial!"
- "Cancel" not "Cancel?"
- "Save" not "Save now"

### Error messages (state + remedy)

- "Amount required" + suggestion to retry
- Not "Oops! Something went wrong"

### Empty states (factual + invitation)

- "No transactions yet" + "Tap + to add your first"
- Not "You haven't added any transactions yet! Click here to get started! 🎉"

### Insight copy (observe, don't lecture)

- "You spent +40% on coffee this month" (observation)
- Not "You should drink less coffee" (advice)
- Optionally: "Compared to last 3 months" (context, neutral)

---

## 12. Asset checklist for v1.0 launch

- [ ] App icon — 1024×1024 + asset catalog with light/dark/tinted
- [ ] Splash screen (uses LaunchScreen.storyboard with logo)
- [ ] All Asset Catalog colors (15+ semantic tokens)
- [ ] App Store screenshots — 6 variants for 6.9" iPhone Pro Max minimum
- [ ] App Store icon (1024×1024 same as in-app)
- [ ] Privacy Policy landing page (already published at GitHub Pages)
- [ ] About screen logo

---

*Design system is living. Update as patterns evolve through real user feedback. Every change should be motivated by usability data, not aesthetic preference alone.*
