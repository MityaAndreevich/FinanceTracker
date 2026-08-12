# BRIEF (Claude Code) — v1.0.3 Proactive gain-framed alerts (premium hook). Model: Sonnet. Skills: apple-hig-expert, paywalls. Do AFTER iCloud sync (additive, lower risk).

**v1.0.3 branch.** `main`, commit per unit, push, build + test before commit. Localize all strings in 5 locales (incl. the notification bodies). No CLAUDE.md anti-patterns. On-device only — no server, no data leaves the phone (privacy wedge).

## Why (NotebookLM-validated — source: MONETIZATION_FREE_PAID_SPEC.md v2 + a16f8bf7)
Proactive spend alerts reduce the financial anxiety 70% of trackers feel and are a validated premium hook (AI/insight apps earn ~41% more LTV). Two hard rules from the research:
1. **Gain-frame, never loss-frame.** "You'll have $X safe by Friday" / "You're on pace" — NOT "You only have $X left" (loss-framing triggers the Day-0 risk alarm). Gain-framing lifts conversion +23% and lowers anxiety.
2. **User-configured timing, or it reads as nagging** (Duolingo lesson). The user picks whether alerts are on, which day, and what time. Default OFF or a single gentle default the user can change.

## Scope
- **Reuse existing Pace / safe-to-spend logic** (grep — we shipped `PaceMetric` + safe-to-spend). Don't recompute; the alert is a notification wrapper around the same numbers, with the same ChartGuards-style guards (no fire on sparse/degenerate data).
- **Local notifications** via `UNUserNotificationCenter`. Request permission gracefully and only when the user turns alerts ON (not at launch). On-device scheduling; nothing transmitted.
- **Alert types (gain-framed):**
  - Weekly "safe to spend" ("You have {amount} safe to spend through {day}.") on a user-chosen day/time.
  - Pace nudge ("You're spending a bit faster than usual — {amount} safe for the rest of the month.") — calm, not alarm; muted, no red.
  - Only fire when there's enough data to be truthful (guard: budget or income known, elapsed days > 0, non-degenerate). Never a false/degenerate alert on a money app.
- **Premium-gated:** the alerts settings section is behind `AccessManager.isPremium`; a free user tapping it → the paywall (contextual upsell). During the reverse trial they work (premium-active).
- **Settings UX:** on/off, day picker, time picker, alert-type toggles. Respect the system notification settings (if the user denied at OS level, show a clear "enable in Settings" state, don't nag).

## Guardrails
- Gain-frame copy only; no alarm-red, no guilt, no loss-framing.
- User controls timing — never a fixed unchangeable schedule.
- On-device; no analytics/telemetry on the alerts.
- Don't fire on sparse data (would be wrong/annoying and erodes trust on a finance app).

## Tests (targeted)
- Gain-framed strings in 5 locales, no truncation on the longest (ru/pt-BR); numbers via Money.swift.
- Scheduling: alert fires at the user-chosen day/time; disabling cancels pending notifications.
- Guards: no alert scheduled when data is degenerate (no budget/income, elapsed==0).
- Gating: settings blocked when free → paywall; active in reverse trial / paid.
- OS-permission-denied path shows the enable-in-Settings state, doesn't crash or nag.

## Report (≤6 lines/item): alert types + copy, the reused Pace source, scheduling, gating, permission handling, files, build/test, commit per unit. Device-verify: turn alerts on → permission prompt → set a time → the gain-framed notification fires; free user hits the paywall; sparse data fires nothing.
