# Privacy Policy — moved

The Budget Crab privacy policy is **not** kept in this repository.

**Canonical, published version:** <https://budgetcrab.app/PRIVACY_POLICY.html>
**Source of record:** `MityaAndreevich/budget-crab` → `PRIVACY_POLICY.html`

This is a pointer, not a copy. Do not restore a policy document here.

---

## Why this file exists instead of the document

A second copy of the policy lived at this path from 2026-06-22 until 2026-08-03.
It was never the published policy — but it *was* publicly readable, because
GitHub Pages was enabled on this repository (`main` → `/docs`) and rendered it at
`mityaandreevich.github.io/FinanceTracker/PRIVACY_POLICY.html`.

The two copies diverged on **2026-06-25**. `ff77d5b` (06-24) renamed the product
to "Vela" across user-facing surfaces including this file; `69a9495` (06-25)
renamed the app to "Budget Crab"; the HTML at `budget-crab` was authored fresh on
06-26 with the correct name, and this Markdown copy was never brought back in
line. It drifted for 40 days and ended up asserting three things that were not
true of the shipped app: the name "Vela", a camera / Receipt-OCR data flow (the
app declares no `NSCameraUsageDescription` and links no Vision framework), and
end-to-end encryption of iCloud data.

`outputs/BRIEF_PRIVACY_POLICY_HOST.md` (audit dated 2026-07-02) had already
listed exactly those corrections. They were applied to the HTML and never to this
file. **That is the failure mode a duplicate produces: a fix lands on one copy.**

GitHub Pages was disabled on this repository on 2026-08-03, and this document was
replaced by this pointer on the same day. Both were needed — disabling Pages
removed the symptom, deleting the duplicate removed the defect.

## The rule

One fact, one home. A pointer, never a copy.

If the policy needs changing, change it in `budget-crab` and publish from there.
There is no second place to keep in sync, and adding one re-creates the bug.

## Related

- Correction analysis and Apple citations on the encryption claim:
  `outputs/REVIEW_PRIVACY_POLICY_CORRECTION_2026-08-03.md`
- Full audit of what was live and where: `outputs/AUDIT_STATE_2026-08-03.md` §D
