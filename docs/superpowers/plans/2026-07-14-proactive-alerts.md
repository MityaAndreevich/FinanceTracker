# Proactive Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One weekly, gain-framed, on-device notification telling the user how much they have safe to spend, at a day and time they choose — premium-gated, and silent whenever the data can't support a true statement.

**Architecture:** Everything decidable is pure and testable without a simulator. `SafeToSpend` extracts the maths currently trapped inside `DashboardView`. `ProactiveAlertPolicy` is a single pure function returning a plan or `nil` (five guards). `ProactiveAlertScheduler` is a thin impure shell over `UNUserNotificationCenter`, behind a protocol so tests can assert against a fake.

**Tech Stack:** SwiftUI, SwiftData, `UserNotifications`, Swift Testing (`import Testing`) for new tests, XCTest for the existing `LocaleCompletenessTests`.

**Spec:** `docs/superpowers/specs/2026-07-14-proactive-alerts-design.md` (`fc959d6`, `f166bd7`). Read it first.

## Global Constraints

- **Gain-framed copy only.** No loss-framing, no alarm-red, no guilt. Over budget ⇒ **send nothing**.
- **Month-scoped copy.** `remainingCents` is a whole-month figure. Never present it as a week figure — there is no `{day}` placeholder. (The brief's "safe to spend through {day}" is wrong; see the spec.)
- **Never fire on data that can't support a true statement.** Five nil-guards in `ProactiveAlertPolicy`.
- **At most one pending notification, never a repeating trigger.** A repeating trigger would replay a frozen number forever.
- **Permission is requested only when the user turns alerts ON.** Never at launch.
- **`AppCapability.proactiveAlerts` ALREADY EXISTS** in `FreeTierLimits.swift` with `requiresPremium == true`. Do **not** add it. Gate via `AccessManager.shared.isAllowed(.proactiveAlerts)` — the reverse trial resolves through the same call for free.
- **AppIntents cancel, never reschedule.** They run out-of-process without the `LocalizedBundle` swizzle.
- **Amounts via `Shared/Money.swift`** (`Money.format(cents:currencyCode:)`). Never a per-view formatter.
- **Five locales:** `en`, `ru`, `es`, `pt-BR`, `uk`. No hardcoded English, notification bodies included.
- **No `pbxproj` edits.** The app target is a `PBXFileSystemSynchronizedRootGroup`; new files under `FinanceTracker/` are picked up automatically.
- Commit after each task with a conventional prefix. Build before every commit.

**Simulator UDID** (the `name=` matcher fails on this machine):

```
C2BC48D9-DE78-4C7A-8845-ADD486863AB8
```

**Build:**

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'id=C2BC48D9-DE78-4C7A-8845-ADD486863AB8' build 2>&1 | tail -5
```

**Test:**

```bash
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination 'id=C2BC48D9-DE78-4C7A-8845-ADD486863AB8' \
  -parallel-testing-enabled NO -only-testing:FinanceTrackerTests test 2>&1 \
  | grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|✘|error:" | head
```

`-parallel-testing-enabled NO` is required in this repo — parallel workers corrupt the shared SwiftData store.

---

### Task 1: SafeToSpend (extract the maths from DashboardView)

The spec's key correction: safe-to-spend is **not** currently reusable. It is inline in `DashboardView`. Extract it first, or the scheduler duplicates it and a notification can disagree with the dashboard — the exact trust bug this feature exists to avoid.

The snapshot also carries the prior-history fields `PaceMetric.baselineDailyCents` needs, so the alert can evaluate pace without a second aggregation pass.

**Files:**
- Create: `FinanceTracker/Shared/SafeToSpend.swift`
- Modify: `FinanceTracker/Views/DashboardView.swift` (`expenseCents` ~line 77, `remainingCents` ~line 105)
- Test: `FinanceTrackerTests/SafeToSpendTests.swift`

**Interfaces:**
- Consumes: `Transaction` (`isIncome`, `isExpense`, `amountCents`, `date`), `PeriodScope.currentMonth`.
- Produces:
  - `SafeToSpend.Entry` — `amountCents: Int`, `date: Date`, `isIncome: Bool`
  - `SafeToSpend.Snapshot` — `monthlyBudgetCents`, `spentCents`, `elapsedDays`, `daysInMonth`, `priorExpenseCents`, `priorSpanDays`; computed `remainingCents: Int`, `isBudgetSet: Bool`
  - `SafeToSpend.remainingCents(monthlyBudgetCents:spentCents:) -> Int`
  - `SafeToSpend.snapshot(monthlyBudgetCents:spentThisMonthCents:priorExpenseCents:priorSpanDays:now:calendar:) -> Snapshot`
  - `SafeToSpend.aggregate(entries:now:calendar:) -> (spentThisMonthCents: Int, priorExpenseCents: Int, priorSpanDays: Int)`
  - `SafeToSpend.entries(from: [Transaction]) -> [Entry]` — the only part that touches SwiftData

**Why `Entry` exists:** `Transaction.init` requires a non-optional `category: Category`, so
building fixtures would drag a SwiftData `ModelContainer` into what should be pure
arithmetic tests. `Entry` is the three fields the maths actually needs, so the aggregation
is tested with plain structs and the SwiftData dependency shrinks to one trivial `map`.

- [ ] **Step 1: Write the failing tests**

Create `FinanceTrackerTests/SafeToSpendTests.swift`:

```swift
//
//  SafeToSpendTests.swift
//  FinanceTrackerTests
//
//  Safe-to-spend used to live inside DashboardView, which meant anything else that
//  needed the number had to recompute it — and a notification that disagrees with
//  the dashboard is exactly the trust bug the alerts feature exists to avoid.
//  These tests pin the extracted maths.
//

import Testing
import Foundation
@testable import FinanceTracker

struct SafeToSpendTests {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func snapshot(
        budget: Int,
        spent: Int,
        now: Date,
        priorExpense: Int = 0,
        priorSpan: Int = 0
    ) -> SafeToSpend.Snapshot {
        SafeToSpend.snapshot(
            monthlyBudgetCents: budget,
            spentThisMonthCents: spent,
            priorExpenseCents: priorExpense,
            priorSpanDays: priorSpan,
            now: now,
            calendar: cal
        )
    }

    // MARK: - The number itself

    @Test func remainingIsBudgetMinusSpend() {
        let s = snapshot(budget: 100_000, spent: 40_000, now: date(2026, 7, 10))
        #expect(s.remainingCents == 60_000)
    }

    @Test func remainingGoesNegativeWhenOverBudget() {
        // The snapshot reports the truth. Suppressing the alert is the POLICY's job
        // (Task 2), not this type's — this must not clamp to zero and hide it.
        let s = snapshot(budget: 100_000, spent: 130_000, now: date(2026, 7, 10))
        #expect(s.remainingCents == -30_000)
    }

    @Test func noBudgetIsNotSet() {
        #expect(snapshot(budget: 0, spent: 5_000, now: date(2026, 7, 10)).isBudgetSet == false)
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 10)).isBudgetSet == true)
    }

    // MARK: - Calendar fields

    @Test func elapsedDaysCountsTodayInclusive() {
        // Day-to-date window: the 1st is day 1, not day 0.
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 1)).elapsedDays == 1)
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 14)).elapsedDays == 14)
    }

    @Test func daysInMonthFollowsTheRealCalendar() {
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 7, 14)).daysInMonth == 31)
        #expect(snapshot(budget: 1, spent: 0, now: date(2026, 2, 14)).daysInMonth == 28)
        #expect(snapshot(budget: 1, spent: 0, now: date(2028, 2, 14)).daysInMonth == 29)  // leap
    }

    // MARK: - Aggregation over a ledger

    private func expense(_ cents: Int, _ d: Date) -> SafeToSpend.Entry {
        SafeToSpend.Entry(amountCents: cents, date: d, isIncome: false)
    }

    private func income(_ cents: Int, _ d: Date) -> SafeToSpend.Entry {
        SafeToSpend.Entry(amountCents: cents, date: d, isIncome: true)
    }

    @Test func aggregateSumsThisMonthsExpensesOnly() {
        let agg = SafeToSpend.aggregate(
            entries: [
                expense(5_000, date(2026, 7, 2)),
                expense(3_000, date(2026, 7, 10)),
                income(90_000, date(2026, 7, 5)),      // income is not spending
                expense(7_000, date(2026, 6, 20)),     // prior month
            ],
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(agg.spentThisMonthCents == 8_000)
        #expect(agg.priorExpenseCents == 7_000)
    }

    @Test func priorSpanIsMeasuredFromTheEarliestPriorExpense() {
        let agg = SafeToSpend.aggregate(
            entries: [
                expense(1_000, date(2026, 6, 1)),
                expense(1_000, date(2026, 6, 15)),
            ],
            now: date(2026, 7, 14), calendar: cal
        )
        // 1 June → 1 July is 30 days of history.
        #expect(agg.priorSpanDays == 30)
        #expect(agg.priorExpenseCents == 2_000)
    }

    @Test func noPriorHistoryIsZeroSpanNotACrash() {
        // A brand-new user has no "usual" to compare against. This must yield 0, which
        // drives PaceMetric to .unavailable rather than dividing by zero.
        let agg = SafeToSpend.aggregate(
            entries: [expense(1_000, date(2026, 7, 3))],
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(agg.priorExpenseCents == 0)
        #expect(agg.priorSpanDays == 0)
    }

    @Test func emptyLedgerAggregatesToZeros() {
        let agg = SafeToSpend.aggregate(entries: [], now: date(2026, 7, 14), calendar: cal)
        #expect(agg.spentThisMonthCents == 0)
        #expect(agg.priorExpenseCents == 0)
        #expect(agg.priorSpanDays == 0)
    }

    @Test func futureDatedExpensesDoNotCountAsSpentYet() {
        // A transaction dated later this month has not been spent as of today.
        let agg = SafeToSpend.aggregate(
            entries: [expense(9_000, date(2026, 7, 28))],
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(agg.spentThisMonthCents == 0)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command from Global Constraints.
Expected: compile failure — `cannot find 'SafeToSpend' in scope`.

- [ ] **Step 3: Write the implementation**

Create `FinanceTracker/Shared/SafeToSpend.swift`:

```swift
//
//  SafeToSpend.swift
//  FinanceTracker
//
//  What's left of this month's budget, and the history PaceMetric needs to judge
//  spending velocity — as pure data, computable anywhere.
//
//  This used to live inside DashboardView. It was extracted because the proactive
//  alerts need the same number, and a notification that disagrees with the dashboard
//  would erode trust on a money app faster than no notification at all. One
//  computation, two consumers, no possible drift.
//

import Foundation

enum SafeToSpend {

    /// The three fields the arithmetic actually needs from a ledger row.
    ///
    /// `Transaction.init` requires a non-optional `Category`, so taking `[Transaction]`
    /// directly would drag a SwiftData `ModelContainer` into tests that are pure
    /// arithmetic. This keeps the maths testable with plain structs and confines the
    /// SwiftData dependency to one `map`.
    struct Entry: Equatable, Sendable {
        let amountCents: Int
        let date: Date
        let isIncome: Bool
    }

    /// A month's spending position. Reports the truth, including a negative
    /// `remainingCents` — deciding what to *do* about being over budget (namely: stay
    /// silent) belongs to `ProactiveAlertPolicy`, not here.
    struct Snapshot: Equatable, Sendable {
        let monthlyBudgetCents: Int
        let spentCents: Int
        /// Days elapsed this month, today inclusive — the day-to-date window.
        let elapsedDays: Int
        let daysInMonth: Int
        /// Gross expense before this month, and the day-span it covers. Feeds
        /// `PaceMetric.baselineDailyCents` for budget-less users.
        let priorExpenseCents: Int
        let priorSpanDays: Int

        /// Can be negative. Do not clamp — the caller needs to know.
        var remainingCents: Int { monthlyBudgetCents - spentCents }

        var isBudgetSet: Bool { monthlyBudgetCents > 0 }
    }

    /// The one subtraction, in one place. `DashboardView` and the alerts both call this,
    /// so they cannot drift apart.
    static func remainingCents(monthlyBudgetCents: Int, spentCents: Int) -> Int {
        monthlyBudgetCents - spentCents
    }

    static func snapshot(
        monthlyBudgetCents: Int,
        spentThisMonthCents: Int,
        priorExpenseCents: Int,
        priorSpanDays: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Snapshot {
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let elapsedDays = calendar.component(.day, from: now)

        return Snapshot(
            monthlyBudgetCents: monthlyBudgetCents,
            spentCents: spentThisMonthCents,
            elapsedDays: elapsedDays,
            daysInMonth: daysInMonth,
            priorExpenseCents: priorExpenseCents,
            priorSpanDays: priorSpanDays
        )
    }

    /// Rolls a ledger up into the three figures `snapshot(...)` needs.
    static func aggregate(
        entries: [Entry],
        now: Date,
        calendar: Calendar = .current
    ) -> (spentThisMonthCents: Int, priorExpenseCents: Int, priorSpanDays: Int) {
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else { return (0, 0, 0) }

        let today = calendar.startOfDay(for: now)
        var spentThisMonth = 0
        var priorExpense = 0
        var earliestPriorDay: Date?

        for entry in entries where !entry.isIncome {
            let day = calendar.startOfDay(for: entry.date)
            if day < monthStart {
                priorExpense += entry.amountCents
                earliestPriorDay = earliestPriorDay.map { min($0, day) } ?? day
            } else if day <= today {
                // A future-dated expense has not been spent yet.
                spentThisMonth += entry.amountCents
            }
        }

        let priorSpanDays = earliestPriorDay
            .flatMap { calendar.dateComponents([.day], from: $0, to: monthStart).day } ?? 0

        return (spentThisMonth, priorExpense, priorSpanDays)
    }

    /// The only place this type touches SwiftData.
    static func entries(from transactions: [Transaction]) -> [Entry] {
        transactions.map {
            Entry(amountCents: $0.amountCents, date: $0.date, isIncome: $0.isIncome)
        }
    }
}
```

- [ ] **Step 4: Point DashboardView at it**

In `FinanceTracker/Views/DashboardView.swift`, replace the inline `remainingCents` (~line 105):

```swift
    /// What's left of the budget this month (can go negative when over budget).
    private var remainingCents: Int { monthlyBudgetCents - expenseCents }
```

with a call into the extracted type, so the dashboard and the alert cannot disagree:

```swift
    /// What's left of the budget this month (can go negative when over budget).
    ///
    /// Delegates to `SafeToSpend` — the alerts read the same computation, and a
    /// notification that disagreed with this screen would be worse than no
    /// notification at all.
    private var remainingCents: Int {
        SafeToSpend.remainingCents(
            monthlyBudgetCents: monthlyBudgetCents,
            spentCents: expenseCents
        )
    }
```

Leave `expenseCents`, `budgetIsSet`, `daysLeftInMonth`, and `perDayCents` exactly as they are — this task changes *where the subtraction lives*, nothing else. The dashboard's rendered numbers must be byte-for-byte identical.

- [ ] **Step 5: Run the tests to verify they pass**

Run the test command from Global Constraints.
Expected: `SafeToSpendTests` all pass, and every pre-existing suite still passes (the dashboard refactor is behaviour-preserving).

- [ ] **Step 6: Commit**

```bash
git add FinanceTracker/Shared/SafeToSpend.swift FinanceTracker/Views/DashboardView.swift \
        FinanceTrackerTests/SafeToSpendTests.swift
git commit -F - <<'EOF'
feat(alerts): extract safe-to-spend from DashboardView

The alerts need this number, and the brief assumed it was already reusable. It
was not — it lived inline in the view, so anything else that wanted it had to
recompute it. A notification that disagrees with the dashboard would erode trust
on a money app faster than no notification at all, so there is now one
computation with two consumers.

The snapshot reports a negative remainder rather than clamping it: deciding to
stay silent when over budget is the policy's job, not the arithmetic's.
EOF
```

---

### Task 2: ProactiveAlertPolicy (pure — the five guards)

Everything the feature decides lives here, in one pure function with no `UNUserNotificationCenter`, no `Bundle`, and no clock of its own. Every rule in the brief becomes a unit test against it.

**Files:**
- Create: `FinanceTracker/Services/ProactiveAlertPolicy.swift`
- Test: `FinanceTrackerTests/ProactiveAlertPolicyTests.swift`

**Interfaces:**
- Consumes: `SafeToSpend.Snapshot` (Task 1), `PaceMetric.State` (exists).
- Produces:
  - `AlertSettings` — `isEnabled: Bool`, `weekday: Int` (1–7, `Calendar` numbering), `hour: Int`, `minute: Int`
  - `ProactiveAlertPolicy.Body` — `.safeToSpend(amountCents: Int)` | `.pace(amountCents: Int)`
  - `ProactiveAlertPolicy.Plan` — `fireDate: Date`, `body: Body`
  - `ProactiveAlertPolicy.plan(snapshot:pace:settings:now:calendar:) -> Plan?`

- [ ] **Step 1: Write the failing tests**

Create `FinanceTrackerTests/ProactiveAlertPolicyTests.swift`:

```swift
//
//  ProactiveAlertPolicyTests.swift
//  FinanceTrackerTests
//
//  The whole feature's judgement lives in one pure function, so every rule in the
//  brief is a test here rather than something you have to observe on a device.
//
//  The five nil-guards all exist for the same reason: on a money app, a notification
//  that is wrong is far worse than a notification that never arrives.
//

import Testing
import Foundation
@testable import FinanceTracker

struct ProactiveAlertPolicyTests {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-07-14 is a Tuesday (Calendar weekday 3).
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func settings(
        enabled: Bool = true,
        weekday: Int = 6,      // Friday
        hour: Int = 18,
        minute: Int = 0
    ) -> AlertSettings {
        AlertSettings(isEnabled: enabled, weekday: weekday, hour: hour, minute: minute)
    }

    private func snapshot(
        budget: Int = 100_000,
        spent: Int = 40_000,
        elapsed: Int = 14,
        daysInMonth: Int = 31
    ) -> SafeToSpend.Snapshot {
        SafeToSpend.Snapshot(
            monthlyBudgetCents: budget,
            spentCents: spent,
            elapsedDays: elapsed,
            daysInMonth: daysInMonth,
            priorExpenseCents: 50_000,
            priorSpanDays: 30
        )
    }

    // MARK: - Guard 1: disabled

    @Test func disabledSchedulesNothing() {
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(enabled: false),
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 2: no budget

    @Test func noBudgetSchedulesNothing() {
        // Without a budget there is no safe-to-spend number, so there is nothing
        // truthful to say. Silence, not a guess.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 0), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 3: degenerate elapsed

    @Test func zeroElapsedDaysSchedulesNothing() {
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(elapsed: 0), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 4: over budget → silence

    @Test func overBudgetSchedulesNothing() {
        // Every truthful sentence about a negative balance is loss-framed, and
        // loss-framing is forbidden. So we say nothing at all.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 100_000, spent: 130_000), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    @Test func exactlyOnBudgetSchedulesNothing() {
        // remaining == 0: "You have $0.00 safe to spend" is technically true and
        // emotionally a scolding. Boundary belongs on the silent side.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 100_000, spent: 100_000), pace: .onPace,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - Guard 5: month rollover

    @Test func aFireDateInNextMonthSchedulesNothing() {
        // Tue 28 July, alert set for Saturday → the next Saturday is 1 August, whose
        // numbers reset. Scheduling it would deliver July's figure in August.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(weekday: 7),          // Saturday
            now: date(2026, 7, 28), calendar: cal
        )
        #expect(plan == nil)
    }

    // MARK: - The happy paths

    @Test func schedulesTheNextMatchingWeekdayInThisMonth() {
        // Tue 14 July 09:00, alert on Friday 18:00 → Fri 17 July 18:00.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(weekday: 6, hour: 18, minute: 0),
            now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan != nil)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: plan!.fireDate)
        #expect(comps.year == 2026)
        #expect(comps.month == 7)
        #expect(comps.day == 17)
        #expect(comps.hour == 18)
        #expect(comps.minute == 0)
    }

    @Test func fireDateIsAlwaysInTheFuture() {
        // Today IS Friday and the time has already passed → next Friday, not today.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(), pace: .onPace,
            settings: settings(weekday: 6, hour: 8, minute: 0),
            now: date(2026, 7, 17, 20),      // Fri 17 July, 20:00 — 08:00 is gone
            calendar: cal
        )
        #expect(plan != nil)
        #expect(plan!.fireDate > date(2026, 7, 17, 20))
        #expect(cal.component(.day, from: plan!.fireDate) == 24)   // the following Friday
    }

    // MARK: - Body selection

    @Test func fasterPaceGetsThePaceBody() {
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 100_000, spent: 40_000), pace: .faster,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan?.body == .pace(amountCents: 60_000))
    }

    @Test func everyOtherPaceStateGetsTheSafeToSpendBody() {
        for pace: PaceMetric.State in [.onPace, .under, .unavailable] {
            let plan = ProactiveAlertPolicy.plan(
                snapshot: snapshot(budget: 100_000, spent: 40_000), pace: pace,
                settings: settings(), now: date(2026, 7, 14), calendar: cal
            )
            #expect(plan?.body == .safeToSpend(amountCents: 60_000),
                    "pace \(pace) should fall back to the safe-to-spend body")
        }
    }

    @Test func bothBodiesCarryTheMonthRemainder() {
        // Guards the spec's copy correction: the amount is the WHOLE MONTH's
        // remainder, so the copy must be month-scoped. Never a week figure.
        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot(budget: 250_000, spent: 100_000), pace: .faster,
            settings: settings(), now: date(2026, 7, 14), calendar: cal
        )
        #expect(plan?.body == .pace(amountCents: 150_000))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command. Expected: `cannot find 'ProactiveAlertPolicy' in scope`.

- [ ] **Step 3: Write the implementation**

Create `FinanceTracker/Services/ProactiveAlertPolicy.swift`:

```swift
//
//  ProactiveAlertPolicy.swift
//  FinanceTracker
//
//  Whether to send a weekly alert, when, and what it says. Pure — no notification
//  centre, no Bundle, no ambient clock — so every rule is unit-testable.
//
//  The five nil-guards below all exist for one reason: on a money app, an alert that
//  is wrong is far worse than an alert that never arrives. When we cannot say
//  something both true and gain-framed, we say nothing.
//

import Foundation

/// The user's alert preferences, mirrored out of `@AppStorage` so the policy stays pure.
struct AlertSettings: Equatable, Sendable {
    let isEnabled: Bool
    /// `Calendar` numbering: 1 = Sunday … 7 = Saturday.
    let weekday: Int
    let hour: Int
    let minute: Int
}

enum ProactiveAlertPolicy {

    /// What the notification says. Both bodies carry the **whole month's** remainder,
    /// which is why the copy is month-scoped — presenting this as a week figure would
    /// overstate what is safe to spend and encourage overspending.
    enum Body: Equatable, Sendable {
        case safeToSpend(amountCents: Int)
        case pace(amountCents: Int)
    }

    struct Plan: Equatable, Sendable {
        let fireDate: Date
        let body: Body
    }

    static func plan(
        snapshot: SafeToSpend.Snapshot,
        pace: PaceMetric.State,
        settings: AlertSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> Plan? {
        // 1. The user turned alerts off.
        guard settings.isEnabled else { return nil }

        // 2. No budget ⇒ no safe-to-spend number ⇒ nothing truthful to say.
        guard snapshot.isBudgetSet else { return nil }

        // 3. Degenerate period — the same guard PaceMetric applies to itself.
        guard snapshot.elapsedDays > 0 else { return nil }

        // 4. Over budget (or exactly on it). Every honest sentence about a negative
        //    balance is loss-framed, and loss-framing is forbidden — it is the anxiety
        //    trigger the research says to avoid. The dashboard still shows the truth to
        //    anyone who opens the app; we are declining to *push* bad news, not hiding it.
        guard snapshot.remainingCents > 0 else { return nil }

        guard let fireDate = nextFireDate(settings: settings, now: now, calendar: calendar)
        else { return nil }

        // 5. Month rollover: the numbers reset on the 1st, so an alert computed in July
        //    must never be delivered in August carrying July's figure.
        guard calendar.isDate(fireDate, equalTo: now, toGranularity: .month) else { return nil }

        let amount = snapshot.remainingCents
        let body: Body = (pace == .faster)
            ? .pace(amountCents: amount)
            : .safeToSpend(amountCents: amount)

        return Plan(fireDate: fireDate, body: body)
    }

    /// The next occurrence of the chosen weekday-and-time strictly after `now`.
    private static func nextFireDate(
        settings: AlertSettings,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.weekday = settings.weekday
        components.hour = settings.hour
        components.minute = settings.minute

        // `.strict` + `matchNextTime` gives the next matching instant, never `now`
        // itself — so an alert set for 08:00 on a Friday, evaluated at 20:00 on that
        // Friday, lands next Friday rather than in the past.
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test command. Expected: all `ProactiveAlertPolicyTests` pass.

- [ ] **Step 5: Commit**

```bash
git add FinanceTracker/Services/ProactiveAlertPolicy.swift \
        FinanceTrackerTests/ProactiveAlertPolicyTests.swift
git commit -F - <<'EOF'
feat(alerts): pure policy deciding whether to send, when, and what

Five guards, all the same principle: on a money app an alert that is wrong is far
worse than one that never arrives, so when we cannot say something both true and
gain-framed, we say nothing. No budget, no elapsed days, over budget, or a fire
date that would land in next month (whose numbers reset) all yield nil.

Over budget is the sharpest case: every honest sentence about a negative balance
is loss-framed, and loss-framing is exactly the anxiety trigger the research says
to avoid. The dashboard still shows the truth on open — we decline to push bad
news, we don't hide it.

Both bodies carry the whole month's remainder, which is why the copy is
month-scoped: presenting it as a week figure would encourage overspending.
EOF
```

---

### Task 3: ProactiveAlertScheduler (the thin impure shell)

**Files:**
- Create: `FinanceTracker/Services/ProactiveAlertScheduler.swift`
- Test: `FinanceTrackerTests/ProactiveAlertSchedulerTests.swift`

**Interfaces:**
- Consumes: `ProactiveAlertPolicy.Plan` / `.Body` (Task 2), `Money.format(cents:currencyCode:)`.
- Produces:
  - `protocol NotificationScheduling` — `removePending(identifiers: [String])`, `add(_ request: UNNotificationRequest)`
  - `ProactiveAlertScheduler.identifier: String`
  - `ProactiveAlertScheduler.apply(plan:currencyCode:center:)`
  - `ProactiveAlertScheduler.cancel(center:)`
  - `ProactiveAlertScheduler.requestAuthorization() async -> Bool`
  - `ProactiveAlertScheduler.authorizationStatus() async -> UNAuthorizationStatus`

- [ ] **Step 1: Write the failing tests**

Create `FinanceTrackerTests/ProactiveAlertSchedulerTests.swift`:

```swift
//
//  ProactiveAlertSchedulerTests.swift
//  FinanceTrackerTests
//
//  The scheduler is the only impure part of the feature, so UNUserNotificationCenter
//  sits behind a protocol and these tests drive a fake. What matters is that there is
//  never more than one pending alert, that it never repeats (a repeating trigger would
//  replay a frozen number forever), and that turning alerts off actually cancels.
//

import Testing
import Foundation
import UserNotifications
@testable import FinanceTracker

/// Records what the scheduler asked the system to do.
final class FakeNotificationCenter: NotificationScheduling, @unchecked Sendable {
    var added: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    func removePending(identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func schedule(_ request: UNNotificationRequest) {
        added.append(request)
    }
}

struct ProactiveAlertSchedulerTests {

    private func plan(amount: Int = 60_000, pace: Bool = false) -> ProactiveAlertPolicy.Plan {
        ProactiveAlertPolicy.Plan(
            fireDate: Date().addingTimeInterval(3 * 24 * 3600),
            body: pace ? .pace(amountCents: amount) : .safeToSpend(amountCents: amount)
        )
    }

    @Test func applyingAPlanAlwaysClearsThePreviousOneFirst() {
        // Otherwise a stale request with an out-of-date number could survive alongside
        // the fresh one, and iOS would deliver both.
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(), currencyCode: "USD", center: center)

        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
        #expect(center.added.count == 1)
    }

    @Test func aNilPlanCancelsAndSchedulesNothing() {
        // This is how every one of the policy's guards reaches the system: no plan,
        // no notification — and any previously-scheduled one is withdrawn.
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: nil, currencyCode: "USD", center: center)

        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
        #expect(center.added.isEmpty)
    }

    @Test func cancellingRemovesThePendingRequest() {
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.cancel(center: center)

        #expect(center.removedIdentifiers == [ProactiveAlertScheduler.identifier])
        #expect(center.added.isEmpty)
    }

    @Test func theTriggerNeverRepeats() {
        // A repeating trigger would re-deliver a number frozen at schedule time, week
        // after week, long after it stopped being true.
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(), currencyCode: "USD", center: center)

        let trigger = center.added.first?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger != nil)
        #expect(trigger?.repeats == false)
    }

    @Test func onlyEverOnePendingAlert() {
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(amount: 10_000), currencyCode: "USD", center: center)
        ProactiveAlertScheduler.apply(plan: plan(amount: 20_000), currencyCode: "USD", center: center)

        // Both used the same identifier, so iOS replaces rather than accumulates.
        #expect(Set(center.added.map(\.identifier)) == [ProactiveAlertScheduler.identifier])
    }

    @Test func theBodyCarriesTheFormattedAmount() {
        let center = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(amount: 60_000), currencyCode: "USD", center: center)

        let body = center.added.first?.content.body ?? ""
        let expected = Money.format(cents: 60_000, currencyCode: "USD")
        #expect(body.contains(expected), "body should contain \(expected), got: \(body)")
    }

    @Test func thePaceBodyDiffersFromTheSafeToSpendBody() {
        let safeCenter = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(pace: false), currencyCode: "USD", center: safeCenter)

        let paceCenter = FakeNotificationCenter()
        ProactiveAlertScheduler.apply(plan: plan(pace: true), currencyCode: "USD", center: paceCenter)

        #expect(safeCenter.added.first?.content.body != paceCenter.added.first?.content.body)
    }

    @Test func noBodyIsEverLossFramed() {
        // Cheap guard against a future edit reintroducing loss-framing. Both bodies must
        // talk about what the user HAS, never what they have lost or gone over.
        for pace in [false, true] {
            let center = FakeNotificationCenter()
            ProactiveAlertScheduler.apply(plan: plan(pace: pace), currencyCode: "USD", center: center)
            let body = (center.added.first?.content.body ?? "").lowercased()
            #expect(!body.contains("over budget"))
            #expect(!body.contains("only"))
            #expect(!body.contains("-"))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command. Expected: `cannot find 'ProactiveAlertScheduler' in scope` / `cannot find type 'NotificationScheduling'`.

- [ ] **Step 3: Write the implementation**

Create `FinanceTracker/Services/ProactiveAlertScheduler.swift`:

```swift
//
//  ProactiveAlertScheduler.swift
//  FinanceTracker
//
//  The only impure part of the alerts feature: it turns a `ProactiveAlertPolicy.Plan`
//  (or the absence of one) into a pending iOS notification (or the absence of one).
//
//  Follows the pattern already established in RecurrenceService rather than inventing a
//  second notification flow.
//

import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` this feature needs — behind a protocol so
/// the scheduling rules can be tested against a fake instead of the real system.
///
/// The method is `schedule`, not `add`: `UNUserNotificationCenter` already has its own
/// `add(_:)` overloads, and a protocol requirement of the same name would be ambiguous
/// at best and infinitely recursive at worst.
protocol NotificationScheduling {
    func removePending(identifiers: [String])
    func schedule(_ request: UNNotificationRequest)
}

extension UNUserNotificationCenter: NotificationScheduling {
    func removePending(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func schedule(_ request: UNNotificationRequest) {
        add(request, withCompletionHandler: nil)
    }
}

enum ProactiveAlertScheduler {

    /// One stable identifier, so a new request *replaces* the pending one rather than
    /// piling up beside it. There is never more than one weekly alert in flight.
    static let identifier = "budgetcrab.proactive.weekly"

    /// Cancel whatever is pending, then schedule the plan — or nothing, if there isn't
    /// one. Every guard in `ProactiveAlertPolicy` arrives here as `plan == nil`.
    static func apply(
        plan: ProactiveAlertPolicy.Plan?,
        currencyCode: String,
        center: NotificationScheduling = UNUserNotificationCenter.current()
    ) {
        center.removePending(identifiers: [identifier])
        guard let plan else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "alerts.notif.title")
        content.body = body(for: plan.body, currencyCode: currencyCode)
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: plan.fireDate
        )
        // `repeats: false` is load-bearing. A repeating trigger would re-deliver a
        // number frozen at schedule time, week after week, long after it went stale.
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        center.schedule(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }

    static func cancel(center: NotificationScheduling = UNUserNotificationCenter.current()) {
        center.removePending(identifiers: [identifier])
    }

    /// Gain-framed, month-scoped. The amount is the whole month's remainder, so the
    /// copy says so — calling it a week figure would overstate what is safe to spend.
    private static func body(for body: ProactiveAlertPolicy.Body, currencyCode: String) -> String {
        switch body {
        case .safeToSpend(let cents):
            return String(
                format: String(localized: "alerts.notif.body.safe.format"),
                Money.format(cents: cents, currencyCode: currencyCode)
            )
        case .pace(let cents):
            return String(
                format: String(localized: "alerts.notif.body.pace.format"),
                Money.format(cents: cents, currencyCode: currencyCode)
            )
        }
    }

    // MARK: - Authorization

    /// Asked for **only** when the user turns alerts on — never at launch.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test command.

Expected: all `ProactiveAlertSchedulerTests` pass — **except** that the two body tests will
show the raw keys `alerts.notif.body.safe.format` / `alerts.notif.body.pace.format` until
Task 4 adds the strings. `theBodyCarriesTheFormattedAmount` will therefore FAIL here.

That is expected and correct: the test is red for a real missing-string reason, not a
logic error. Task 4 turns it green. Do **not** weaken the test to make it pass now.

- [ ] **Step 5: Commit**

```bash
git add FinanceTracker/Services/ProactiveAlertScheduler.swift \
        FinanceTrackerTests/ProactiveAlertSchedulerTests.swift
git commit -F - <<'EOF'
feat(alerts): scheduler shell over UNUserNotificationCenter

One stable identifier so a fresh request replaces the pending one instead of
piling up beside it, and repeats:false because a repeating trigger would
re-deliver a number frozen at schedule time long after it went stale.

The centre sits behind a protocol so the rules that matter — never more than one
pending alert, a nil plan cancels and schedules nothing, no body is ever
loss-framed — are tested against a fake rather than observed on a device.

Permission is requested only from the settings toggle, never at launch.
EOF
```

---

### Task 4: Localized copy (5 locales)

Adds the strings Task 3 already references, which turns its one deliberately-red test green.

**Files:**
- Modify: `FinanceTracker/{en,ru,es,pt-BR,uk}.lproj/Localizable.strings`
- Modify: `FinanceTrackerTests/LocaleCompletenessTests.swift` (the baseline assertion, currently **661**)

**Interfaces:**
- Produces these keys, consumed by Tasks 3 and 5:
  `alerts.notif.title`, `alerts.notif.body.safe.format`, `alerts.notif.body.pace.format`,
  `settings.alerts`, `alerts.section.title`, `alerts.toggle`, `alerts.day`, `alerts.time`,
  `alerts.footer`, `alerts.needs_budget.title`, `alerts.needs_budget.message`,
  `alerts.needs_budget.cta`, `alerts.denied.title`, `alerts.denied.message`,
  `alerts.denied.cta`

- [ ] **Step 1: Append the keys to `en.lproj/Localizable.strings`**

```
/* MARK: - Proactive alerts */
"settings.alerts" = "Alerts";
"alerts.section.title" = "Weekly alert";
"alerts.toggle" = "Weekly safe-to-spend alert";
"alerts.day" = "Day";
"alerts.time" = "Time";
"alerts.footer" = "One calm notification a week, on your schedule. Nothing leaves your phone.";
"alerts.needs_budget.title" = "Set a budget first";
"alerts.needs_budget.message" = "Alerts tell you what's safe to spend, so they need a monthly budget to work from.";
"alerts.needs_budget.cta" = "Set a budget";
"alerts.denied.title" = "Notifications are off";
"alerts.denied.message" = "Turn on notifications for Budget Crab in the Settings app to get your weekly alert.";
"alerts.denied.cta" = "Open Settings";
"alerts.notif.title" = "Budget Crab";
"alerts.notif.body.safe.format" = "You have %@ safe to spend this month.";
"alerts.notif.body.pace.format" = "You're spending a bit faster than usual — %@ safe for the rest of the month.";
```

- [ ] **Step 2: Add the translations to the other four locales**

`ru.lproj/Localizable.strings`:

```
/* MARK: - Proactive alerts */
"settings.alerts" = "Уведомления";
"alerts.section.title" = "Еженедельное уведомление";
"alerts.toggle" = "Сколько можно потратить";
"alerts.day" = "День";
"alerts.time" = "Время";
"alerts.footer" = "Одно спокойное уведомление в неделю, в удобное вам время. Данные не покидают телефон.";
"alerts.needs_budget.title" = "Сначала задайте бюджет";
"alerts.needs_budget.message" = "Уведомления показывают, сколько можно потратить, поэтому им нужен месячный бюджет.";
"alerts.needs_budget.cta" = "Задать бюджет";
"alerts.denied.title" = "Уведомления отключены";
"alerts.denied.message" = "Включите уведомления для Budget Crab в приложении «Настройки», чтобы получать еженедельное сообщение.";
"alerts.denied.cta" = "Открыть настройки";
"alerts.notif.title" = "Budget Crab";
"alerts.notif.body.safe.format" = "В этом месяце можно потратить ещё %@.";
"alerts.notif.body.pace.format" = "Вы тратите немного быстрее обычного — до конца месяца можно потратить %@.";
```

`es.lproj/Localizable.strings`:

```
/* MARK: - Proactive alerts */
"settings.alerts" = "Avisos";
"alerts.section.title" = "Aviso semanal";
"alerts.toggle" = "Aviso semanal de gasto disponible";
"alerts.day" = "Día";
"alerts.time" = "Hora";
"alerts.footer" = "Un aviso tranquilo a la semana, cuando tú elijas. Nada sale de tu teléfono.";
"alerts.needs_budget.title" = "Primero define un presupuesto";
"alerts.needs_budget.message" = "Los avisos te dicen cuánto puedes gastar, así que necesitan un presupuesto mensual.";
"alerts.needs_budget.cta" = "Definir presupuesto";
"alerts.denied.title" = "Las notificaciones están desactivadas";
"alerts.denied.message" = "Activa las notificaciones de Budget Crab en Ajustes para recibir tu aviso semanal.";
"alerts.denied.cta" = "Abrir Ajustes";
"alerts.notif.title" = "Budget Crab";
"alerts.notif.body.safe.format" = "Puedes gastar %@ este mes.";
"alerts.notif.body.pace.format" = "Estás gastando un poco más rápido de lo habitual: %@ disponibles para el resto del mes.";
```

`pt-BR.lproj/Localizable.strings`:

```
/* MARK: - Proactive alerts */
"settings.alerts" = "Avisos";
"alerts.section.title" = "Aviso semanal";
"alerts.toggle" = "Aviso semanal do que dá para gastar";
"alerts.day" = "Dia";
"alerts.time" = "Horário";
"alerts.footer" = "Um aviso tranquilo por semana, no seu horário. Nada sai do seu celular.";
"alerts.needs_budget.title" = "Defina um orçamento primeiro";
"alerts.needs_budget.message" = "Os avisos mostram quanto dá para gastar, então precisam de um orçamento mensal.";
"alerts.needs_budget.cta" = "Definir orçamento";
"alerts.denied.title" = "As notificações estão desativadas";
"alerts.denied.message" = "Ative as notificações do Budget Crab nos Ajustes para receber seu aviso semanal.";
"alerts.denied.cta" = "Abrir Ajustes";
"alerts.notif.title" = "Budget Crab";
"alerts.notif.body.safe.format" = "Você tem %@ para gastar neste mês.";
"alerts.notif.body.pace.format" = "Você está gastando um pouco mais rápido que o normal — %@ disponíveis para o resto do mês.";
```

`uk.lproj/Localizable.strings`:

```
/* MARK: - Proactive alerts */
"settings.alerts" = "Сповіщення";
"alerts.section.title" = "Щотижневе сповіщення";
"alerts.toggle" = "Скільки можна витратити";
"alerts.day" = "День";
"alerts.time" = "Час";
"alerts.footer" = "Одне спокійне сповіщення на тиждень, у зручний вам час. Дані не залишають телефон.";
"alerts.needs_budget.title" = "Спершу задайте бюджет";
"alerts.needs_budget.message" = "Сповіщення показують, скільки можна витратити, тож їм потрібен місячний бюджет.";
"alerts.needs_budget.cta" = "Задати бюджет";
"alerts.denied.title" = "Сповіщення вимкнено";
"alerts.denied.message" = "Увімкніть сповіщення для Budget Crab у «Налаштуваннях», щоб отримувати щотижневе повідомлення.";
"alerts.denied.cta" = "Відкрити налаштування";
"alerts.notif.title" = "Budget Crab";
"alerts.notif.body.safe.format" = "Цього місяця можна витратити ще %@.";
"alerts.notif.body.pace.format" = "Ви витрачаєте трохи швидше, ніж зазвичай — до кінця місяця можна витратити %@.";
```

- [ ] **Step 3: Update the baseline in `LocaleCompletenessTests.swift`**

This task adds **15** keys to a baseline of 661, so it becomes **676**. Replace the existing assertion and add a note above it in the same style as the entries already there:

```swift
        // 2026-07-14 (proactive alerts): +15. The alerts settings chrome, the three
        // blocked states (no budget / permission denied / paywall), and the two
        // gain-framed notification bodies. Both bodies are month-scoped because the
        // amount is the whole month's remainder — calling it a week figure would
        // overstate what is safe to spend. All 5 locales in parity. Was 661.
        XCTAssertEqual(enKeys.count, 676, "English baseline changed; update the expected count.")
```

- [ ] **Step 4: Run the tests**

Run the test command.

Expected: `LocaleCompletenessTests` passes at 676, **and** `ProactiveAlertSchedulerTests.theBodyCarriesTheFormattedAmount` — deliberately left red at the end of Task 3 — now passes, because the format strings resolve.

If the baseline assertion reports a count other than 676, do **not** paste the actual number in. It means a key landed in one locale and was missed in another. Reconcile the five files first.

- [ ] **Step 5: Commit**

```bash
git add FinanceTracker/*.lproj/Localizable.strings FinanceTrackerTests/LocaleCompletenessTests.swift
git commit -F - <<'EOF'
i18n(alerts): gain-framed notification copy in five locales

Both bodies are month-scoped ("safe to spend this month"), matching the arithmetic
exactly. The brief's "safe to spend through {day}" is deliberately not used: the
amount is the whole month's remainder, and presenting it as a week figure would
tell a user with three weeks left that they can spend it all by Friday.

Also covers the three blocked states — no budget, notifications denied, and the
paywall — because each is a real user, not an error case.
EOF
```

---

### Task 5: AlertsSettingsView + gating

Three blocked states, each a real user. `AppCapability.proactiveAlerts` **already exists** — consume it, don't add it.

**Files:**
- Create: `FinanceTracker/Views/Settings/AlertsSettingsView.swift`
- Modify: `FinanceTracker/Views/Settings/SettingsView.swift` (add the row next to Learn & Tips)
- Test: `FinanceTrackerTests/ProactiveAlertGatingTests.swift`

**Interfaces:**
- Consumes: `AccessManager.shared.isAllowed(.proactiveAlerts)`, `AlertSettings` (Task 2), `ProactiveAlertScheduler` (Task 3), `PaywallView` (exists), the Task 4 strings.
- Produces: `AlertsSettingsView()`; the `@AppStorage` keys `alertsEnabled`, `alertWeekday`, `alertHour`, `alertMinute`.

- [ ] **Step 1: Write the failing gating test**

Create `FinanceTrackerTests/ProactiveAlertGatingTests.swift`:

```swift
//
//  ProactiveAlertGatingTests.swift
//  FinanceTrackerTests
//
//  Alerts are a premium hook. The capability already existed in FreeTierLimits
//  (declared so the gate would be there the day the feature landed) — these tests pin
//  that it actually gates, and that the reverse trial gets alerts for free.
//

import Testing
import Foundation
@testable import FinanceTracker

struct ProactiveAlertGatingTests {

    @Test func alertsRequirePremium() {
        #expect(AppCapability.proactiveAlerts.requiresPremium == true)
    }

    @Test func aFreeUserIsBlocked() {
        let isPremium = AccessManager.isPremium(
            hasPaidEntitlement: false,
            trialStart: nil,
            now: .now
        )
        #expect(isPremium == false)
    }

    @Test func anActiveReverseTrialGetsAlerts() {
        // The reverse trial resolves through the same isPremium call, so trial users
        // get alerts with no extra code path to forget.
        let startedToday = Date.now
        let isPremium = AccessManager.isPremium(
            hasPaidEntitlement: false,
            trialStart: startedToday,
            now: .now
        )
        #expect(isPremium == true)
    }

    @Test func aPaidUserGetsAlerts() {
        let isPremium = AccessManager.isPremium(
            hasPaidEntitlement: true,
            trialStart: nil,
            now: .now
        )
        #expect(isPremium == true)
    }

    @Test func aLapsedTrialWithoutPurchaseIsBlocked() {
        let longAgo = Calendar.current.date(byAdding: .day, value: -60, to: .now)!
        let isPremium = AccessManager.isPremium(
            hasPaidEntitlement: false,
            trialStart: longAgo,
            now: .now
        )
        #expect(isPremium == false)
    }
}
```

- [ ] **Step 2: Run it to verify it passes**

Run the test command.

Expected: **PASS immediately.** `AppCapability.proactiveAlerts` and `AccessManager.isPremium` both already exist, so this task's test is a *characterization* test — it pins behaviour we are about to depend on, and would catch someone later flipping `proactiveAlerts` to free by accident. There is no red phase here, and that is correct; do not invent one.

- [ ] **Step 3: Write AlertsSettingsView**

Create `FinanceTracker/Views/Settings/AlertsSettingsView.swift`:

```swift
//
//  AlertsSettingsView.swift
//  FinanceTracker
//
//  One weekly, gain-framed notification — on the user's schedule, or not at all.
//
//  Three blocked states, each of which is a real person rather than an error: a free
//  user (paywall), someone who denied notifications at the OS level (a plain pointer to
//  Settings, shown once, never nagged), and someone with no budget (nothing truthful to
//  say without one).
//

import SwiftUI
import UserNotifications

struct AlertsSettingsView: View {
    @AppStorage("alertsEnabled") private var alertsEnabled = false
    @AppStorage("alertWeekday") private var alertWeekday = 6      // Friday
    @AppStorage("alertHour") private var alertHour = 18
    @AppStorage("alertMinute") private var alertMinute = 0
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents = 0

    @ObservedObject private var access = AccessManager.shared

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPaywall = false
    @State private var showBudgetSetter = false

    private var isBudgetSet: Bool { monthlyBudgetCents > 0 }
    private var isDenied: Bool { authStatus == .denied }

    var body: some View {
        List {
            if !access.isAllowed(.proactiveAlerts) {
                premiumSection
            } else if !isBudgetSet {
                needsBudgetSection
            } else {
                if isDenied { deniedSection }
                alertSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task { authStatus = await ProactiveAlertScheduler.authorizationStatus() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showBudgetSetter) { BudgetSetterSheet() }
    }

    // MARK: - The real thing

    private var alertSection: some View {
        Section {
            Toggle("alerts.toggle", isOn: $alertsEnabled)
                .onChange(of: alertsEnabled) { _, isOn in
                    Task { await toggled(on: isOn) }
                }

            if alertsEnabled && !isDenied {
                Picker("alerts.day", selection: $alertWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdayName(weekday)).tag(weekday)
                    }
                }
                DatePicker(
                    "alerts.time",
                    selection: Binding(
                        get: { timeOfDay },
                        set: { newValue in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            alertHour = comps.hour ?? 18
                            alertMinute = comps.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("alerts.section.title")
        } footer: {
            Text("alerts.footer")
        }
    }

    // MARK: - Blocked states

    private var premiumSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                Label("alerts.toggle", systemImage: "lock")
            }
        } footer: {
            Text("alerts.footer")
        }
    }

    private var needsBudgetSection: some View {
        Section {
            Button {
                showBudgetSetter = true
            } label: {
                Label("alerts.needs_budget.cta", systemImage: "target")
            }
        } header: {
            Text("alerts.needs_budget.title")
        } footer: {
            Text("alerts.needs_budget.message")
        }
    }

    /// Stated once, in place. No repeat prompting — the user already said no, and the
    /// brief is explicit that we do not nag.
    private var deniedSection: some View {
        Section {
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Label("alerts.denied.cta", systemImage: "gear")
            }
        } header: {
            Text("alerts.denied.title")
        } footer: {
            Text("alerts.denied.message")
        }
    }

    // MARK: - Behaviour

    /// Permission is asked for here and nowhere else — the moment the user opts in,
    /// never at launch.
    private func toggled(on isOn: Bool) async {
        guard isOn else {
            ProactiveAlertScheduler.cancel()
            return
        }
        if authStatus == .notDetermined {
            _ = await ProactiveAlertScheduler.requestAuthorization()
            authStatus = await ProactiveAlertScheduler.authorizationStatus()
        }
        // The actual scheduling happens on the next refresh (foreground / didSave),
        // which is the one place that owns the snapshot.
    }

    private var timeOfDay: Date {
        Calendar.current.date(
            from: DateComponents(hour: alertHour, minute: alertMinute)
        ) ?? .now
    }

    private func weekdayName(_ weekday: Int) -> String {
        // Calendar weekday numbering is 1-based (1 = Sunday); the symbols array is 0-based.
        let symbols = Calendar.current.standaloneWeekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index].capitalized
    }
}

#Preview {
    NavigationStack { AlertsSettingsView() }
}
```

- [ ] **Step 4: Add the Settings row**

In `FinanceTracker/Views/Settings/SettingsView.swift`, in the same `Section` that holds the Learn & Tips row, add above it:

```swift
                NavigationLink {
                    AlertsSettingsView()
                } label: {
                    Label("settings.alerts", systemImage: "bell.badge")
                }
```

- [ ] **Step 5: Build and run the full suite**

Run the build command, then the test command. Expected: build succeeds, all tests pass.

(`BudgetSetterSheet()` takes no arguments — it reads `monthlyBudgetCents` straight from
`@AppStorage` — so the call above is correct as written. Reuse it; do not build a second
budget-setting sheet.)

- [ ] **Step 6: Commit**

```bash
git add FinanceTracker/Views/Settings/AlertsSettingsView.swift \
        FinanceTracker/Views/Settings/SettingsView.swift \
        FinanceTrackerTests/ProactiveAlertGatingTests.swift
git commit -F - <<'EOF'
feat(alerts): settings screen with the three blocked states

Free user, OS-denied notifications, and no budget are each a real person rather
than an error case, so each gets a real state: the paywall, a plain one-time
pointer to Settings (never a repeat prompt — the user already said no), and a
link to set a budget (without one there is no safe-to-spend number to report).

AppCapability.proactiveAlerts already existed, declared so the gate would be there
the day the feature landed — so gating is a consumption, not a new enum case, and
the reverse trial resolves through the same isAllowed call for free.

Permission is requested from the toggle and nowhere else.
EOF
```

---

### Task 6: Refresh wiring (foreground, didSave, AppIntents cancel)

The pending alert is only correct if it is recomputed whenever the numbers move. Safe-to-spend changes **only** on a write — so one choke-point on saves, plus foreground, covers it.

**Files:**
- Create: `FinanceTracker/Services/ProactiveAlertRefresher.swift`
- Modify: `FinanceTracker/FinanceTrackerApp.swift` (scenePhase + `ModelContext.didSave`)
- Modify: `FinanceTracker/AppIntents/` — cancel after any write

**Interfaces:**
- Consumes: `SafeToSpend` (Task 1), `PaceMetric` (exists), `ProactiveAlertPolicy` (Task 2), `ProactiveAlertScheduler` (Task 3), `AccessManager`.
- Produces: `ProactiveAlertRefresher.refresh(modelContext:)`.

- [ ] **Step 1: Write the refresher**

Create `FinanceTracker/Services/ProactiveAlertRefresher.swift`:

```swift
//
//  ProactiveAlertRefresher.swift
//  FinanceTracker
//
//  Recomputes the single pending alert. This is the join between the pure policy and
//  the live ledger, and it is the answer to the staleness problem: a local
//  notification's body is frozen when scheduled, so an amount in it can be wrong by the
//  time it fires.
//
//  Safe-to-spend is `budget − spend(this month)`. It changes ONLY when a transaction is
//  written, when the budget changes, or when the month rolls over — the passage of time
//  alone never changes it. So if we recompute after every write, a number computed on
//  Monday is still literally true on Friday: had it stopped being true, a write would
//  have happened and we would have rescheduled.
//

import Foundation
import SwiftData

@MainActor
enum ProactiveAlertRefresher {

    static func refresh(modelContext: ModelContext) {
        let defaults = UserDefaults.standard

        // A lapsed user keeps nothing pending. Checked here rather than trusting the
        // toggle, so an expired trial cannot leave a premium notification in flight.
        guard AccessManager.shared.isAllowed(.proactiveAlerts) else {
            ProactiveAlertScheduler.cancel()
            return
        }

        let settings = AlertSettings(
            isEnabled: defaults.bool(forKey: "alertsEnabled"),
            weekday: defaults.object(forKey: "alertWeekday") as? Int ?? 6,
            hour: defaults.object(forKey: "alertHour") as? Int ?? 18,
            minute: defaults.object(forKey: "alertMinute") as? Int ?? 0
        )

        let transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        let budget = defaults.integer(forKey: "monthlyBudgetCents")
        let currency = defaults.string(forKey: "defaultCurrencyCode") ?? "USD"
        let now = Date()

        let agg = SafeToSpend.aggregate(
            entries: SafeToSpend.entries(from: transactions),
            now: now
        )
        let snapshot = SafeToSpend.snapshot(
            monthlyBudgetCents: budget,
            spentThisMonthCents: agg.spentThisMonthCents,
            priorExpenseCents: agg.priorExpenseCents,
            priorSpanDays: agg.priorSpanDays,
            now: now
        )

        let baseline = PaceMetric.baselineDailyCents(
            monthlyBudgetCents: snapshot.monthlyBudgetCents,
            daysInMonth: snapshot.daysInMonth,
            priorExpenseCents: snapshot.priorExpenseCents,
            priorSpanDays: snapshot.priorSpanDays
        )
        let pace = PaceMetric.evaluate(
            spentThisPeriodCents: snapshot.spentCents,
            elapsedDays: snapshot.elapsedDays,
            baselineDailyCents: baseline
        )

        let plan = ProactiveAlertPolicy.plan(
            snapshot: snapshot,
            pace: pace,
            settings: settings,
            now: now
        )

        ProactiveAlertScheduler.apply(plan: plan, currencyCode: currency)
    }
}
```

- [ ] **Step 2: Wire foreground + didSave in FinanceTrackerApp**

In `FinanceTracker/FinanceTrackerApp.swift`, on the same root view that already carries the
`.task { … }` block (around line 94), add:

```swift
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    ProactiveAlertRefresher.refresh(
                        modelContext: SharedModelContainer.shared.mainContext
                    )
                }
                // One choke-point for every in-app write, rather than hunting down each
                // save site. Safe-to-spend can only move when something is written.
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    ProactiveAlertRefresher.refresh(
                        modelContext: SharedModelContainer.shared.mainContext
                    )
                }
```

If `scenePhase` is not already in scope, add `@Environment(\.scenePhase) private var scenePhase`
to the `App` struct alongside its existing properties.

- [ ] **Step 3: Cancel from the AppIntents write path**

Find every AppIntent that writes a transaction:

```bash
grep -rln --include="*.swift" "modelContext.insert\|QuickAddSaveService\|\.save()" FinanceTracker/AppIntents
```

At the end of each such `perform()`, **after** the save, add:

```swift
        // Siri/widget writes run out-of-process, without the app's LocalizedBundle
        // swizzle — so scheduling here could produce a notification in the wrong
        // language (the same Bundle.main trap the widget hit). And the write just
        // changed the spend, so the pending alert is now wrong regardless of language.
        //
        // Cancel it. The app re-creates it correctly on next foreground. A missed
        // low-stakes nudge beats a wrong one on a money app.
        ProactiveAlertScheduler.cancel()
```

- [ ] **Step 4: Build and run the full suite**

Run the build command, then the test command. Expected: build succeeds, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add FinanceTracker/Services/ProactiveAlertRefresher.swift \
        FinanceTracker/FinanceTrackerApp.swift FinanceTracker/AppIntents
git commit -F - <<'EOF'
feat(alerts): recompute the pending alert whenever the numbers move

A local notification's body is frozen when scheduled, so an amount in it can be
wrong by the time it fires — on a money app. But safe-to-spend only changes when
something is written, never through the passage of time alone. So recomputing on
every save (one ModelContext.didSave choke-point) plus foreground means a number
computed on Monday is still literally true on Friday.

AppIntents cancel rather than reschedule: they run out-of-process without the
LocalizedBundle swizzle, so they could emit a notification in the wrong language —
and their write just invalidated the pending number anyway. Silence beats wrong.

A lapsed user's pending alert is cancelled at refresh, so an expired trial cannot
leave a premium notification in flight.
EOF
```

---

### Task 7: Device verification

- [ ] **Step 1: Build, install, launch**

```bash
SIM=C2BC48D9-DE78-4C7A-8845-ADD486863AB8
xcrun simctl boot $SIM 2>/dev/null; open -a Simulator
xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
  -destination "id=$SIM" -derivedDataPath build/verify build
xcrun simctl install $SIM build/verify/Build/Products/Debug-iphonesimulator/FinanceTracker.app
xcrun simctl launch $SIM com.dmitrylogachev.budgetcrab
```

- [ ] **Step 2: Verify the happy path**

- Settings shows an **Alerts** row (bell icon).
- With a budget set and premium/trial active: toggle on → **the OS permission prompt appears** (and only then, never at launch).
- Pick a day and time a couple of minutes out. Background the app. The notification fires, gain-framed, with the correct amount and the right currency.
- The amount in the notification **matches the dashboard's safe-to-spend exactly**. If it does not, `SafeToSpend` is not the single source it is supposed to be.

- [ ] **Step 3: Verify the three blocked states**

- **Free user** (lapsed trial, no purchase): the Alerts row shows the locked state and tapping it opens the paywall.
- **No budget:** clear the budget → the screen shows "Set a budget first" and links to the budget setter.
- **Permission denied:** deny at the OS prompt (or turn Budget Crab's notifications off in the Settings app) → the screen shows "Notifications are off" with an Open Settings button, and does **not** re-prompt on return.

- [ ] **Step 4: Verify the silences**

These are the point of the feature, so check them explicitly:

- **Over budget:** spend past the budget, then foreground the app. Confirm **no** notification is pending:
  ```bash
  # Nothing should be listed for the identifier budgetcrab.proactive.weekly
  xcrun simctl spawn $SIM log stream --predicate 'subsystem CONTAINS "usernotifications"' &
  ```
  Simpler check: set a fire time ~2 minutes out while over budget and confirm nothing arrives.
- **Sparse data:** fresh install, no budget → nothing is ever scheduled.

- [ ] **Step 5: Verify locale**

Switch the device language to Russian (`xcrun simctl spawn $SIM defaults write NSGlobalDomain AppleLanguages -array ru`, reinstall, relaunch) and confirm the **notification body itself** is Russian — not just the settings chrome. Restore to `en` afterwards.

- [ ] **Step 6: Clean up simulator state and push**

Manual QA writes defaults that can poison the test suite (this is what happened to
`TutorialFlowTests`). Clear anything you set, then confirm the suite is green:

```bash
SIM=C2BC48D9-DE78-4C7A-8845-ADD486863AB8
for k in alertsEnabled alertWeekday alertHour alertMinute monthlyBudgetCents; do
  xcrun simctl spawn $SIM defaults delete com.dmitrylogachev.budgetcrab $k 2>/dev/null
done
```

Run the test command one final time, then:

```bash
git push origin main
```

---

## Notes for the implementer

**`AppCapability.proactiveAlerts` already exists.** It was declared in `FreeTierLimits.swift`
under "Premium hooks — NOT built yet," with a comment saying the gate exists the day the
feature lands. Today is that day. Consume it; do not add a duplicate case.

**Known duplication, deliberately left alone.** `AnalyticsView.recomputePace(...)` computes
prior-history figures much like `SafeToSpend.aggregate(...)`. It is *not* refactored here —
it is entangled with the Pulse chart's own aggregation, and untangling it is not what this
feature is for. If you touch that file for another reason, consider unifying then.

**Known limit, by design.** A user who only ever writes via Siri or the widget, and rarely
opens the app, gets fewer alerts: their out-of-process writes cancel the pending alert, and
the correct re-create only happens on foreground. This is accepted. Do **not** build a
cross-process reschedule — it is fragile and would have to re-derive the locale inside the
extension, walking straight back into the `Bundle.main` trap this design avoids.
