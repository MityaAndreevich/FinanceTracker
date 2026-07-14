//
//  SaveActionGate.swift
//  FinanceTracker
//
//  Accidental double-submit protection for a single user action.
//

import Foundation

/// Collapses a fast double-fire of ONE user action (a Save tap, an auto-commit)
/// into a single run.
///
/// Deliberately content-BLIND: it never looks at what is being saved, only at how
/// recently this action last fired. That is the whole design.
///
/// It replaces a content-identity dedup that lived in `QuickAddSaveService` and
/// silently dropped legitimate entries — two coffees at the same price on the same
/// day collapsed into one row while the UI reported "saved". Identical content never
/// implied an accidental duplicate; only *timing of a single action* does. A gate that
/// cannot see the payload cannot drop a distinct entry, so this class of data loss is
/// structurally impossible here — the worst it can do is ignore a second tap that a
/// human could not physically have intended as a second purchase.
///
/// Not a substitute for import dedup (`CSVImportService`), where a file may genuinely
/// restate rows the user already has and there is no human in the loop.
@MainActor
final class SaveActionGate {

    /// Long enough to swallow a double-tap, an accessibility double-fire, or a late
    /// voice `.ended` re-enabling the button; far shorter than any human could type a
    /// *different* entry and submit it.
    static let debounceWindow: TimeInterval = 0.5

    private var lastAcceptedAt: Date?

    init() {}

    /// Runs `body` unless this action already fired within `debounceWindow`.
    /// - Returns: `true` if `body` ran, `false` if this fire was debounced away.
    @discardableResult
    func submit(now: Date = .now, _ body: () throws -> Void) rethrows -> Bool {
        if let last = lastAcceptedAt, now.timeIntervalSince(last) < Self.debounceWindow {
            return false
        }
        lastAcceptedAt = now
        try body()
        return true
    }

    /// Reopens the gate immediately.
    ///
    /// Call after a FAILED save. The window exists to absorb an accidental second tap,
    /// not to block a deliberate retry: if a save throws, the user is looking at an
    /// error and may well tap again inside 500ms, and that tap must land. Without this,
    /// the gate would itself become a (smaller) source of the data loss it replaced.
    func reset() {
        lastAcceptedAt = nil
    }
}
