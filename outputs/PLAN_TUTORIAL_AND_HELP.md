# PLAN — the re-playable tutorial and the annotated Settings screenshots

**Created 2026-09-12.** There was no tutorial plan document before this one; the idea lived as two
lines of backlog (`SUBMISSION_RUNWAY.md` v1.0.1 backlog, *"Visual Help & Tips: annotated
screenshots … Partly redundant with the live coach-marks → lower priority"*) and as GROUP 2 of
`PROPOSAL_1_0_5_SCOPE.md`, which deliberately proposes **no new teaching mechanism at all**.

This file exists because the case for the work stopped being a principle and became a case.

**Nothing here is designed yet. Nothing here is scheduled.** This is the evidence and the
acceptance test, written down *before* the design, so the design can be judged against something it
did not choose for itself.

---

## 1. THE EVIDENCE

### 1.1 What happened

**Eliel** — Spanish, 1.0.4 build 8, the first written contact from a real App Store user — asked
three things. Paraphrased here only where marked; the request itself is his:

- **a savings balance**
- what am I spending
- what is my income

### 1.2 Two of the three are already answered, and answered well

Not adequately. *Well.* This is not a feature gap:

| His question | What ships today |
|---|---|
| what am I spending | Monthly budget with **safe-to-spend** and a per-day remainder; dashboard month totals |
| what is my income | Analytics **Income•Expenses**, 12-month horizon |
| (neither, but adjacent) | Per-category **monthly limits**, with a weekly notification |

Only the savings balance is genuinely absent. It is recorded as **one data point, n=1**, in
`DEMAND_RESEARCH_AND_ROADMAP_2026-07.md` §1.3 — in the Signal #7 corpus, explicitly **not** on the
roadmap.

### 1.3 He had used none of it

From his usage summary: **under a month** installed · **0–10 transactions** · no splits · no
recurring · **no limits** · no voice · no CSV · no export.

**That is the finding.** Two of his three questions have shipped, working, well-designed answers,
and he reached none of them. He wrote to support instead.

### 1.4 The second piece of evidence, and it is about us

**Writing his reply required reading `Localizable.strings` to name the five steps to a feature that
ships and works.** Not to find out whether it existed — to find out what the screen calls it, and
in what order the taps go.

He does not have those files. **He has a screen.**

If the path is only reconstructible from the string table, the screen is not carrying it.

---

## 2. What this evidence does and does not license

**It licenses:** treating discoverability as the constraint on this app's value, on a real case
rather than on a principle. Every feature named in §1.2 is shipped, tested and translated, and for
this user it earned nothing.

**It does not license:**

- **Building a savings balance.** One request is not demand. §1.3 of the demand roadmap says so at
  length, and it says so *in the row that already lost its evidence once*.
- **Reading his request as demand for safe-to-spend.** He asked for a savings balance — a stock.
  Safe-to-spend is a flow. Different numbers, different questions. The citation protocol in
  `CLAUDE.md` exists because this project has already lost claims to exactly this kind of drift.
- **Concluding the coach-marks failed.** See §3 — we cannot tell, and that is the problem.
- **Generalising from n=1.** This is one user. What it changes is that the discoverability argument
  now has an instance attached to it, so it can be tested instead of asserted.

---

## 3. What already exists, and the question it cannot answer

The first-run flow is **live and already re-playable**:

- `OnboardingCoordinator` — greeting → three coach-marks → first win.
  `steps = [.quickAdd, .budget, .analyticsTab]` (`OnboardingCoordinator.swift:31`).
- Settings ▸ Tutorial & Sample Data ▸ **"Replay tutorial"** (`GeneralSettingView.swift:~415`)
  clears `hasSeenFeatureTour`, resets the rating gate and posts
  `.budgetCrabReplayOnboarding` — **immediately**, not next launch.
- The retired 3-screen carousel is gone; `tutorial.page1–3` are orphaned strings
  (`PROPOSAL_1_0_5_SCOPE.md` §1.3, pending deletion). Only `tutorial.page3.demo_offer` is live.

**So the tour already has a `.budget` step, and this user still did not find the budget.**

**We cannot tell why.** Did he skip the tour, never see it, or see it and not retain it? Nothing we
hold distinguishes those. **That is the first thing this work has to fix, and it is cheaper than any
of the design.** A tutorial whose completion, skip and replay are not observable cannot be
iterated — it can only be re-guessed. `FeatureUsageSignals` already carries the
"has the user ever used X" instrument that produced §1.3's usage summary; the teaching flow needs
the same treatment before it is redesigned, not after.

---

## 4. THE ACCEPTANCE TEST — pre-registered, before the design exists

Written now so the design cannot pick its own exam.

> **A new user, starting from a cold install, must be able to answer
> "how much do I have and how much am I spending"
> and reach BOTH the monthly budget AND a per-category limit,
> WITHOUT writing to support and WITHOUT a reply that names a five-tap path.**

Conditions, so it is a test and not a hope:

1. **His question, not a rewritten one.** "How much do I have and how much am I spending" is the
   prompt, verbatim. It is not narrowed to "find safe-to-spend", which would tell the tester the
   answer.
2. **Both destinations.** The budget *and* a category limit. Category limits are the 1.0.3 feature
   §1.2 of the 1.0.5 proposal calls *"effectively unshipped"*; if the teaching surface does not
   reach them, it has not done the job this evidence describes.
3. **In Spanish, at least once.** The one user we have is `es`. Testing only in `en` tests a
   different product (`project_localization_coverage`; the tutorial's strings ship in five locales).
4. **Replay counts as a pass, first-run does not count as the only path.** The point of a
   re-playable tutorial is the user who did not need it on day 0 and needs it on day 9 — which is
   this user exactly, at 0–10 transactions in under a month.
5. **A null result is reportable.** If a redesigned tutorial does not move this, that is the
   finding, and it belongs in this file next to the evidence — not quietly absorbed into the next
   design round.

---

## 5. The unresolved conflict, stated rather than settled

The two halves of this work are not equally supported, and one of them is contested **by our own
files**:

- `outputs/ANALYTICS_COLOR_RESEARCH_SYNTHESIS.md` §4: *"research says interactive + contextual
  beats static annotated screenshots"* → *"lead with TipKit + interactive demo; keep annotated
  screenshots only as secondary reference"*.
- `SUBMISSION_RUNWAY.md` reaches the same ranking from a different direction: annotated screenshots
  are *"partly redundant with the live coach-marks → lower priority"*.
- `PROPOSAL_1_0_5_SCOPE.md` GROUP 2 goes further and proposes **no new mechanism** for four of six
  capabilities, on the rule *"does the user need to be TOLD this, or to be able to FIND it at the
  moment they want it?"* — with the observation that a visible affordance costs nothing when
  ignored while a hint costs attention every time it fires.

**⚠️ That first citation is not currently usable.** It is a NotebookLM claim of the exact vintage
the 2026-08-13 audit re-asked, and **21 of 64 attributed claims did not survive a clean re-ask**
(`AUDIT_NOTEBOOKLM_CITATIONS_2026-08-13.md`). It has not been re-asked. Before it is allowed to
kill the annotated-screenshots half, it gets the protocol in `CLAUDE.md`: `--new`, non-leading
("What do the sources say about static annotated help versus contextual in-app teaching?"), the
**sentence pasted**, and a negative control. If it fails the re-ask, the ranking it produced falls
with it and the two halves go back to even.

**The third argument stands on its own regardless**, and it is the strongest thing in this section:
GROUP 2's rule did not come from a notebook. Note also that it cuts *against* a bigger tutorial —
which is why §4's acceptance test is written as "can the user get there", not "did the user see the
lesson". **A change that makes the budget findable from the screen passes §4 without a tutorial at
all, and that outcome is allowed.**

---

## 6. What happens next, in order

1. **Instrument the teaching flow** (§3) — seen / skipped / completed / replayed. Cheap, and
   nothing downstream is interpretable without it.
2. **Re-ask the contested citation** (§5) under the protocol. It decides whether the annotated
   screenshots are a co-equal half or a secondary reference.
3. **Only then design**, against §4, which is already written and does not move.

**Not scheduled against any release.** 1.0.5 build 10 is in review; this is post-verdict work and
it is not a hotfix candidate.

---

## 7. What is NOT claimed

- Not claimed that the coach-marks failed this user. Not measured — §3.
- Not claimed that a tutorial would have kept him. He is one user, still active, and nothing here
  measures retention.
- Not claimed that the savings balance should be built. §1.3 of the demand roadmap is one data
  point and says so.
- Not claimed that the annotated screenshots are the right mechanism. §5 is open on purpose.
