# BRIEF (Claude Code) — Full pre-submit code review / AUDIT (read-first, severity-gated). Model: Opus for the audit pass; Sonnet for any P0 fixes.

**Mode = AUDIT, not refactor.** Produce a ranked findings report FIRST. Do NOT change code during the audit except to fix confirmed **P0** issues (crash / leak / data-loss / security / concurrency-hazard). Defer all P1/P2 to a post-launch cleanup. We are days from App Store submission — protect the submit; do not mass-refactor now.

**Use installed skills:** security review, release-review/app-store, superpowers (systematic-debugging / TDD), ios-simulator. Run the audit in a dedicated review subagent so it doesn't pollute the main working context (per CLAUDE.md context discipline). Grep-first; read only what a finding requires.

## Output: `outputs/CODE_REVIEW_FINDINGS.md`
For each finding: **severity (P0/P1/P2) · category · file:line · what · why it matters · fix sketch · effort**. Sort by severity. End with a P0 punch-list and a P1/P2 backlog. Keep the report tight — reference paths + line ranges, don't paste large code.

## Severity gate
- **P0 (fix before submit):** crashes (force-unwrap `!`, `try!`, array OOB, `fatalError`, non-finite → Swift Charts), memory leaks / retain cycles, data loss/corruption, concurrency hazards (main-thread Core Data, `ModelContext` off a `ModelActor`, data races), security/privacy violations (contradicts "Data Not Collected", secrets, sensitive logging).
- **P1 (post-launch, soon):** dead code, duplication vs our shared infra, long functions, missing `weak`, hardcoded strings / locale parity gaps, unnecessary main-thread work, questionable error handling.
- **P2 (backlog):** style, naming, doc, micro-perf.

## Checklist (report findings per area)
1. **Crash safety:** every `!` force-unwrap, `try!`, `as!`, subscript without bounds check, `fatalError`/`precondition`; any numeric value that can reach Swift Charts / a frame size without an `isFinite && >= 0` guard (we already have a confirmed Charts NaN crash — find the rest).
2. **Memory / lifecycle:** escaping closures capturing `self` strongly (esp. StoreKit `Transaction.updates`, Speech/AVAudioSession callbacks, Combine sinks, `Task {}`, timers, NotificationCenter); delegates not `weak`; observers/tasks not cancelled on teardown; `@StateObject` vs `@ObservedObject` misuse. Run Instruments Leaks/Allocations if feasible; otherwise static reasoning.
3. **Concurrency / SwiftData:** synchronous `context.fetch` / `performBlockAndWait` / `executeFetchRequest` on main; `ModelContext` touched off a `ModelActor`; `@MainActor` correctness; unstructured `Task` without cancellation; delete-rule correctness (we hit `.deny` before).
4. **Security / privacy:** anything transmitted off-device (must be nothing per our label); logging of transaction data / amounts / PII in Release; hardcoded secrets/keys; Keychain/Data Protection usage; `PrivacyInfo.xcprivacy` Required-Reason coverage matches actual API use.
5. **Correctness conventions (our anti-patterns):** per-view `MoneyFormatter`/`formatMoney` (use `Shared/Money.swift`); `tx.typeRaw == "income"` (use `tx.isIncome`); reading `transactions.first?.currency` for aggregation (use `@AppStorage("defaultCurrencyCode")`); per-view category picker (must route through `CategoryPickerSheet`); hardcoded English strings.
6. **Dead code / duplication:** unused files, symbols, DEBUG-only seams leaking into Release, duplicated logic that belongs in shared infra.
7. **Localization:** hardcoded user-facing strings; string parity across en/ru/es/pt-BR/uk.
8. **Performance:** heavy work in SwiftUI `body`/computed props; redundant recomputation on each keystroke/save; image/asset sizing.

## Verification
Use a subagent to independently sanity-check the P0 list (don't self-certify high-severity). Build must stay green. For any P0 you fix now: commit per fix with a conventional prefix, targeted test where the logic is testable, and note it in the findings doc.

## Report back
Path to CODE_REVIEW_FINDINGS.md, the P0 count + one-line each, what (if anything) you fixed now vs deferred, build status. Do NOT start P1/P2 work — that's a separate post-launch brief.
