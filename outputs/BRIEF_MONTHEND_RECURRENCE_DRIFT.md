# BRIEF — a month-end recurring series drifts off month-end permanently

**Filed:** 2026-07-30 · **Status:** filed, not started · **Severity:** wrong posting
dates, silently, forever · **Independent of iCloud sync**

Deliberately **not** fixed inside the recurrence-identity work
(`PLAN_RECURRENCE_SYNC_IDENTITY.md`). It changes posting dates for existing
users, so it deserves its own diff, its own test, and its own decision about
back-correcting series that have already drifted.

## The bug

`RecurrenceService.nextDueDate(for:recurrence:)` advances from the **last handled
boundary**, not from the series anchor:

```swift
let lastBoundary = handledDate(for: tx.uuid) ?? tx.date
return recurrence.nextDate(after: lastBoundary)
```

and `RecurrenceType.nextDate(after:)` is `calendar.date(byAdding: .month, value: 1, to: date)`.

`byAdding: .month` clamps into short months. Because the next step starts from
the **clamped result** rather than from the anchor, the clamp is permanent:

| period | due | why |
|---|---|---|
| Jan | Jan 31 | anchor |
| Feb | Feb 28 | clamped — correct |
| Mar | **Mar 28** | wrong; should be Mar 31 |
| Apr | Apr 28 | drifted for good |

One February moves a month-end subscription to the 28th for the rest of its life.
Same shape for a yearly series anchored Feb 29: it clamps to Feb 28 in 2025 and
never returns to the 29th in 2028.

## Correct behavior

Clamp the **anchor's** day-of-month into each target month, never the previous
result's:

- target month = anchor month + n periods
- day = `min(anchor day, days in target month)`

Jan 31 → Feb 28 → **Mar 31**. Feb 29 2024 → Feb 28 2025/26/27 → **Feb 29 2028**.

## Repro

Monthly template anchored 2026-01-31, confirm once in February, read the next due
date. Expect 2026-03-31; observe 2026-03-28.

## Notes for whoever takes it

- The anchor is `tx.date` — but under sync a series can have twin rows that
  disagree on it. Take the anchor from
  `RecurrenceService.canonicalTemplate(among:)`, not from an arbitrary row.
- Do **not** derive the occurrence identity from the posting date. It already
  does not: `RecurrencePeriod.label(for:cadence:)` keys on the calendar period,
  so Jan 31 and its Feb 28 posting are both simply `2026-02`. Fixing the drift
  moves posting dates **without** re-keying any occurrence — which is the whole
  reason identity was kept off the anchor.
- Decide explicitly whether already-drifted series are re-anchored or left where
  they are. Re-anchoring changes dates on rows a user has already seen.
- Needs a test per cadence, plus the Feb-29-returns-in-2028 case.
