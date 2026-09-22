# Crash reports harvested before a simulator erase

The erase-before-every-full-run rule deletes the simulator's own `.ips` files, which is how
the three reports `DEFECT_VOICE_INPUT_DEINIT_ABORT.md` §1 quoted came to be unverifiable
(`8e16662`). So: **copy first, erase second**, into a dated directory here.

`crashReporterKey` (a device-identifying hash) is redacted in every file; nothing else is edited.

- `2026-09-21/…171428.ips` — `TSVExportServiceTests.delimiterCollisionsAreNeutralised` dying by
  index trap under a Phase 0 escaping mutant (the test now fails by assertion instead).
- `2026-09-21/…181558.ips`, `…181658.ips` — the commissioned D5 reds: `Swift runtime failure:
  arithmetic overflow` in `AnalyticsSeries` / `CategoryBreakdown` with plain `+` restored.
- `2026-09-21/…190156.ips` — the same, from the `PoisonedAnalyticsJourneyTests` mutant run.
