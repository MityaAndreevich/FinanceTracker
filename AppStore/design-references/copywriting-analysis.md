# Copywriting Audit — In-App Strings (en.lproj baseline)

**Skill:** `copywriting`
**Date:** 2026-06-28 · **Inputs:** `FinanceTracker/en.lproj/Localizable.strings` (652 lines), `.agents/product-marketing.md` (voice + anti-claims)
**Method:** Full string read against documented voice/vocabulary/anti-claim rules. Analysis only — no strings changed.

> Voice target (from context doc): **calm, confident, precise; warm-not-folksy; lead with outcome; show-don't-tell on privacy; premium-but-human.** Avoid: exclamation points, "smart/powerful/seamless/streamline," "we care about privacy," bank/cloud language, "free forever," and all the legal anti-claims.

---

## Banned-claims sweep — result: **mostly clean** ✅

No legally/▲App-Review-dangerous claims found: **no** "AI-powered," "bank-grade," "end-to-end encrypted," "zero data collection," "free forever," or "we never see your data." The privacy strings use the safe architecture-first framing ("never leaves your device," "no servers"). This is genuinely well-disciplined.

Two soft violations of the **vocabulary** list (not legal, but off-voice):
- **"Smart insights coming soon"** (`dashboard.day0.title`) — "smart" is on the avoid list, and "coming soon" is a hype promise the Sage voice shouldn't make.
- **"future power features"** (`paywall.subtitle`) — "power features" is buzzword-adjacent and vague.

And **zero exclamation points** across all 652 lines — the voice rule is fully respected. ✅

---

## P0 — Developer artifacts & wrong brand name shipping to users

These are the highest-severity findings because the app is **pre-submission** and these are user-visible:

| Key | Current value | Problem |
|---|---|---|
| `general.language_hint` | "Language switching will be fully enabled when localization keys are added." | **Developer note shipped as UI.** Also now *factually false* (switching works). |
| `about.privacy_hint` | "Privacy Policy and Terms will be added before App Store release." | **Internal TODO** visible to users. |
| `about.app_name` | "FinanceTracker" | **Wrong brand** — should be "Budget Crab." |
| `settings.privacy.subtitle` | "FinanceTracker is built with privacy by design…" | **Wrong brand** on the flagship privacy screen. |
| `pdf.report.title` | "FinanceTracker Report" | **Wrong brand in exported PDFs** — a document users may share externally. |

"FinanceTracker" is the internal/legacy name; the product is **Budget Crab** everywhere in marketing. These regressions undercut brand consistency (and mere-exposure) at exactly the wrong moment.

---

## P1 — Voice & differentiator integrity

- **"We" as the on-device actor.** `tutorial.page1.caption` "We figure out the category automatically" and `dashboard.empty.caption` "Type or speak above — we'll do the rest." For a brand whose core claim is *no one can see your data*, "we" implies a remote brain. Prefer **"Budget Crab reads it on your iPhone."** Small words, but they quietly contradict the #1 differentiator.
- **"Source" leftover.** `edit.source.picker` = "Source" — the Source→Account rebrand is applied everywhere else ("Income by Account," "Add Account"). This one slipped.
- **"our servers."** `privacy.claim.no_data_uploaded` = "No data uploaded to our servers" — subtly implies servers exist. The architecture-first template prefers "there are no servers to upload to." Minor but on-brand to tighten.

---

## P2 — Consistency, stale keys, internal contradictions

1. **Duplicate empty-state copy for the Dashboard.** Two competing sets exist:
   - `dashboard.empty.headline/body/cta` = "Add your first transaction" / "Tap + to log income or expense in 3 seconds." / "Get started →"
   - `dashboard.empty.title/caption` = "Start tracking in seconds" / "Type or speak above — we'll do the rest" (this is the set actually rendered).
   One set is orphaned; they also disagree on the action model ("Tap +" vs "Type or speak above"). Pick one voice.
2. **Likely-dead legacy analytics strings.** `analytics.chart.pie/bars/line`, `analytics.section.combined.title`, `analytics.section.expenses_by_category.title`, `analytics.section.income_by_source.title`, `analytics.label.*`, `analytics.legend.*` appear superseded by the Pulse/Breakdown/Horizon redesign. Dead keys inflate the 459-key catalog and the translation surface (×4 locales).
3. **Restart messaging contradicts itself.** `settings.language.restart_required.*` strings still exist though the code now applies language *silently* (no restart alert), while `help.language_change.body` still tells users to fully quit and reopen. Decide the truth and make all copy agree.
4. **CTA strength is uneven.** Strong: "Start tracking," "Start free trial," "Add transaction →." Weak/generic: "Get started →," lone "Next." Acceptable in-app, but the strong ones show the better pattern (verb + outcome).

---

## What's working (keep)

- **Blame-free errors** (fundamental-attribution-aware): "We couldn't read that — try the detailed form," "Something went wrong." Never blames the user. ✅
- **Outcome-led microcopy:** "spot where money leaks," "in 3 seconds," "see your spending patterns." Leads with benefit, then mechanism — exactly the documented voice.
- **Help articles** are calm, precise, and privacy-forward without virtue-signaling — model Sage voice.
- **Privacy claims** are concrete and compliant ("no accounts, no servers, never leaves your device").

---

## TOP 5 ACTIONABLE IMPROVEMENTS

1. **Purge developer artifacts before submission (P0).** Rewrite/remove `general.language_hint` and `about.privacy_hint` — neither should ever ship. (Submission-readiness, not just polish.)
2. **Fix the brand name everywhere (P0).** Replace "FinanceTracker" with "Budget Crab" in `about.app_name`, `settings.privacy.subtitle`, and `pdf.report.title` (the PDF one is externally shareable — highest visibility).
3. **Drop "smart"/"power features"; switch "we" → on-device actor (P1).** Rewrite `dashboard.day0.title` ("Insights unlock as you track"), `paywall.subtitle`, and the "we figure out / we'll do the rest" lines to "Budget Crab … on your iPhone." Aligns voice rules and *strengthens* the privacy claim.
4. **De-duplicate the Dashboard empty state + finish the Account rebrand (P1/P2).** Keep one empty-state copy set; fix `edit.source.picker` "Source" → "Account."
5. **Reconcile the language-restart story + prune dead analytics keys (P2).** Make `help.language_change.body` and the (now silent) restart strings agree; remove superseded `analytics.chart.*`/legacy keys to shrink the translation surface.

---

**Bottom line:** the voice is genuinely on-brand and the dangerous-claims discipline is excellent. The real risks are **not tone — they're leaks**: an internal product name and two developer TODO strings that are currently set to ship to users. Those are quick, high-value fixes that also happen to be submission-readiness items.
