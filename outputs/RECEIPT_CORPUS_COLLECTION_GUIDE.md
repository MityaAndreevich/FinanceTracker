# Receipt corpus — collection guide (one page)

**For:** Dmitry. **Why:** the scanner ships only after it is measured against real receipts
(`DESIGN_RECEIPT_SCAN.md` §7). The numbers are only as honest as the corpus, so the corpus is
collected *before* the parser is tuned and half of it is sealed. **Where it lives:** the private repo
(`budget-crab-internal/receipt-corpus/`), never this one — and even there, **no personal data**.

## What to collect

| type | per locale | target locales |
|---|---|---|
| **Paper** — a photo of a physical receipt | **10 or more** | en and ru first (you and friends); es-MX, pt-BR, uk as available. A locale short of 10 REAL paper photos ships paper scanning with a permanent "check the amount" line — that is fine, just say so |
| **Screenshot** — an online order confirmation, a payment-app receipt, an e-mail receipt, a delivery-app order | **10 or more** | all five. Screenshots must show **Subtotal / Tax / Shipping / Discount and a grand total** where the real page has them — that is exactly the case the parser must get right |

Variety matters more than volume. For paper, include at least: a long grocery slip, a café slip
with a tip line, a fuel receipt, a pharmacy receipt with tax lines, a restaurant bill, and a
handful of **deliberately bad ones** — crumpled, photographed at an angle, thermal-faded, poorly lit.
The parser has to fail *gracefully* on those, and we need to see how it fails.

Also collect **5 non-receipts** for the negative control: a menu, a business card, a page of a book,
a photo with no text, a bank statement. The scanner must find **no total** on any of them.

## How to photograph paper

1. Receipt flat on a plain surface, the **whole receipt in frame**, top to bottom.
2. Natural light, no flash, no shadow across the total line.
3. Hold the phone roughly parallel to the paper. (Then break these rules on purpose for the bad set.)
4. Use the normal Camera app, not a document scanner — we want what the app will see.
5. Screenshots: the plain screenshot, uncropped, as a user would take it.

## Privacy — before anything leaves your phone

**Cover, in the photo or with the Markup tool afterwards:** card numbers (even the last four),
cardholder names, e-mail addresses, home addresses, phone numbers, loyalty-card numbers, order
numbers that look like account numbers, QR codes. **Do not cover** the merchant name, the date, the
line items, or any amount — those are what we measure. If a screenshot cannot be made safe, leave it
out. The corpus is private, and it still must not carry personal data — a corpus is a file that gets
copied.

## Naming

`<locale>_<type>_<nn>.jpg` (or `.png` for screenshots), e.g. `ru_paper_03.jpg`, `en_screenshot_07.png`,
`uk_paper_bad_02.jpg` for the deliberately bad ones, `xx_nonreceipt_01.jpg` for the control set.
Locale = the language printed on the receipt (`en`, `ru`, `es`, `pt`, `uk`), not where you are.

## Recording the truth — `manifest.csv`, one row per image

```
file,locale,type,total_cents,merchant,date,currency,notes
ru_paper_03.jpg,ru,paper,125000,Перекрёсток,2026-09-18,RUB,thermal slightly faded
en_screenshot_07.png,en,screenshot,4599,Amazon,2026-09-20,USD,subtotal 42.99 + shipping 3.00
xx_nonreceipt_01.jpg,,nonreceipt,,,,,restaurant menu
```

- `total_cents` = the amount you actually paid, **in cents, no separators** (12 500,00 ₽ → `125000`).
  Read it from the receipt, not from the app.
- `merchant` = as printed, `date` = `yyyy-mm-dd` as printed (blank if none), `currency` = ISO code.
- `notes` = anything a reader of a miss would want to know.

## What happens next (so the ordering is clear)

1. You hand over the images + manifest. I freeze it: a SHA-256 of every file and of the manifest,
   committed. **Nothing is added to a frozen set.** Late arrivals become the *next* set.
2. The set is split in two **by hash, not by hand** — a DEV half I may look at and tune the parser
   against, and a SEALED half nobody looks at.
3. The parser is frozen (a commit). The sealed half is run **once**; the numbers reported are those.
4. If the sealed half misses the bar, that is the report. We do not tune and re-run the sealed half;
   we collect a new sealed set.

**Deadline:** the parser and the capture flow can be built without the corpus, but **nothing ships
until step 3** — so the day the en and ru paper photos arrive is the feature's critical path.
