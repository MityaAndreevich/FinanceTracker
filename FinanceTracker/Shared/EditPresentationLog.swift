//
//  EditPresentationLog.swift
//  FinanceTracker
//
//  DEBUG-only instrumentation for the 2026-07-17 device report: at ~8k rows,
//  tapping Edit on a Transactions row presents nothing — persistent, silent, no
//  crash. The mechanism does NOT reproduce in the simulator at 8k across an
//  exhaustive matrix (row / swipe / context / re-entry / scroll-deep × single &
//  two launch × iOS 18.6 and 26.5 — see EditAtScaleReproTests). So it has to be
//  captured on the device where it fires. The founder runs Debug builds, so this
//  DEBUG-gated logging reaches him.
//
//  During a device repro, open Console.app (or `log show`/`log stream`) filtered
//  by subsystem "com.dmitrylogachev.budgetcrab", category "EditPresentation". Tap
//  a row's Edit once; the emitted sequence tells the story:
//
//    CHILD-APPEAR / CHILD-DISAPPEAR
//                  — the scoped list child MOUNTED / UNMOUNTED under a specific
//                    identity `id`. This tracks a REAL `.id(scope)` identity flip
//                    (view lifetime), NOT a struct re-init — SwiftUI re-inits a
//                    View on every render, so `init` is useless as a flip signal.
//    TAP-SET       — a row/swipe/context Edit button set `editTx`, carrying the
//                    period row-count, the scope, and the live child identity at
//                    that instant (the defect is scale/timing-bound, so timing
//                    relative to a child flip is the thing we most need).
//    BINDING       — `editTx` transitioned nil→id (armed) or id→nil (popped/reset).
//    DEST-INVOKED  — SwiftUI asked `navigationDestination` to BUILD the editor.
//    EDITOR-APPEAR — EditTransactionView actually mounted on screen.
//
//  How to read the capture (one tap):
//    TAP-SET present, DEST-INVOKED absent          → push DROPPED (never requested).
//    DEST-INVOKED present, EDITOR-APPEAR absent     → built but never mounted.
//    BINDING id→nil right after nil→id              → pushed then POPPED (sticky reset).
//    TAP-SET absent                                 → the tap never set editTx.
//    CHILD-DISAPPEAR+CHILD-APPEAR (new id) BEFORE   → an `.id(scope)` flip is racing
//      DEST-INVOKED, or liveChildId changes mid-tap    the push — the founder's #1.
//
//  Expected-normal noise, so it isn't misread as a fault:
//    * A CHILD-DISAPPEAR AFTER EDITOR-APPEAR is normal — the list is covered by
//      the pushed editor.
//    * DEST-INVOKED repeating while the editor is up is normal — SwiftUI
//      re-evaluates the destination builder on later renders. Only the FIRST
//      DEST-INVOKED after a TAP-SET matters.
//
//  Privacy: only a truncated row UUID, a short identity token, integer counts,
//  and the scope key are logged `.public`. No merchant, amount, note, or category
//  *values* are recorded.
//

import Foundation

#if DEBUG
import os

enum EditPresentationLog {
    private static let log = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "EditPresentation")

    /// Identity of the scoped-list child that most recently MOUNTED (onAppear). A
    /// real `.id(scope)` flip changes this; a plain struct re-init during a render
    /// does not. Read at TAP-SET so the capture shows the live identity at the
    /// instant of the tap. Main-actor only (all call sites are).
    private(set) static var liveChildIdentity = "—"

    private static func short(_ id: UUID) -> String { String(id.uuidString.prefix(8)) }

    // `.notice` (not `.debug`): notice-level entries are persisted to the unified
    // log and appear in Console.app / `log show` with NO special configuration —
    // the founder just filters by subsystem + category during a repro. `.debug`
    // would need debug logging explicitly enabled first and could be dropped.

    static func childAppear(id: UUID, scope: String) {
        liveChildIdentity = short(id)
        log.notice("CHILD-APPEAR id=\(short(id), privacy: .public) scope=\(scope, privacy: .public)")
    }

    static func childDisappear(id: UUID, scope: String) {
        log.notice("CHILD-DISAPPEAR id=\(short(id), privacy: .public) scope=\(scope, privacy: .public)")
    }

    static func tapSet(row: UUID, periodCount: Int, filteredCount: Int, scope: String, editTxWasNil: Bool) {
        log.notice("TAP-SET row=\(short(row), privacy: .public) periodCount=\(periodCount, privacy: .public) filtered=\(filteredCount, privacy: .public) scope=\(scope, privacy: .public) editTxWasNil=\(editTxWasNil, privacy: .public) liveChildId=\(liveChildIdentity, privacy: .public)")
    }

    static func binding(old: UUID?, new: UUID?) {
        let o = old.map(short) ?? "nil"
        let n = new.map(short) ?? "nil"
        log.notice("BINDING editTx \(o, privacy: .public)→\(n, privacy: .public)")
    }

    static func destInvoked(row: UUID) {
        log.notice("DEST-INVOKED row=\(short(row), privacy: .public)")
    }

    static func editorAppear(row: UUID) {
        log.notice("EDITOR-APPEAR row=\(short(row), privacy: .public)")
    }
}
#endif
