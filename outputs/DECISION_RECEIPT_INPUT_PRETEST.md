# PRE-REGISTERED DECISION RULE — receipt / photo input

**Written:** 2026-08-02 · **Written BEFORE any data existed.** That is the entire point of this file.
**Status:** registered, not yet resolved. The instrument (feedback usage summary) ships in 1.0.4.
**Supersedes:** the "v1.1 headline differentiator" ranking in `FEATURE_PREP_BACKLOG.md` §Priority-table row 1, which was written 2026-07-02 from demand research, before the 2026-07-19 council reviewed it.

---

## 0. Why this file exists

Two documents in `outputs/` disagreed:

- `FEATURE_PREP_BACKLOG.md` (2026-07-02) ranks photo/receipt OCR **#1**, "headline differentiator", with `SPEC_PHOTO_INPUT.md` ready to build.
- `BRIEF_1_0_3_FEATURE_PACK.md` (post-council 2026-07-19) says **"Receipt/screenshot OCR — n=1 demand, no moat (council: kill)"** and names split transactions as the falsifiable pre-test: *if users never split, we skip the Vision weeks.*

Splits shipped in 1.0.3. 1.0.3 is live. **The test has therefore been running since 1.0.3 shipped, and there has never been any way to read it** — the app has no analytics, and the feedback composer carried no feature-usage signal.

The instrument is now built (1.0.4: an optional, visible, user-removable usage summary in the mail body — see `APP_PRIVACY_ANSWERS.md` §3.12.1). This file fixes the decision rule **before the first data point arrives**, because a threshold chosen after seeing the data is not a test. It is a story.

---

## 1. The sample is biased, and the bias runs toward "build it"

State this plainly every time this file is quoted:

**The sample is self-selected.** It consists of people who opened Settings, found "Tell me what's missing", wrote a message, and sent it. Those are engaged users. **People who write in are not people who churned in week two.** Nobody who deleted the app in week two is in this dataset, and they are exactly the population whose behaviour would argue against building a heavyweight feature.

Splits are an advanced, opt-in behaviour. Engaged users over-represent advanced-feature use. **Therefore the observed split rate is biased UPWARD, and the "build it" threshold below is set high knowing that.** A weak positive is not a positive. If the number comes back in the middle, the answer is not "build it, the signal was there" — the answer is in §4, and it is not build.

There are two further selection layers, both of which must be reported alongside any result:

- **Toggle self-selection.** Only mails whose sender left the summary toggle ON are readable. Privacy-maximalist users are the likeliest to switch it off, and they are plausibly a different population on this exact question. Direction of bias: **unknown**. Do not assume it is small.
- **Language.** The composer localizes into 5 locales; the split rate may differ by market. Report the split by locale if N permits, and do not let one locale carry the verdict.

---

## 2. Precondition — a null result is uninterpretable if the feature is buried

**Verified 2026-08-02, and this is a problem.** Splitting is reachable **only from the edit path**: `AddTransactionView` contains no split UI at all; `TransactionSplit` rows are created solely by `TransactionEditService`, driven by `EditTransactionView`. The real user journey is:

> save the transaction → open it → Edit → scroll to the "Split" section → "Add part"

Four steps, none of which are offered at the moment the user is actually looking at a multi-category purchase (i.e. while entering it).

**This means low split usage has two possible causes — no demand, or no discovery — and the pre-test as designed cannot distinguish them.** That is a real weakness in the council's test, not a quibble.

**Binding rule:** a **KILL verdict under §4 is only valid if the discoverability precondition is met.** Before the first look, one of the following must be true:

- (a) splitting is offered on the entry surface (`AddTransactionView` / Quick Entry), not only in Edit; **or**
- (b) a deliberate discoverability check has been run and recorded, showing that users who would want to split can find it (a coach-mark, a first-run hint, or five observed users).

If neither holds at the look date, a low split rate is **NOT** a kill. It is an untested hypothesis, and the honest action is to fix discoverability first and restart the clock at §3's T0. A high split rate despite poor discoverability is, by contrast, a *strong* positive — the signal survived a handicap.

---

## 3. When to look

The clock does **not** start today. The instrument ships in 1.0.4, which is unbuilt as of 2026-08-02.

- **T0 = the date 1.0.4 becomes available on the App Store.** Record it here when it happens: `T0 = ____________`
- **First look: T0 + 90 days.**
- **Second and final look: T0 + 180 days.** Hard stop. There is no third look.

Calendar estimate, to be replaced by the real T0 + 90 the moment 1.0.4 ships — **this is an estimate, not the rule**: if 1.0.4 ships mid-September 2026, first look ≈ **2026-12-15**, hard stop ≈ **2027-03-15**.

Counting rule: only mails received **after T0** count. Anything earlier predates the instrument.

---

## 4. The rule

Definitions, fixed now:

- **N** = feedback emails received in the window, from **distinct senders**, that include a usage summary block. (Mails with the toggle off are counted separately as `N_off` and reported, but do not enter N.)
- **S** = of those N, the number whose summary reads `Split purchases: yes` (ever-used flag).
- **S6** = of those N, the number whose split bucket reads `6+`.

### 4.1 Is there a readable signal at all?

**N ≥ 25.** Below 25, no proportion in this document is distinguishable from any other: at N = 25 an observed 50% still carries a 95% confidence interval of roughly 32–68%. Below that the interval swallows every threshold here, and any verdict would be noise dressed as a decision.

### 4.2 BUILD receipt input — all three must hold

1. **N ≥ 25**, and
2. **S / N ≥ 0.40** — at least 40% of the most engaged users we have have ever split a purchase, and
3. **S6 / N ≥ 0.15** — at least 15% split *habitually* (6+ purchases), not once out of curiosity.

Clause 3 is the one that makes "a weak positive is not a positive" operational. The OCR case rests entirely on the repeat multi-category purchase — the Amazon-order story from `BRIEF_1_0_3_FEATURE_PACK.md` Item 4. **A population that tried splitting once and stopped does not need Vision.** A signal made entirely of one-time splitters is a curiosity signal, and clause 3 rejects it.

Why 0.40 and not 0.25: the sample is biased upward (§1). For a feature ranked as the *headline differentiator* of a release, 40% among the most engaged slice plausibly maps to somewhere near 15–25% of the actual base. That is still a large number and a defensible reason to spend the Vision weeks.

### 4.3 KILL receipt input — either is sufficient

1. **N ≥ 25 and S / N < 0.20**, or
2. **N < 25 at the hard stop (T0 + 180)** — we went looking, deliberately, with a shipped instrument, for six months, and demand did not show up.

Clause 2 is deliberate and is not a technicality. For a feature this expensive, **absence of evidence, after a purpose-built search, is evidence of absence.** The alternative — "we never got enough responses, so let's build it anyway" — is how the 2026-07-02 ranking happened in the first place.

KILL means: close `SPEC_PHOTO_INPUT.md`, strike row 1 of the backlog priority table, and record the numbers here. It does not mean "never" — it means the next person who proposes it must bring new evidence, not the old spec.

### 4.4 The band in between — DEFER, which is not a soft build

If N ≥ 25 and **0.20 ≤ S/N < 0.40**, or if S/N ≥ 0.40 but **S6/N < 0.15**:

- At the **first look**: DEFER to the second look. Do not build. Do not build a "small version". Do not start the Vision spike "just to de-risk it".
- At the **hard stop**, still in the band: **KILL.** The band resolves down, not up. Two looks over six months landing in the middle is itself the answer.

### 4.5 A positive result unlocks interviews, not the build

This is an addition to the council's test, not a softening of it. Even a clean §4.2 pass tells us *that* people split, never *why*. The summary carries no category names by construction, so it cannot tell us whether splits are being used for multi-category receipts (the OCR case) or for something else entirely — shared costs, reimbursements, splitting a bill with a partner. **Those are different features, and the two most obvious alternatives are cheaper than Vision.**

So: **§4.2 pass → run 10 user conversations → then decide.** The build gate is the conversation, and the pre-test gates the conversation. If the conversations say "I split because I share costs with my partner", the correct build is couples/shared costs (backlog row 9), not OCR — and that would be a genuine, and cheaper, win from this test.

---

## 5. Recording the result — fill this in at the look, not before

| | First look (T0+90) | Hard stop (T0+180) |
|---|---|---|
| Date looked | | |
| N (with summary) | | |
| N_off (toggle off) | | |
| S | | |
| S6 | | |
| S/N | | |
| S6/N | | |
| §2 precondition met? | | |
| **Verdict** | | |

**Do not edit §4 after data starts arriving.** If §4 turns out to be wrong, say so in a new dated section below this one, with the reasoning, and leave the original thresholds visible. A threshold quietly moved is a threshold that never existed.

---

## 6. Dependencies this decision touches

- **`docs/PRIVACY_POLICY.md` currently describes receipt OCR as a shipping feature** — §2 ("If you grant the App permission to access the camera (for the optional Receipt OCR feature)…") and §11 ("Vision — for on-device receipt OCR (Premium feature)"). **The app requests no camera permission and links no Vision framework.** The published policy is describing a data flow that does not exist and pre-commits the product to the exact feature this file is meant to gate. **This must be corrected regardless of the verdict, and before 1.0.4 submission.** (The same document still calls the app "Vela" throughout, and describes iCloud sync as available — sync is 1.0.4 and unbuilt. Flagged 2026-08-02; not fixed in that pass, as a published legal document's wording is the founder's call.)
- A KILL verdict makes `NSCameraUsageDescription` unnecessary — see `APP_PRIVACY_ANSWERS.md` §1.5, which flags the Photos category flipping to Yes if OCR is ever built.
- `SPEC_PHOTO_INPUT.md` stays on disk either way as the record of what was specced and why it was or was not built.
