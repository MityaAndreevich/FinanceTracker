# BRIEF (Claude Code) — v1.0.3 iCloud Sync (CloudKit + SwiftData), premium-gated. Model: **Opus** (data-layer migration + concurrency — highest-risk work in the app). Skills: apple-hig-expert, find-skills for SwiftData/CloudKit. 

**v1.0.3 branch (1.0.2 is the shipped/frozen money release — don't touch it).** `main`, commit per unit, push, `xcodebuild … build` + full test before each commit. Localize all new strings in 5 locales. **This migrates the live financial data store — a mistake loses users' money data. TDD, back up before migrating, refuse-don't-assume, never destroy data.**

## Why
iCloud Sync is the #1 premium gate by WTP (research: "standard expectation at $4.99; turns a one-time utility into a subscription-worthy service"). Privacy framing = our wedge: **encrypted in the user's OWN iCloud (private database), we never see it, no bank login.** Premium-gated behind `AccessManager.isPremium`.

## ⚠️ Step 0 — CloudKit compatibility audit FIRST (report before ANY change)
CloudKit + SwiftData imposes hard constraints our current model likely violates. Audit and report:
- **`@Attribute(.unique)` is NOT allowed** with CloudKit sync. We have `Transaction.uuid` as `@Attribute(.unique)` (and possibly others). Report every `.unique` in the model. Plan: drop the DB-level unique constraint and enforce uniqueness in code (our dedup already keys on UUID) — but this is a **store migration**, describe it before doing it.
- **All attributes must be optional or have defaults**, and **relationships must be optional with inverses**. Report every non-optional attribute / relationship without a default.
- **No `.deny` delete rules** (CloudKit-incompatible — noted in prior research). Report any.
- **KNOWN BUG to fix here (found 2026-07-12):** `Transaction.source` is `.nullify` **with NO inverse relationship** → SwiftData never enforces the rule → deleting a Source leaves a dangling on-disk reference → `source.name` read crashes (EXC_BREAKPOINT, persists across launches). Currently only dodged by the UI refusing to delete accounts-with-transactions. **Fix properly here:** add the inverse relationship (CloudKit requires inverses anyway) so `.nullify` actually fires. Audit ALL relationships for missing inverses, not just this one.
- Report the current `ModelConfiguration`/container setup (SharedModelContainer), the App Group, and how the widget reads the store (the widget must keep working post-migration).
**Do not proceed to Item 1 until you've reported this audit and the migration plan.**

## Item 1 — Model + container changes for CloudKit
- Make the models CloudKit-compatible per the audit (optional/defaulted attrs, optional inverse relationships, remove `.unique`, no `.deny`).
- Add a CloudKit-backed `ModelConfiguration` (`cloudKitDatabase: .private` / `.automatic`) alongside the local one. Add the iCloud + CloudKit + Background Modes (remote notifications) capabilities/entitlements.
- **Migration must be non-destructive:** existing local data must survive and flow into the synced store. Provide a safe path (and a rollback note). Never wipe on schema mismatch — recover or migrate.

## Item 2 — Off-main write path (@ModelActor) — belongs WITH sync
- Route writes through a `@ModelActor` so concurrent local edits + CloudKit merge don't corrupt the context (CloudKit stresses concurrency). No `ModelContext` mutation from a background thread outside the actor (CLAUDE.md anti-pattern).
- Keep the widget snapshot rebuild + `contentSignature` reload working with the new write path.

## Item 3 — Premium gating + UX
- Settings toggle "Sync with iCloud" gated behind `isPremium`; tapping it while free → the paywall (contextual gate — this is the lead upsell moment).
- Clear status: syncing / synced / signed out of iCloud / error. Handle **no iCloud account** gracefully (don't crash, explain).
- Privacy copy: "Synced through your own iCloud, end-to-end via Apple. We never see your data." (Honest — verify it's the private DB.)
- Sync is per-Apple-ID; conflict resolution = last-writer-wins at the field level is acceptable for v1 (document it); dedup stays UUID-based.

## Tests (targeted, TDD)
- Migration: a store with existing local transactions/accounts/categories migrates with **zero data loss** (assert counts + a sample record's fields pre/post).
- Model compiles + persists with the CloudKit-compatible schema; uniqueness now enforced in code (dedup still idempotent on UUID).
- Write path: concurrent writes via the actor don't corrupt; widget signature still updates.
- Gating: sync toggle blocked when free → paywall; enabled when premium.
- No-iCloud-account and offline states handled without crash.

## Report (≤6 lines/item): the Step-0 audit + migration plan FIRST; then model/container changes, the actor write path, gating, files, build/test, commit per unit. Flag anything that turns into a bigger migration than expected. Device-verify (yours): two devices on the same Apple ID sync; existing data intact after update; free user hits the paywall on the sync toggle; sign-out handled. Do NOT build household sharing here (separate later cycle) — but keep the CloudKit foundation reusable for it.
