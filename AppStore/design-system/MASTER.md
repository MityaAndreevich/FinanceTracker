# Budget Crab — Design System (Quiet Premium)

> Source of truth for visual tokens. Generated 2026-06-28 during the overnight
> design polish. The `ui-ux-pro-max` generic generator suggested a handwritten
> Caveat / navy-gold "Liquid Glass" kit — **rejected**: handwritten fonts and
> chromatic glass are wrong for a money app where trust + daylight legibility
> win. This is the tailored Quiet Premium direction the brief specified.

## Personality

Private. Offline. Calm. A $99 lifetime tool, not a $0.99 utility. Restraint over
decoration: generous whitespace, one confident accent, soft elevation, no neon.

## Color

Implemented in `FinanceTracker/Shared/Color+Semantic.swift`.

| Role | Token | Light | Dark |
|------|-------|-------|------|
| Brand accent | `Color.brand` / `.accentColor` | mint `#3DDC97` | same |
| Background | system | warm `systemBackground` | soft charcoal |
| Card surface | `Color.bcCardFill` | `secondarySystemBackground` | `#212123` |
| Income | `Color.bcIncome` | deep emerald `#1A8F61` | mint `#66D69E` |
| Expense | `Color.bcExpense` | terracotta `#BF5430` | warm clay `#E8876F` |
| Separator | `Color.bcSeparator` | black 6% | white 10% |
| Text | system label / `.secondary` / `.tertiary` | charcoal | warm white |

**Money color is an accent, never the signal** — sign (`+`/`−`) + arrow glyph
carry meaning (color-blind safe). The brand mint accent is **unchanged**
globally (the `AccentColor` asset drives the locked screenshot pipeline and the
shipped paywall; recoloring it is out of scope for this pass).

## Typography

Implemented in `DesignSystem.swift` as `Font.bc*`. SF Pro, rounded for numerals
to match the existing money aesthetic.

| Token | Size / weight | Use |
|-------|---------------|-----|
| `bcDisplay` | 60 rounded bold | Hero amount (Quick Entry) |
| `bcAmount` | 40 rounded bold | Card / dashboard net |
| `bcTitle` | 28 rounded semibold | Screen title |
| `bcSectionHeader` | 20 semibold | Section header |
| `bcBody` | 17 regular | Body |
| `bcCaption` | 13 regular | Caption (pair `.secondary`) |

## Spacing (`Spacing.*`)

8-pt rhythm: `xs 8` · `s 12` · `compact 16` · `default 24` · `generous 32` · `hero 48`.

## Radius (`CornerRadius.*`)

`icon 8` · `button 12` · `card 16` · `cardLarge 20` · `sheet 24`.

## Elevation (`Elevation.*`)

- `card` — black 5%, radius 8, y 2 (resting).
- `raised` — black 10%, radius 14, y 6 (active CTA / lifted).

Use `.cardSurface()` / `.elevation(_:)` view modifiers.

## Anti-patterns

- No raw `Color.green` / `Color.red` for money — use `Color.money(isPositive:)`.
- No magic-number paddings — use `Spacing.*`.
- No alarm-red expenses — terracotta.
- No per-view `MoneyFormatter` — use `Shared/Money.swift`.
- Don't recolor the global `AccentColor` asset (screenshot + paywall coupling).
