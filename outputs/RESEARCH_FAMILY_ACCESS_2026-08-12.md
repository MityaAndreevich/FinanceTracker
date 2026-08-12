# RESEARCH — family / shared access (backlog #9)

**Date:** 2026-08-12 · **Status: RESEARCH ONLY. No design, no code, no decision taken.**
**The sync program is untouched by this document and still sits ahead of it.**

Method rule applied throughout, from `DEMAND_RESEARCH_AND_ROADMAP_2026-07.md`: *supply-side evidence
is not demand evidence.* Leg 1 (demand) was run and written before Leg 2 (competitors) was opened.

---

## 0. THE HEADLINE

> ### Measured demand for shared access: **0.04 % – 0.14 %** of 4,904 competitor reviews.
> ### That is **BELOW** device sync's 0.28 %, which this project already ruled "no signal".
> ### Confidence: **MEDIUM-LOW**, and it rests on **one channel**.
>
> **And both of backlog row #9's demand citations fail verification.**
>
> | Citation in `FEATURE_PREP_BACKLOG.md:32` | Verdict |
> |---|---|
> | "reviews **69 rage**" | **FALSE.** 50 of the 69 are the English idiom *"a couple of years / weeks / seconds"*. The theme tagger matched the word **couple**. Of the 19 remaining, ~9 are genuinely about a sharing feature. |
> | "NotebookLM: **decisive at premium price**" | **NOT IN SOURCES.** Asked directly, with conversation history excluded, notebook `73afc9a4` answered: *"Claims made in our previous conversation regarding joint budgeting as a 'decisive driver' for higher retention or its impact on long-term 'stickiness' are **not in the sources**."* |
>
> The second one is the more serious failure. The "decisive at premium price" claim was almost
> certainly **generated in an earlier session of our own and then cited back to us as literature** —
> the notebook's first answer today repeated it with a `[History]` marker, and only disowned it when
> explicitly told to ignore history. That is the zero-row rule and the supply-side rule combined:
> an instrument reporting confidently about something it never measured.

**Nothing here says couples budgeting is unreal.** It says we have **no measured demand from
anyone who could become our user**, and that row #9 was scored on two citations that do not hold.

---

## LEG 1 — DEMAND

### 1.1 Corpus and denominator

`review_mining_output/reviews_20260702_135538.csv` — 4,972 rows, 16 apps, US only.
Excluding the 68 rows from **Barri Send Money & Remittances** (a remittance app, not a budgeting
app, flagged in a prior audit and never removed) gives the standing denominator:

**N = 4,904 usable rows, 15 apps.** Band 1-2★ = 1,804. This is the same denominator the 0.28 %
sync figure uses, so the two numbers are directly comparable.

### 1.2 The "69 rage" number is an artefact of the word "couple"

The corpus carries a pre-computed `couples_shared` theme tag: **237 rows**, of which **68** are
1-2★ (69 with the remittance app included — that is the backlog's number).

Reading them, the tagger fires on the idiom:

- *"I came over here **a couple of years** ago because Mint dissolved"* — Rocket Money, 1★
- *"what used to take **a couple seconds** now takes 5x that"* — YNAB, 1★
- *"reclassifying transactions every **couple months**"* — Simplifi, 1★

Splitting the 237 by whether any relationship/sharing language is present at all:

| | total | 1-2★ | 4-5★ |
|---|---:|---:|---:|
| has relationship/sharing language | 106 | **18** | 81 |
| **only the "a couple of" idiom** | **131** | **50** | 70 |

So **50 of the 68 "rage" rows are not about couples at all.** Hand-reading the surviving 18, a
further 9 mention a spouse or family only incidentally (a billing scam, a UI complaint, a data-loss
report). **~9 rows are genuinely about a sharing feature — 0.18 % of the corpus, and every one of
them is a complaint about an implementation, not a request for one.**

### 1.3 The four buckets you asked for

Built by searching the **whole corpus** — not the broken theme tag — for sharing subjects
(`spouse|husband|wife|partner|fiancé|boyfriend|girlfriend|joint account|shared account|shared
budget|household|multi-user`, idiom excluded), then hand-reading every hit that also carried
request or absence language.

**162 rows (3.30 %) mention a sharing subject at all. 132 of those (2.69 %) are 4-5★.**
The topic is overwhelmingly present in *praise*, not in complaint.

| Bucket | Rows | Rate vs N=4,904 |
|---|---:|---:|
| **A. Wants it, cannot get it** — true unmet demand | **2 – 7** | **0.04 % – 0.14 %** |
| **B. Has it and it is broken** | ~9 | 0.18 % |
| **C. Privacy fear about a partner seeing things** | **1** | **0.02 %** |
| **D. Billing / seat complaints** | 2 | 0.04 % |

**Bucket A is the only demand-side number**, and it is a range because the boundary is genuinely
ambiguous. The two unarguable rows:

- PocketGuard 4★ — *"I cannot log on to multiple devices at one time, nor can I share my budget. My
  spouse and I use this together and it would make things so much easier."*
- Goodbudget 4★ — *"it would be nice for my wife and I to be able to login to the same budget on
  different phones."* (Goodbudget **has** this — so it is arguably a discoverability failure, not
  unmet demand. Counted in the upper bound only.)

The other five are adjacent wants — automatic **splitting** of shared-account transactions, or
partner-reimbursement maths — which are *not* shared access. Counting them charitably gives 0.14 %.

**Bucket C is the finding I did not expect.** The fear that motivated Honeydue's entire
per-transaction hiding feature is **essentially unattested**: a single 4★ Wallet review — *"My wife
hates this app since now I am able to see [her spending]"* — in 4,904 rows. If per-transaction
privacy is the reason to build this, the corpus does not support it.

### 1.4 Comparison to sync, on the same denominator

| Signal | Rate | Prior verdict |
|---|---:|---|
| `sync_breakage` theme (a *problem*, not a want) | 104 / 4,904 = 2.12 % | — |
| **Device-sync demand**, after excluding bank aggregation | **0.28 %** | *"no sync signal in either readable channel"* |
| **Shared-access demand (bucket A)** | **0.04 % – 0.14 %** | this document |

**Shared access measures at half to one-seventh of a signal already judged too weak to act on.**

### 1.5 The confound, and which way it cuts — the corpus answers this itself

The stated confound is real: these are **bank-aggregator** users. Our population is manual-entry,
privacy-motivated, no bank links. It cuts both ways, and the honest reading needs both:

**Cuts AGAINST us (demand here overstates ours).** Much of the sharing conversation is inseparable
from bank linking — *joint accounts*, Plaid MFA for two spouses, "link a specific joint account and
reduce expenses by half". Those wants **cannot exist in our app**, because our `Source` is a label
with no feed behind it. Several bucket-A/B rows evaporate on contact with our architecture.

**Cuts FOR us (demand here understates ours) — and the corpus gives a testable handle on it.**
Sharing salience per app, normalised:

| App | sharing-subject rate | model |
|---|---:|---|
| **Goodbudget** | **10.8 %** (54/500) | **manual entry, envelope** |
| Monarch | 6.0 % (3/50) | aggregator |
| EveryDollar | 6.0 % (30/500) | aggregator (+manual) |
| YNAB | 4.2 % (21/500) | aggregator |
| PocketGuard | 3.3 % (15/450) | aggregator |
| Rocket Money | 0.8 % (4/500) | aggregator |
| Albert | 0.6 % (2/350) | aggregator |

**Goodbudget — the one manual-entry envelope app in the corpus, and the closest analogue to Budget
Crab — has the highest couples salience by a factor of ~1.8 over the next app and ~13 over Rocket
Money.** 48 of its 54 sharing mentions are 4-5★ praise. Representative:

> *"It functions for us as a **digital checkbook register that synchronizes**. I record what I spend
> from our shared accounts on my phone and then she does the same. As long as we remember to record
> the transactions right away, we're always on the same page."* — Goodbudget, 5★

> *"It's simplistic and **shared in real time**. Functions well on both our devices — apple for me,
> android for him. **I handle all the household finances** so being able to see all the spending
> being done is great."* — Goodbudget, 5★

**This is the single strongest piece of evidence in the document, and it is still not demand.** It
is satisfaction among people who already have the feature, in the app most like ours. It says the
*use pattern is real and durable for manual, hand-entered, two-person ledgers* — which is precisely
the pattern our architecture could serve. It does not say our users are asking.

**On balance I read the confound as roughly neutral to mildly favourable**: we lose the
bank-linked wants, we gain the manual-entry segment where salience is highest. It does not move
0.04–0.14 % anywhere near a build threshold.

### 1.6 Our own channels — and the honest statement about them

- **App Store reviews: 2, both ours.** Zero mentions of sharing, couples, partner or family. Two
  written reviews cannot measure anything; they are recorded so the count is not mistaken for
  silence-as-evidence.
- **support@budgetcrab.app: still unread.** Unchanged since the last demand review. **I cannot
  read it** — no credentials in this environment, and the founder must.

> **Therefore, as instructed: the demand finding rests on ONE channel — a competitor review corpus
> for a product category we are not in.** No first-party demand evidence exists for this feature,
> in either direction. Until the mailbox is read, "no demand" and "we have not looked" are not
> distinguishable from our side.

### 1.7 What the domain literature says couples fail at (notebook `73afc9a4`)

Source-grounded, with the unsupported retention claim withdrawn:

- **Partner-approval is the barrier, not the feature.** Couples fail on *"differing preferences for
  complexity versus simplicity"*, creating a barrier where **one partner rejects a tool the other
  finds useful**. The binding constraint is getting the second person to adopt at all.
- **Maintenance fatigue kills shared budgeting**, with quitting *"within two weeks if the friction
  of logging and recategorizing feels greater than the reward."* **Shared manual entry doubles the
  surface on which that fatigue can occur** — two people must both keep logging.
- **Autonomy matters:** abandonment occurs where there is *"a lack of autonomy or control over what
  data is shared with the partner."*
- **Retention: no source-based evidence.** Directly probed. Tiller notes high retention without
  attributing it to collaboration; every other source is a "best for couples" designation, which is
  editorial, not data.

The literature's implication is uncomfortable for a manual app: the failure mode is **the second
person not keeping up**, and manual entry makes that worse, not better.

### 1.8 Pricing (notebook `0e5f6bb9`)

- **Sold separately / included / higher tier:** sources are **silent on the consumer norm**. Seat
  adds are documented as a **B2B expansion playbook**, and seat count is named as a *"Good/Better/
  Best"* constraint used to push users up a tier.
- **No figures exist** for the churn or ARPU effect of a second consumer seat. Explicitly "not in
  sources".
- The one transferable datum: **35 % of annual-plan cancellations happen in month 1**, and the
  sources suggest upselling multi-seat **later in the lifecycle (month 2+)**, not at purchase.

**Observed competitor practice contradicts the "sell the seat" instinct entirely** — see §2.5.
Monarch and YNAB both include partners **free** in one subscription. Charging for a second seat
would put us on the wrong side of every player we compete with.

---

## LEG 2 — SHAPE (primary sources only)

Vendor documentation and support/terms pages. No comparison blogs.

### 2.1 The five models

| | **Unit of sharing** | **Can a partner hide?** | **Symmetric?** | **Invite / removal** | **Price** |
|---|---|---|---|---|---|
| **Honeydue** | The **account** (bank account) | **Yes** — 3 levels per account (balances+transactions / balances only / nothing) **plus per-TRANSACTION hiding** | Docs describe owner→partner control; reciprocity not stated | Partner invite; not documented on separation | Free |
| **Monarch** | The **household** — one shared dashboard | **No.** *"Once you invite your partner to your household, they will be able to view all connected bank accounts."* | **Yes — fully symmetric.** *"the same level of visibility and access"* | Invite from Household Members. **Cannot invite anyone who already has a Monarch account** — they must delete it or use a new email | **Free**, included in one subscription |
| **YNAB Together** | The **budget** (a whole document) — you choose which of your budgets to share | **Only whole-budget.** Keep a budget private by not sharing it — but *"all budgets are always shared with the Group Manager"* | **No — asymmetric by design.** Manager sees and may edit every member's budgets | Manager invites/removes, up to 6. On removal: *"budgets you own will be unshared but stay with your account; budgets shared with you will no longer be shared, and bank accounts you added to those shared budgets will become unlinked"*; removed member gets a 34-day trial | **One subscription**, up to 6 people, each with own login |
| **Copilot** | **The login.** Sharing = giving a partner Magic Link access to *your* account | **No** — there is no second identity to hide from | n/a — one identity | Share the sign-in link | Included. **Separate profiles are an open feature request, not shipped** |
| **Zeta** | **The account container** — a joint account, plus optional **personal** accounts | **By separation, not by ACL** — personal accounts are simply not the joint account | Symmetric within the joint account (*"you'll be able to see who swiped what"*) | Banking product | Free |

### 2.2 The three real answers the industry has found

1. **Per-record ACL** (Honeydue) — maximum granularity, requires a server.
2. **All-or-nothing on a container** (Monarch = household; YNAB = budget; Zeta = account) — no
   per-record logic at all. **Privacy comes from choosing which container to put a thing in.**
3. **Share the credential** (Copilot) — not sharing at all; one identity, two people.

**Only Honeydue does (1).** The most expensive and most recent products — Monarch and Copilot —
chose (2) and (3). That is worth weighing against the assumption that granularity is table stakes.

### 2.3 Zeta is the model that matters to us

Zeta solves partner privacy with **two containers and no ACL logic**: money in the joint account is
visible to both; money in a personal account is not. There is no "hide this transaction" — there is
"put it in the other pot".

**That maps exactly onto what CloudKit can express** (§3), and it is the only competitor model that
does. It arrives at Honeydue's user-visible outcome — *"my partner cannot see the anniversary
gift"* — through structure rather than permissions.

### 2.4 Separation — the question nobody answers

**Only YNAB documents it**, and only mechanically: on removal your own budgets stay with you and
become unshared; shared budgets stop being shared; linked accounts unlink. Monarch, Honeydue, Zeta
and Copilot publish nothing about what happens when a couple separates.

**Everyone with a server can afford to leave this undefined, because the server arbitrates.** We
would have no arbitrator. For us, "who keeps the ledger" is not a support question — it is a
data-model question that must be answered before a line is written.

### 2.5 Pricing — the seat is free everywhere

Monarch: *"It's free to add additional household members."* YNAB: up to six, *"all for the price of
a single subscription."* Honeydue and Zeta: free products. Copilot: the login is shared, so the
question does not arise.

**Nobody sells the second seat.** Combined with §1.8's finding that the consumer norm is not
documented anywhere, the evidence points one way: **if we ever ship this, the partner is included,
not sold.** Charging would be a lone position against every competitor examined.

### 2.6 THE QUESTION: every one of them shares bank-linked accounts

Correct, and it is structural. In all five, the shared object is a **feed** — an account that
produces transactions automatically. Sharing means "point your feed at our shared view."

Our `Source` is a **label**. Our data is hand-entered. So the industry's unit of sharing does not
exist in our product, and **no competitor's answer can be copied**. The unit has to be derived from
our own model. §4 does that.

---

## LEG 3 — THE CONSTRAINT, and it vetoes most of §4

### 3.1 What CKShare can actually express

From Apple's own material (Tech Talk 10874, *Get the most out of CloudKit Sharing*):

**Two units, mutually exclusive within a zone:**

- **Hierarchical sharing** — *"a single record is shared as a root record, and any children of that
  record are also shared."*
- **Zone sharing** (iOS 15+) — *"all of the records in the zone are shared, not just a single
  record's hierarchy."*
- *"Because zone sharing affects all of the records in a record zone, this type of sharing cannot
  coexist with hierarchical shares in the same record zone. You can either have one or more
  hierarchical shares in a zone, or a single zone-wide share."*

**Permissions are per PARTICIPANT, never per record:**

- *"Permissions are set on each participant object individually and each participant is added to
  the participants array on the CKShare."*
- Apple's material states plainly: **permissions are not per-record — they apply to either the
  entire shared hierarchy or the entire shared zone.**

**Answer to your question:** per-record visibility **cannot be expressed at all**. Hiding one
transaction from a participant requires that transaction to live **outside the shared hierarchy or
zone** — i.e. a separate container. There is no third option.

### 3.2 SwiftData does not support the shared database — and this is the veto

Three independent sources, agreeing:

- Notebook `de492776`, from sources: *"SwiftData **supports only private iCloud databases**.
  Synchronization with the public database and **cross-account data sharing** are **unsupported**."*
- Apple Developer Forums, DTS: **SwiftData + CloudKit public or shared database isn't supported
  today**; the recommendation for apps that need it is to **stay on `NSPersistentCloudKitContainer`**
  (Core Data), which does expose the sharing APIs.
- Still true as of 2026, with the additional constraint that **records in the default zone cannot
  be shared** — and SwiftData's private sync uses the default zone.

**Our entire persistence layer is SwiftData.** V2 was designed for it, the migration plan is built
on it, the multi-configuration container is SwiftData's, and `DESIGN_ICLOUD_SYNC_1_0_4.md` assumes
`ModelConfiguration(cloudKitDatabase:)` throughout.

> **So shared access is not "sync, then a share sheet." It requires either abandoning SwiftData for
> Core Data on the shared path, or hand-writing CloudKit sync beneath a second store.**
> Both are architecture programmes, not features. This is the veto, and it applies before any
> product question is reached.

### 3.3 What is structurally unavailable to us, and the nearest honest substitute

| Honeydue behaviour | Available to us? | Nearest honest substitute |
|---|---|---|
| Hide **one transaction** from a partner | **NO** — CKShare has no per-record permission | Put it in a **private container** the share does not cover (Zeta's model) |
| Per-account **three-level** visibility (balances / +transactions / nothing) | **NO** as an ACL | Approximated only if each Source were its own share root — see §4, and it is expensive |
| **Change** what a partner sees, retroactively, on existing data | **NO** — would mean moving records between zones, which is a delete+recreate, breaking identity | Nothing honest. **This is the one to refuse outright.** |
| Read-only participation | **YES** — `CKShare.Participant.Permission` has read-only | Direct equivalent |
| Revoke a participant | **YES** — remove from the share | Direct equivalent, though see §3.4 |

**Honeydue can do all of this because it has a server and its own ACL logic. We have no server —
that is the moat.** The moat and the missing feature are the same fact. Any design that quietly
reintroduces a server to get per-record hiding is not a feature decision; it is abandoning the
positioning.

### 3.4 Conflict: two humans, last-writer-wins, no server

`DESIGN_ICLOUD_SYNC §3` designs conflict resolution for **one user on N devices**. The assumption
that makes it safe is that the same person made both edits and remembers the intent. **Two people
break that assumption, not the mechanism.**

**What the user sees when a partner's edit is silently overwritten: nothing.** That is the whole
problem. Device A and device B both edit the grocery amount within a sync window; last-writer-wins
picks one; the loser's device updates to the winner's value with no event, no diff, no notice. The
partner who typed 47.20 later sees 52.00 and cannot tell whether they mistyped, their partner
corrected them, or the app lost it. In a shared financial ledger the natural reading is *"my partner
changed my entry"* — a relationship problem manufactured by a merge rule.

**Is there a model that avoids it without a server?** Partially, and the honest answer is
per-field, not global:

- **Append-only / event-sourced entries.** A ledger of immutable transactions with edits as
  subsequent events converges without a server, because inserts never conflict — only updates do.
  This is what makes a **shared ledger fundamentally safer than a shared budget**: two people adding
  rows is a union, and unions have no conflicts. Two people editing the same row does.
- **CRDT-style per-field merge** (last-writer-wins per attribute with a causal timestamp) narrows
  the blast radius from "the row" to "the field", so simultaneous edits to *amount* and *category*
  both survive. It does **not** solve two people editing the *same* field.
- **Nothing serverless resolves a genuine semantic conflict.** The realistic answer is not to
  resolve it but to **surface it** — keep both values and ask — which is a UI surface this app does
  not have and which the sync design explicitly deferred.

**The design consequence, and it is the most useful thing in this document:** a shared *ledger*
(two people appending transactions) is a nearly conflict-free workload. A shared *budget* (two
people adjusting the same category limits and amounts) is conflict-dense. **They are not the same
feature, and the corpus's happiest users — Goodbudget's — describe the first one.**

---

## 4. THE UNIT OF SHARING — candidates, with the Leg 3 veto applied

> **An option CloudKit cannot express is not an option, however good it looks.**

| # | Candidate | Daily friction for the user | CKShare verdict |
|---|---|---|---|
| **1** | **Whole ledger** — one shared zone, both see everything | **Lowest.** Nothing to decide, ever. But no privacy at all: every entry visible forever, retroactively. | ✅ **Expressible** — one zone share. Matches Monarch's shape exactly. |
| **2** | **Per `Source`** — share selected accounts | Moderate: each new Source needs a share decision. But `Source` is a *label*, so a user can silently mis-file a private purchase into a shared Source and expose it. | ⚠️ **Only as separate hierarchies**, one share root per Source, and **hierarchical and zone sharing cannot coexist in one zone**. Re-parenting a transaction between Sources = moving it between shares. **Expensive and fragile.** |
| **3** | **Per category** | High: a decision on every category, and category is exactly the field users most often *correct after the fact* — so visibility would change retroactively as a side effect of recategorising. | ❌ **Vetoed.** Same hierarchy problem as (2), plus recategorising would silently re-share or un-share history. |
| **4** | **Per transaction** | Highest: a decision on every single entry, on the entry surface, where our whole wedge is speed. | ❌ **Vetoed outright.** CKShare has **no per-record permission**. Not expressible. This is Honeydue's model and it is unavailable. |
| **5** | **A separate SHARED ledger alongside each person's private one** | Low-moderate: one decision per transaction — *shared pot or my pot* — but expressed as **which ledger am I in**, not as a permission. Same shape as choosing an account. | ✅ **Expressible** — the shared ledger is its own zone, shared whole; the private ledger stays in the private database. **Zeta's model, and the only one that gives privacy AND fits CloudKit.** |

**Two survive: (1) whole ledger, and (5) a separate shared ledger.** (5) is (1) plus a private
container, and it is the only candidate that answers *"can I keep something private?"* with anything
other than *"no"*.

**But both still sit behind §3.2's veto.** Expressible in CloudKit ≠ available in SwiftData. Either
option requires leaving SwiftData for the shared path.

**One more constraint that (5) inherits and (1) does not:** our multi-configuration container
already runs two stores (`synced` + `local`). A third, shared store is a third configuration whose
records must never be resolvable from the wrong one — and this project has already been bitten by
exactly that boundary (`delete(model:)` throwing `134060` because it cannot resolve an entity across
a multi-config container).

---

## 5. WHAT I WOULD BUILD, AND WHAT I WOULD REFUSE

### 5.1 Refuse — evidence-backed

**Refuse per-transaction hiding.** Not a judgement call: **CKShare cannot express it** (§3.1), and
the demand for it is **one review in 4,904** (§1.3, bucket C). Both legs say no independently.

**Refuse per-category sharing.** Vetoed by §3.1, and it would make visibility a side effect of
recategorising — a silent, retroactive privacy change. This is the worst option on the list.

**Refuse selling the second seat.** Every competitor examined includes the partner free (§2.5), and
no source documents a consumer norm otherwise (§1.8). Charging would be a lone position.

**Refuse building shared access in the 1.0.x line.** §3.2: it requires abandoning SwiftData on the
shared path or hand-writing CloudKit sync. That is an architecture programme sitting behind private
sync, which is itself behind two unbuilt prerequisites (the rollback ladder and the recurrence
watermark).

### 5.2 Would not build now — judgement, on weak evidence

**I would not schedule shared access at all on current evidence.** 0.04–0.14 %, below a signal
already ruled insufficient, from a single channel in a category we are not in, with both backlog
citations falsified. **That is judgement, not evidence** — evidence establishes the number; whether
the number is a threshold is a decision.

**The strongest counter-argument, stated fairly:** Goodbudget's 10.8 % (§1.5). The manual-entry app
most like ours has by far the highest couples salience, and 48 of 54 mentions are praise. If any
datum justifies revisiting, it is that one — and it is **satisfaction, not demand**, which is
precisely the supply-side error this method rule exists to prevent. It should not be scored as
demand no matter how much we like it.

### 5.3 Would build — cheap, evidence-backed, independent of this feature

**Read the support mailbox.** The demand finding rests on one channel because the other is unread
(§1.6). This is the highest-value action in the document and it needs no engineering.

**Correct `FEATURE_PREP_BACKLOG.md` row #9.** Both demand citations fail (§0). Leaving them
standing means the next planning pass re-derives the same conclusion from the same bad inputs — the
exact failure mode signal #9 was withdrawn for.

**If it is ever built: option (5), the separate shared ledger.** Judgement, but constrained
judgement — it is the only candidate that survives the CloudKit veto *and* answers the privacy
question, it is a shipped competitor model (Zeta), and it makes the workload **append-mostly**,
which is the conflict-free case (§3.4). Explicitly: *not* a shared *budget*, which is conflict-dense.

**And a smaller thing the corpus actually asked for.** The adjacent bucket-A wants were about
**splitting a shared expense and tracking partner reimbursement** — Rocket Money 4★, Wallet 2★ —
not about shared access. **We already ship splits.** Whether reimbursement tracking is worth
anything is a separate question on separate evidence, but it is notable that the nearest thing to
real demand in this corpus points at a feature we have rather than one we lack.

---

## 6. Confidence and coverage

**Demand (Leg 1): MEDIUM-LOW.** One channel; a competitor corpus from a category we are not in;
hand-classification of ~60 rows by one reader; a bucket-A range of 2–7 rows where small-count noise
dominates. **The falsification of "69 rage" is high confidence** — it is a mechanical property of
the tagger, reproducible in one command.

**Shape (Leg 2): HIGH** for Monarch, YNAB and Copilot (own docs and terms). **MEDIUM** for Honeydue
(support articles are clear on the mechanism, silent on symmetry) and **LOW** for separation
semantics, which only YNAB publishes at all.

**Constraint (Leg 3): HIGH.** Three independent sources on the SwiftData limitation, including
Apple DTS, plus Apple's own Tech Talk on the permission granularity. **This is the most reliable leg
and it is the one that vetoes.**

**Not covered, stated so coverage is not overclaimed:** the support mailbox (unreadable here);
non-US reviews (corpus is US-only); Honeydue's symmetry and separation behaviour; whether
`NSPersistentCloudKitContainer` could coexist with our SwiftData container in one app — a real
engineering question this document deliberately did not open, because opening it would be design.

---

## Sources

**Demand:** `review_mining_output/reviews_20260702_135538.csv` (N=4,904 after excluding Barri);
NotebookLM `73afc9a4` (domain), `0e5f6bb9` (pricing) — both re-probed with conversation history
excluded.

**Shape:**
[Honeydue — how to change what my partner can see](https://support.honeydue.com/en/articles/3283211-how-to-change-what-my-partner-can-see) ·
[Honeydue — will my partner see my balances](https://support.honeydue.com/en/articles/3179542-will-my-partner-see-my-bank-account-balances-and-transactions) ·
[Monarch — Household Members](https://help.monarch.com/hc/en-us/articles/360048393452-Household-Members) ·
[Monarch — Budgeting for Couples](https://help.monarchmoney.com/hc/en-us/articles/20926382202004-Budgeting-for-Couples) ·
[YNAB Together — Terms of Service](https://www.ynab.com/terms/ynab-together) ·
[YNAB Together — A Guide](https://support.ynab.com/en_us/ynab-together-B1nS78Cki) ·
[Copilot — Sharing Your Account with a Partner](https://help.copilot.money/en/articles/4523792-sharing-your-account-with-a-partner) ·
[Copilot — Multiple Profiles (open feature request)](https://roadmap.copilot.money/feature-requests/p/multiple-profiles-in-one-copilot-account) ·
[Zeta — Joint Accounts](https://www.askzeta.com/jointaccount) ·
[Zeta — Personal accounts](https://www.askzeta.com/personal-bank-account)

**Constraint:**
[Apple Tech Talk 10874 — Get the most out of CloudKit Sharing](https://developer.apple.com/videos/play/tech-talks/10874/) ·
[CKShare](https://developer.apple.com/documentation/cloudkit/ckshare) ·
[CKShare.Participant.Permission](https://developer.apple.com/documentation/cloudkit/ckshare/participant/permission) ·
[Shared Records](https://developer.apple.com/documentation/CloudKit/sharing-cloudkit-data-with-other-icloud-users) ·
[Apple Developer Forums — SwiftData with shared and private containers](https://developer.apple.com/forums/thread/756721) ·
[Apple Developer Forums — Does SwiftData support data sharing among multiple users through iCloud?](https://developer.apple.com/forums/thread/765776) ·
NotebookLM `de492776`.
