# DECISION — one 1.0.4 with sync, or 1.0.4 fixes now and 1.0.5 sync?

**Date:** 2026-08-08 · **Recommendation: (b) — split it.** 1.0.4 = the fixes + split
discoverability, submitted within ~a week. 1.0.5 = sync. Reasoning below, including the
strongest arguments against.

---

## 0. Ground facts, dated

| Fact | Evidence |
|---|---|
| 1.0.3 build 7 submitted **2026-07-27** | `v1.0.3-build7`, ARCHITECTURE.md §submission ledger |
| So 1.0.3 has been live ~**2 weeks**, not months | same |
| The rollback ladder for V2→V3 **does not run at all** | `AUDIT_V3_ROLLBACK_READINESS.md` §0: "Nothing in the §10 ladder runs… no backup on disk to restore from" |
| The pre-V2 backup is **already deleted** on every live 1.0.3 device | same, §2 (`deleteAfterConfirmedGood` on the second good launch) |
| Sync design exists, unbuilt: 536 lines | `DESIGN_ICLOUD_SYNC_1_0_4.md` |
| V3 schema designed, unbuilt: 170 lines | `DESIGN_V3_SCHEMA_FREEZE.md` |
| CloudKit **production schema is additive-only forever** | sync design §1.3 |
| Split discoverability: 2 changes, 3 files, **one new key**, no new state | `PROPOSAL_SPLIT_DISCOVERABILITY_1_0_4.md` §2 |
| The 12-site save classification is **contingent on `cloudKitDatabase: .none`** and "must be redone for 1.0.4, not inherited" | `OVERNIGHT_2026-08-05.md` Item 2 |

**Data gaps, stated rather than papered over.** I have no active-install or feedback-rate number,
and no evidence of user demand for sync. Both matter below and both are flagged where they bite.

---

## 1. The case for (a) — one release carrying fixes and sync

1. **One review cycle, one metadata pass, one What's New.** Two releases genuinely cost two of
   each. Apple review is typically 24–48h, so the cost is coordination, not calendar.
2. **The save-site classification has to be redone for sync anyway.** If it must be re-audited
   under a mirroring save path, doing it once — with sync already on — avoids auditing twice.
3. **One migration event.** Users take one schema change rather than two, and the V3 migration
   and the sync switch-on are verified together, as they will actually be experienced.
4. **No half-state.** Nothing ships promising a foundation that isn't there.

Point 2 is the only one with real force, and §2 turns it around.

---

## 2. The case for (b) — and the argument I think is decisive

**The verification argument.** The overnight report's own conclusion is that the 12-site save
classification holds *because* `cloudKitDatabase` is `.none`, and must be redone if it changes.
Bundling sync with the fixes therefore ships those fixes into a save path whose verification no
longer applies. You do not save an audit by bundling — you invalidate the one you already did,
and ship the fixes on the strength of it. Shipping under `.none` banks each fix under exactly the
conditions it was proven in, and gives the sync release a verified baseline to differ from.

**There is a live, user-visible defect in the fix set.** The i18n conversion is not hypothetical:
on 1.0.3 today, any user who switches language gets English notification bodies for days
afterwards (frozen at schedule time, delivered while the app isn't running) and an English-chromed
PDF they may forward. The app ships five locales and the language picker is a first-class
feature. (a) leaves that in the field for months.

**Risk isolation.** (a) puts, in one release: a V3 migration whose rollback ladder does not exist,
on every live device whose backup is already deleted; the first CloudKit write; and a production
schema push that is additive-only forever. If that release goes wrong, the fixes are implicated
too and you cannot separate them. (b) makes 1.0.4 a no-schema-change release.

**Four unstarted gates, and one must be built rather than fixed.** The ladder audit found no rung
runs. That is not a patch; it is building the guarded path and then walking the §11 drill — the
same drill that gated 1.0.3.

**A smaller point that still counts:** five shipped strings claim "100% on-device". They stay
*true* until sync ships. And the privacy-policy correction (which removes the unshipped sync
promise) can go out alongside 1.0.4 instead of waiting.

---

## 3. Dates

**(b)** — the only unbuilt piece is split discoverability (one key, no new state), plus
regression and the TestFlight drill.
- Submit **~2026-08-13 to 2026-08-18**; available **late August 2026**.

**(a)** — I cannot support a date with evidence, and say so plainly. Four gates, one of which the
audit shows must be built from nothing, plus a one-way production schema push and a consent
screen. Honest range, explicitly a guess needing validation: **October–December 2026**.
The `mid-September 2026` guess in `DECISION_RECEIPT_INPUT_PRETEST.md` §3 predates the rollback
audit that found the ladder absent, and should be treated as stale.

**So (a) delays every fix already written by roughly two to four months.**

---

## 4. Does starting T0 sooner help or hurt?

Asked directly, so answered directly: **mildly bad, and not decisive — but there is a free move
that removes the question.**

It hurts for one specific reason, and it is not "the window is shorter" (it isn't).
`DECISION_RECEIPT_INPUT_PRETEST.md` §4.3 clause 2 makes **`N < 25` at the hard stop a KILL** —
not "inconclusive", a KILL. N accrues as install base × time × feedback rate × toggle-on rate.
The install base two weeks after 1.0.3 is the smallest it will ever be, so an early T0 maximises
the chance the 180 days end with N < 25 and the rule returns KILL meaning *"nobody wrote in"*
rather than *"nobody splits"*. §5 allows no third look.

**I do not have the number that settles this** — no MAU, no feedback rate. Sizing it as an
explicit guess: 25 mails with the toggle left on, at an indie in-app feedback rate of roughly
0.1–0.5% of MAU over six months, needs something like 5 000–25 000 MAU. A two-week-old 1.0.3 is
probably not there. **This needs validating against App Store Connect before it is relied on.**

**Why it is still not decisive:** the council already provisionally killed OCR on n=1 demand. A
low-N kill therefore lands on the same verdict that already stands. What is lost is only the
option value of a BUILD signal — real, but small if demand really is low.

**The free move, and it is time-limited.** Amend §4.3 clause 2 **now**, before 1.0.4 ships, so a
low-N result reads as *"no data, no verdict"* rather than KILL. That is legitimate today
precisely because no data exists; the document forbids exactly this edit once mails start
arriving. Make that change and T0 timing stops mattering, which is a better outcome than
choosing a release date to protect a measurement.

Holding split discoverability back to keep T0 unstarted is the alternative, and I do **not**
recommend it: it lets the instrument dictate the product, and the change is a genuine (if modest)
usability fix.

---

## 5. Recommendation

**(b).** Ship 1.0.4 late August: the save-site fixes, the i18n conversion, the instrument
ordering fix, split discoverability, and the privacy-policy correction. No schema change, no
CloudKit. Then take sync as 1.0.5 through its four gates in order, starting with the rollback
ladder, because nothing else in that program is safe until a failed migration can be recovered.

Before submitting 1.0.4, do two things that are cheap now and impossible later:
1. Amend §4.3 clause 2 so low N is inconclusive, not a kill (§4 above).
2. Record at T0 that the §1.1 usage-signal ordering fix is live — already stubbed in the receipt.

**What would change this recommendation:** evidence that users are actively asking for sync
(I have none, and did not look for it — it is checkable in reviews and support mail), or the
rollback ladder turning out to be days rather than weeks. If sync were within two weeks of done,
(a)'s single-migration argument would start to outweigh the verification argument in §2.
