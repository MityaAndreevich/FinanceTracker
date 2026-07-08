# Budget Crab — Import & Migration roadmap (2026-07-06)

Source: NotebookLM 73afc9a4. Goal: let users bring data from competitors + bank statements, so we can honestly market "easy to switch." **Honesty gate (2.3): only claim what we actually parse.** Sequence = build → then claim.

## Strategic fit — why this is ON-brand, not a detour
The 2026 trend is **import statements WITHOUT bank credentials** — on-device AI/OCR parsing of CSV/PDF/screenshots (Finny, Zeroed). That is exactly our positioning: privacy-first, no bank linking, on-device. Migration is a direct amplifier of our wedge, and it rides the validated **post-Mint vacuum** ("Mint refugees" → Monarch won purely on Mint-CSV import; Piere grew on "import years of Mint data").
**Advantage already banked:** the notebook's #1 hard part of importing — **duplicate reconciliation** — we already solved (UUID dedup + flag-not-drop for foreign files). The scariest part is done.

## What competitors export / what bank statements come in
- **CSV** — universal standard (Mint, EveryDollar, MoneyWiz, Actual, everyone). Mint CSV = the de-facto migration format.
- **OFX / QFX / QIF** — standard financial-exchange; privacy users prefer these for manual import (no bank creds).
- **PDF** — bank monthly statements; needs OCR/AI extraction.
- **SQLite** — Actual Budget's "sovereign" backup.
- **MT940 / CAMT.053** — EU/pro bank standards.

Competitor export column schemas (for our mapper presets):
| Source | Columns |
| --- | --- |
| Mint CSV | Date, Description, Original Description, Amount, Transaction Type, Category, Account Name, Labels, Notes |
| NerdWallet | Account, Amount, Category, Date, Vendor |
| EveryDollar | Amount, Date, Category, Line Item |
| PocketGuard | Category, Merchant, Date, Notes(#hashtags) |
| Actual Budget | Payee, Notes, Category, Amount, Transfers |
| Our export | date, type, amount, currency, category, source, tax, note, merchant, id |

## Tiered roadmap (build → claim)

### Tier 1 — v1.0 (SHIPPED)
Generic CSV import + our own round-trip export (hardened, UUID dedup).
**Claim allowed now:** "Import your transactions via CSV." NOTHING about banks/Mint yet.

### Tier 2 — v1.1 (highest ROI, moderate effort) — Flexible CSV import + source presets
The migration unlock. Components:
- **Column-mapping UI** — user maps their file's columns to ours (handles any CSV).
- **Source presets** — one-tap mappings for the big migration sources: **Mint CSV** (priority — the refugee wave), YNAB, Monarch, generic bank CSV.
- **Handle the #1 bank-CSV gotcha:** amount split into **two columns** (separate debit/credit) vs a single signed column. Explicit support — this is where naive importers fail.
- Reuse existing dedup so re-imports/overlaps don't duplicate.
**Claim unlocked:** "Easily switch from Mint, YNAB, and most banks — import via CSV." **ASO keywords:** `import from Mint`, `switch from Mint`, `CSV import`, `budget import`.

### Tier 3 — v1.2+ (bigger, strongest differentiator) — Statement import via on-device AI/OCR
Parse **PDF bank statements** (and optionally OFX/QFX + screenshots) with **on-device Foundation Models / OCR** — no bank credentials, nothing leaves the phone. This IS our v1.1 AI roadmap ([[financetracker_v1_1_ai_roadmap]]) pointed at import. Perfect privacy-moat story.
**Claim unlocked:** "Import bank statements (PDF) — parsed on your iPhone, no bank login." Keywords: `bank statement import`, `import PDF statement`.

### Do NOT build now / do NOT claim yet
- Anything beyond generic CSV until Tier 2 ships (2.3 risk).
- MT940/CAMT.053 (EU pro) — niche, only if data demands.
- Live bank sync — off-brand (we're no-bank-linking by design; that's the point).

## Friction to design around (from reviews)
- **Re-categorization tax** — biggest post-import complaint. Our category mapping in presets + "leave uncategorized, user fixes" should minimize forced re-tagging.
- **Duplicate reconciliation** — already solved (UUID + flag-not-drop). Keep it.
- **Manual-barrier / 2-week abandonment** — fast import IS the "superpower" that prevents it; this is why Tier 2/3 matter for retention, not just acquisition.

## Launch impact
None on v1.0. Tier 2 = v1.1, Tier 3 = v1.2+. Marketing claims strictly follow the build. When Tier 2 ships, add migration keywords + consider a "Switch from Mint" Custom Product Page.
