# Proactive gain-framed alerts — design

**Version:** v1.0.2 (retargeted from v1.0.3 — alerts are low-risk and bundle into the big 1.0.2)
**Date:** 2026-07-14
**Status:** approved, ready for implementation planning
**Brief:** `outputs/BRIEF_PROACTIVE_ALERTS_V1_0_3.md`

## Goal

A single weekly, gain-framed, on-device notification telling the user how much they
have safe to spend — at a day and time they choose. Premium-gated. Never fires on
data too sparse to be truthful.

Nothing leaves the device. No server, no telemetry on the alerts.

## Corrections to the originating brief

1. **`PaceMetric` already contains the sparse-data guard the brief asks for.**
   `evaluate(...)` returns `.unavailable` unless `elapsedDays > 0` and
   `baselineDailyCents > 0`. We consume that state; we do not re-implement it.

2. **Notification infrastructure is not greenfield.** `RecurrenceService` already has
   `requestAuthorizationIfNeeded()` and `UNNotificationRequest` scheduling. Reuse the
   pattern; do not write a second permission flow.

3. **Safe-to-spend is NOT reusable, despite what the brief assumes.** The brief says
   "don't recompute; we shipped safe-to-spend." We did not — not as a reusable unit.
   It is inline in `DashboardView` (`remainingCents = monthlyBudgetCents - expenseCents`,
   `budgetIsSet`). It must be **extracted first**, or the scheduler duplicates it and
   the two drift. A notification that disagrees with the dashboard is precisely the
   trust-eroding bug the brief exists to prevent.

4. **Gate through `AppCapability`, not raw `isPremium`.** `AccessManager.isAllowed(_:)`
   and the `AppCapability` enum already exist, and the reverse trial resolves through
   them for free.

## The problem the brief does not address: staleness

**A local notification's body is frozen when it is scheduled, not when it fires.**

So "You have $412 safe to spend through Friday," computed on Monday and delivered on
Friday, is a lie if the user spent anything on Wednesday. On a money app. That
directly violates the brief's own rule that an alert must never be false.

**Resolution: reschedule on every write.**

Safe-to-spend is `budget − spend(this month)`. It changes **only** when a transaction
is written, when the budget changes, or when the month rolls over. *The passage of
time alone never changes it.* So if we recompute and reschedule the single pending
alert after every write, then a number computed on Monday and delivered on Friday is
still literally true on Friday — because if it had stopped being true, a write would
have occurred and we would have rescheduled.

Month rollover is the one time-based case, and it gets an explicit guard: **never
schedule an occurrence that falls outside the current month.**

## Architecture

Three units, split so that everything decidable is pure and testable, and the impure
shell is as thin as possible.

### 1. `Shared/SafeToSpend.swift` — pure, new

Extracted from `DashboardView`, mirroring `PaceMetric`'s shape.

```swift
enum SafeToSpend {
    struct Snapshot: Equatable {
        let monthlyBudgetCents: Int
        let spentCents: Int
        let elapsedDays: Int
        let daysInMonth: Int
        var remainingCents: Int { monthlyBudgetCents - spentCents }
        var isBudgetSet: Bool { monthlyBudgetCents > 0 }
    }
}
```

**`DashboardView` is refactored to consume it.** That is the point of the extraction:
the dashboard and the notification become mathematically incapable of disagreeing.

### 2. `Services/ProactiveAlertPolicy.swift` — pure, new. The feature's brain.

Given a `SafeToSpend.Snapshot`, a `PaceMetric.State`, the user's settings, and `now`,
it returns a plan or **nil**. No I/O, no `UNUserNotificationCenter`, no `Bundle`.

```swift
/// The user's alert preferences, mirrored from @AppStorage so the policy stays pure.
struct AlertSettings: Equatable {
    let isEnabled: Bool
    let weekday: Int      // 1–7, Calendar's numbering
    let hour: Int         // 0–23
    let minute: Int       // 0–59
}

enum ProactiveAlertPolicy {
    enum Body: Equatable {
        case safeToSpend(amountCents: Int)   // "You have {amount} safe to spend this month."
        case pace(amountCents: Int)          // "…a bit faster than usual — {amount} safe for the rest of the month."
    }
    struct Plan: Equatable {
        let fireDate: Date
        let body: Body
    }
    static func plan(
        snapshot: SafeToSpend.Snapshot,
        pace: PaceMetric.State,
        settings: AlertSettings,
        now: Date,
        calendar: Calendar
    ) -> Plan?
}
```

**The five nil-guards** — each one a unit test:

| Condition | Why nil |
|---|---|
| `!settings.isEnabled` | User turned alerts off. |
| `!snapshot.isBudgetSet` | No budget ⇒ no safe-to-spend number ⇒ nothing truthful to say. |
| `snapshot.elapsedDays == 0` | Degenerate; nothing to report; matches `PaceMetric`'s own guard. |
| `snapshot.remainingCents <= 0` | Over budget — see below. |
| next fire date is outside the current month | Rollover guard: the numbers would be for the wrong month. |

**Body selection:** `.pace` when `pace == .faster`, `.safeToSpend` otherwise. The pace
nudge is *folded into the weekly alert* rather than being a second notification — so
the user gets at most one push per week, and nagging is structurally impossible
(the brief's own Duolingo lesson).

### 3. `Services/ProactiveAlertScheduler.swift` — the thin impure shell

- Cancels the pending request, then adds **at most one**. **Never a repeating
  trigger** — a repeating notification would replay a frozen number forever.
- `UNUserNotificationCenter` sits behind a small protocol (`NotificationScheduling`)
  so "disabling cancels pending" is testable against a fake.
- Permission is requested **only when the user turns alerts on** — never at launch —
  reusing `RecurrenceService`'s existing pattern.

### Refresh triggers

The pending alert is recomputed on:

- **app foreground** (`scenePhase → .active`), and
- **`ModelContext.didSave`** — one choke-point covering every in-app write, rather
  than hunting down each save site individually.

### AppIntents: cancel, don't reschedule

Siri and widget writes run in a **different process**, which does not have the app's
`LocalizedBundle` swizzle — so an AppIntent that scheduled a notification could write
it in the wrong language. (This is the same `Bundle.main` trap the widget hit.)

So **AppIntents cancel the pending alert and schedule nothing.** The app re-creates it
on next foreground. Cancelling needs no localization and no arithmetic.

This is also correct on the numbers, independently of language: a Siri write changed
the spend, so the pending alert is now wrong *regardless*. Cancelling it is the right
move on both counts. Worst case is a missed alert; never a wrong one.

## Over budget: send nothing

When `remainingCents <= 0`, **no alert is scheduled that week.**

Every truthful sentence about a negative balance is loss-framed, and loss-framing is
forbidden — it is the Day-0 anxiety trigger the research says to avoid. A push is an
unsolicited interruption; there is no honest, gain-framed, over-budget message, and a
chirpy number-free one reads as tone-deaf to someone deep in the red.

We are **declining to push bad news, not hiding it**: the over-budget state is already
fully visible in-app on the dashboard and the widget (muted terracotta), where the user
can see it on their own terms.

## Gating

Add `AppCapability.proactiveAlerts`; gate via `AccessManager.isAllowed(.proactiveAlerts)`.
The reverse trial resolves through the same call, so trial users get alerts with no
extra code. A free user tapping the Settings row gets the paywall (contextual upsell).

## Settings UX — `Views/Settings/AlertsSettingsView.swift`

On/off toggle, weekday picker, time picker. Stored as `@AppStorage`:
`alertsEnabled` (Bool), `alertWeekday` (Int, 1–7), `alertHour` (Int), `alertMinute` (Int).

**Three blocked states, each a real user:**

| State | UI |
|---|---|
| Not premium | Row routes to the paywall. |
| OS permission denied | Plain "enable in Settings" row with a deep link. Shown once, in place. Never nagged. |
| No budget set | "Set a budget to enable alerts," linking to the existing budget setter. |

## Copy

Gain-framed only. No alarm-red, no guilt, no loss-framing. Amounts through
`Shared/Money.swift` — never a per-view formatter.

- **Safe-to-spend:** "You have {amount} safe to spend this month."
- **Pace:** "You're spending a bit faster than usual — {amount} safe for the rest of the month."

All strings localized in 5 locales (en, ru, es, pt-BR, uk), notification bodies included.

### Correction to the brief's copy

The brief specifies *"You have {amount} safe to spend **through {day}**."* That copy is
**wrong for the number we have**, and shipping it would be the exact false-number
failure this design exists to prevent — just hidden in the wording rather than the
arithmetic.

`remainingCents` is `budget − spend` for the **whole month**. Presenting it as what is
safe *through Friday* overstates what the user can spend this week, by a factor of
however much of the month is left. A user with £400 left for three weeks would read
"£400 safe through Friday" and be encouraged to spend all of it in five days.

So both bodies are scoped to the month, matching the arithmetic exactly. There is no
`{day}` placeholder. Producing a genuinely week-scoped figure would be different (and
new) arithmetic; it is not in this version.

## Known limits

**Siri/widget-only users get fewer alerts.** The correct re-create happens on app
foreground, and out-of-process writes do not reach the app's `ModelContext.didSave`.
So a user who interacts only through Siri and the widget, and rarely opens the app,
will have their pending alert cancelled and not promptly re-created.

This is **accepted, not fixed**. A cross-process reschedule is deliberately *not*
built: it is fragile, and it would have to re-derive the locale inside the extension —
walking straight back into the `Bundle.main` trap this design avoids. A missed
low-stakes nudge is a fair price for a guaranteed-correct one.

**Over-budget weeks are silent** (above). Silent exactly when the stakes feel highest —
accepted, because the alternative violates the gain-framing rule.

**Pace news can be up to 6 days late,** since the pace nudge rides the weekly slot
rather than firing on its own. Accepted: it buys structural non-naggability.

### Future enhancement — do NOT build in this version

**A pace-aware rate figure is the stronger premium hook**, and the inputs already exist
in `SafeToSpend.Snapshot` (`remainingCents`, plus days-left derivable from
`elapsedDays` / `daysInMonth`). Something like *"~{amount}/day for the rest of the
month"* — or a genuine week-scoped *"through {day}"* number — tells the user what to
actually do, where a month total only tells them where they stand.

This is a **fast-follow after 1.0.2 ships**, not part of it. This version stays honestly
month-scoped: it is better to ship a number that is exactly true than a more useful
number that is approximately true, on a money app, in the version that introduces
notifications at all.

## Testing

- **Policy (pure, no simulator):** each of the five nil-guards; body selection on
  `.faster` vs. otherwise; the month-rollover boundary.
- **`SafeToSpend`:** extraction is behaviour-preserving — the dashboard's numbers are
  unchanged.
- **Scheduler:** disabling cancels the pending request (fake `NotificationScheduling`);
  at most one request is ever added; never a repeating trigger.
- **Gating:** blocked when free; allowed during the reverse trial and when paid.
- **Permission denied:** the settings screen shows the enable-in-Settings state and
  does not crash or nag.
- **Copy:** 5-locale parity; amounts via `Money.swift`; no truncation in the longest
  locale (ru/uk).

## Files

**New**
- `FinanceTracker/Shared/SafeToSpend.swift`
- `FinanceTracker/Services/ProactiveAlertPolicy.swift`
- `FinanceTracker/Services/ProactiveAlertScheduler.swift`
- `FinanceTracker/Views/Settings/AlertsSettingsView.swift`
- `FinanceTrackerTests/SafeToSpendTests.swift`
- `FinanceTrackerTests/ProactiveAlertPolicyTests.swift`
- `FinanceTrackerTests/ProactiveAlertSchedulerTests.swift`

**Modified**
- `FinanceTracker/Views/DashboardView.swift` — consume `SafeToSpend`
- `FinanceTracker/Purchases/FreeTierLimits.swift` — add `.proactiveAlerts`
- `FinanceTracker/Views/Settings/SettingsView.swift` — the Alerts row
- `FinanceTracker/FinanceTrackerApp.swift` — foreground + `ModelContext.didSave` refresh
- `FinanceTracker/AppIntents/*` — cancel the pending alert after a write
- `FinanceTracker/{en,ru,es,pt-BR,uk}.lproj/Localizable.strings`
- `FinanceTrackerTests/LocaleCompletenessTests.swift` — baseline bump (currently 661)

## Device verification

Turn alerts on → permission prompt appears → set a day/time → the gain-framed
notification fires with the right number. A free user hits the paywall. A user with no
budget sees the set-a-budget state. Sparse data fires nothing. Over budget fires
nothing.
