# Device QA — v1.0.2 (gate before submit). Run on the real iPhone, build from `main` (≥ 5cd7b56).

Scope = **what changed in 1.0.2**. Not a full-app regression. Anything ❌ → stop and report, don't submit.

## 0. Setup
- [ ] Build current `main` to the device from Xcode. **Keep it attached** — if it crashes we want the log, not a memory of it.
- [ ] Do the first pass **without deleting the app** (you carry a revealed log full of orphaned `placeholder-004` etc. — that's the exact upgrade path real testers hit). Then a second pass on a clean install.

## 1. Upgrade path — orphaned tips (highest risk, new code)
- [ ] App launches. No crash. (Your persisted log points at placeholder ids that no longer exist.)
- [ ] A tip of the day shows, with real content — not blank, not a placeholder.
- [ ] Learn hub: collection isn't broken; no empty rows or ghost entries.
- [ ] Completion counter (`X of Y unlocked`) reads sanely — not "102 of 102" on day one.

## 2. Tips content — 5 locales
- [ ] Switch in-app language through all five (en / ru / es / pt-BR / uk). Tip of the day renders in each; no English leaking into a translated one.
- [ ] Terminology matches the UI: the tip says **«Можно потратить»**, not «Свободно тратить»; **«Темп трат»**, not «Темп». Same check in es / pt-BR / uk. This is the thing we just fixed — verify it actually shipped.
- [ ] Text doesn't clip or overflow on the tip card in RU/UK (longest strings).
- [ ] Widget still follows the **baked** in-app language after a language switch.

## 3. Collection + reveal cadence
- [ ] Clean install → **exactly one** tip unlocked. Not a back-catalogue.
- [ ] Unseen tips are locked — no term/text visible, and search doesn't surface them.
- [ ] Search inside the hub returns only unlocked tips.
- [ ] Help articles (8) are present regardless.
- [ ] (Optional, if quick) advance the device date one day → exactly one more unlocks, not a dump.

## 4. Paywall
- [ ] Free vs Premium comparison renders; columns aligned; RU labels wrap without clipping.
- [ ] Data-safety line is visible and readable ("nothing is deleted if you go back to Free…").
- [ ] **No trial claim anywhere** (the offer is removed — any "30-day free" text is a blocker).
- [ ] Prices show correctly in your store's currency; no hardcoded "$34.99" / "Save 42%".
- [ ] Restore is visible. Dismiss is easy.
- [ ] The caps advertised are the caps enforced: try adding a 3rd account and a 4th custom category on Free → blocked, with the paywall reachable.

## 5. Manual entry dedup (this was silent data loss)
- [ ] Add **two identical transactions in a row, fast** (same amount, same merchant, same day) → **two rows appear.** One row = regression, stop.
- [ ] Double-tap Save fast on one entry → exactly one row (the 500ms gate).
- [ ] If a save fails, the sheet reopens rather than silently dismissing.

## 6. Alerts
- [ ] Proactive alert copy is month-scoped and gain-framed; no false "safe through Friday" on a month remainder.
- [ ] Premium-gated: a Free user doesn't get them.

## 7. The crash watch (#22 — ship-and-monitor)
- [ ] Hammer QuickAdd: 15–20 rapid adds, mixed Cyrillic and English merchant names, with Dashboard and Analytics visible.
- [ ] Watch the Xcode console for **`Invalid frame dimension (negative or non-finite)`** — that line is the fingerprint. Its absence is the signal the frame guards hold.
- [ ] If it crashes: don't detach. Grab `bt` and the full console tail and send them.

## 8. Sanity
- [ ] CSV export → open the file; amounts use "." and aren't column-shifted (re-verify in RU locale).
- [ ] Charts render on Dashboard + Analytics with 0, 1, and many transactions — no blank-forever, no crash.

## Verdict
- All green → bump build, archive, upload, submit 1.0.2.
- Any ❌ → report it here with the log; we fix before submitting.
