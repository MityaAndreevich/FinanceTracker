# The free/paid line, re-read against the citation sweep

**Date:** 2026-08-13 · **Mode:** read-only. **Nothing repriced, nothing gated, nothing built.**

**Boundary, stated first so no reader has to wonder:** the shipped free widget is **not** in question
and must not be clawed back. Users have it. Removing a shipped free capability is precisely the trust
damage this programme exists to prevent, and it would cost more than the feature is worth.
**Path A's nine confirmed figures are not reopened here.**

The question this answers is the narrower one: **did the reversed premise shape anything else in the
free/paid line, and how should the next feature of that class be priced?**

---

## 0. Answer

**The inversion itself touched exactly one capability — the widget.** No other rationale cites that
reading.

**But the failure it belongs to is not isolated, and the pattern is the finding.** Of the six free
capabilities in `MONETIZATION_FREE_PAID_SPEC.md`, **three** rest on a claim that did not survive the
sweep, and **all three fail in the same direction: toward giving more away.**

| Free capability | Stated rationale | Status after the sweep |
|---|---|---|
| Unlimited manual entry + Quick Add | retention + habit + honest brand | No notebook citation — a **brand** argument, honestly framed |
| **Full history + basic trends** | *"Gating history = retention killer, 'hostage' sentiment"* | **NOT IN SOURCES** — rejected by `0e5f6bb9` **and** `a16f8bf7` |
| Basic current-month analytics | (none given) | No notebook citation |
| **Basic home-screen widget** | *"widgets ranked LOW paid-WTP"* | **INVERTED** — sources call widgets a *"differentiator for retention and willingness to pay"* |
| CSV export | *"deliberate deviation from one source that suggested gating export"* | **Sourced, and knowingly overruled — the model to copy** |
| **Capped accounts + categories** | *"Goodbudget model: free capped at ~2 accounts / ~15–20 categories"* | **NOT IN SOURCES** |

**Three of six free capabilities were justified by evidence that does not exist, and not one of the
failures errs toward gating more.** Random citation decay would scatter in both directions. This
does not. It reads as motivated reasoning — reaching for a citation to support a decision already
made on instinct, and stopping looking once one was found.

That is the answer to *"did it shape anything else"*: **not the inversion, but the habit that produced
it.**

---

## 1. The three, in detail

### 1.1 The widget — the inversion (**do not act on this one**)

`MONETIZATION_FREE_PAID_SPEC.md` keeps the widget free because *"widgets ranked LOW paid-WTP
('aesthetic delight, not killer feature'); keep as a retention/word-of-mouth signal."*

Asked clean, `0e5f6bb9` says home-screen widgets are highly requested native features and a
*"differentiator for retention and **willingness to pay**"* — and `a16f8bf7` has nothing on it at all.
The parenthetical *"aesthetic delight, not killer feature"* appears in neither.

**The retention half of the rationale is right; the WTP half is exactly backwards.** The conclusion
(free widget) may still be correct on brand and word-of-mouth grounds — a free widget is a visible,
recurring advertisement on the user's home screen, and that argument stands on its own without the
WTP claim. **Keep the decision, discard the reasoning, and do not re-derive it from a source that
says the opposite.**

### 1.2 Full history free — the most consequential of the three

*"Gating history = retention killer, 'hostage' sentiment, weak converter (Credit Karma lesson)."*

**NOT IN SOURCES**, and unusually well tested: it was put to **both** plausible notebooks — the
pricing corpus and the behavioural-psychology corpus — and rejected by each independently.

This is the spec's headline reversal from v1 (*"history is NO LONGER the lead gate"*), so a v1→v2
inversion of the primary monetization gate was made on an unsourced claim. **It is also the free
capability with the largest revenue consequence**, since history is the classic gate in this category
and the one competitors actually use.

**Not a recommendation to gate it.** The anti-hostage argument is a genuine brand position and
coherent with *"your data is never hostage"* and free CSV export. **The correction is to stop calling
it research.** It is a brand decision, and brand decisions do not need a citation — they need to be
labelled as brand decisions so nobody later "validates" them into a number.

### 1.3 The cap calibration — the one live gate

*"Goodbudget model: free capped at ~2 accounts / ~15–20 categories → upgrade at the 'maintenance
wall'."* **NOT IN SOURCES.**

This one matters more than the other two because **it is the forcing gate** — the only place in the
line where a number directly triggers a paywall.

**In fairness, the shipped implementation is consistent with the model it cites**, which I checked
rather than assumed: `FreeTierLimits.maxAccounts = 2`, `maxCustomCategories = 3` **on top of 13
seeded defaults that are always available** — 16 total categories, inside the quoted 15–20. The
implementation did not drift. **The model it faithfully implements is simply not from the sources.**

So the live gate's calibration currently rests on a remembered competitor detail. That may well be
accurate about Goodbudget — it is a checkable, external, first-party fact. **It just was not checked,
and it is presented as though it had been.**

### 1.4 CSV export — the counter-example, and the standard

*"Deliberate deviation from one source that suggested gating export: our anti-dark-pattern brand
outweighs the marginal conversion."*

**This is the only rationale in the free/paid line that survives contact with the sweep intact, and
it survives because of how it is written.** It names the source, states that the source recommends
the opposite, gives the reason for overruling it, and accepts the cost. Nothing to correct — there is
no gap between what it claims and what it did.

**Every other line in the spec should read like this one.** The failure mode is not "we disagreed
with the research"; it is "we agreed with research that did not exist."

---

## 2. How to price the next feature of that class

**The class:** native platform surfaces that increase engagement without adding data — widgets, Apple
Watch, Siri/App Intents, Live Activities, Control Center controls, Lock Screen. Three are already
shipped free (widget, Siri, quick-add surfaces), and **all three were placed using the reversed
premise or none at all** — backlog row #5's citations both failed.

**The rule going in, given the corrected reading:**

1. **Default a native surface to a premium candidate, not to free.** The sources treat these as WTP
   differentiators. That is the opposite of the assumption we have been operating on, and the next
   one should start from the corrected position.
2. **Free is still often the right answer — but it must be argued, not assumed.** A widget is a
   recurring home-screen advertisement; Siri is a retention hook. Those are real arguments. Make
   them explicitly, in the CSV-export format: *what the evidence says · what we are doing instead ·
   what it costs us.*
3. **Never infer WTP from how small a feature feels to build.** "Aesthetic delight, not killer
   feature" was an engineering intuition about effort that got written down as a market finding
   about willingness to pay. That substitution is the whole defect in miniature.
4. **Separate the two questions the widget rationale fused.** *Does this drive retention?* and *would
   someone pay for it?* have different answers and different evidence. The sources say the widget
   scores on **both**; our spec collapsed them into one and got the second one backwards.

**Concretely, and without reopening anything shipped:** the next surface of this class — an Apple
Watch app or a Live Activity — should enter the roadmap with an explicit tier decision and a labelled
rationale, rather than inheriting "native surfaces are free" from a line of reasoning now known to be
inverted.

---

## 3. What was deliberately not done

- **No clawback.** Per the brief, and because it is right.
- **Path A untouched.** Its nine figures are confirmed; nothing here bears on price points.
- **No repricing proposed.** Every capability above keeps its current tier. The deliverable is which
  rationales are load-bearing and false, not a new line.
- **PREMIUM-side rationales not swept in full.** Two are already known to be affected and are
  recorded for completeness rather than acted on: proactive alerts cite *"gain-frame lifts conversion
  +23%"* (the source says **outcome-based** messaging — the number is real, the mechanism renamed),
  and the *"household/partner sharing — HIGHEST WTP"* tentpole is the fabricated claim, already struck
  from backlog row #9.
