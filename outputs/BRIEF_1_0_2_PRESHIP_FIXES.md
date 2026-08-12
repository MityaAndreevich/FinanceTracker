# BRIEF (Claude Code) — v1.0.2 pre-ship fixes (must clear before submitting 1.0.2). Model: Sonnet + systematic-debugging for Item 1. Skills: paywalls.

**v1.0.2 branch.** `main`, commit per item, push, build + full test before commit. No batching. Both items must be green before 1.0.2 is submitted.

## Item 1 (BLOCKER for 1.0.2) — the account-cap gate test fails: diagnose, don't fix blind
`MonetizationGateFlowTests.test_accountCap_blocksTheNextAdd…` fails with "Account name field never appeared" — pre-existing since 556d884 (the monetization commit), confirmed failing on clean HEAD.
- **Step 0 — report the root cause first.** Determine which it is: (a) a STALE UI test (the add-account field's accessibility id / flow changed, test looks for the wrong thing), or (b) a REAL bug (the account-cap gating blocks or breaks the add-account flow itself, so a free user can't reach/complete adding an account even below the cap). Report with evidence before changing anything.
- If (b) real bug: fix the flow so a free user CAN add up to the cap, and the gate fires only on the (N+1)th add — never breaks reaching the field. This is core monetization correctness.
- If (a) stale test: fix the test to match the real UI + keep it asserting the actual gate behavior (block the next add at the cap, existing data preserved).
- Either way the test must end green AND genuinely verify: free user adds up to cap → allowed; the next add → paywall; existing over-cap items untouched.

## Item 2 — derive the per-month / savings copy from StoreKit (kill the last hardcoded price)
`paywall.yearly.per_month` hardcodes "$2.92/month" and "Save 42%" in all 5 locales — wrong in every non-USD storefront (same class as the trial-price bug just fixed in 0f67862).
- Compute both from the live StoreKit products: per-month = annual price ÷ 12 formatted in the storefront's currency/locale; savings % = 1 − (annual ÷ (monthly × 12)), rounded. Nil-safe if a product is unavailable (hide the line rather than show a wrong number).
- Remove the hardcoded price/percent from the 5 .strings; keep only the surrounding words as a format string.
- Test: correct per-month + savings for a sample product set; a non-USD storefront formats correctly; missing product → line hidden, no crash; 5-locale parity.

## Report (≤6 lines/item): Item 1 root cause (a or b) + the fix + green test; Item 2 the derivation + test; files, build/test, commit per item. Both green before 1.0.2 submit.
