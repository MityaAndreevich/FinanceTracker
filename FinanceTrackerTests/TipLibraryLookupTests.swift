//
//  TipLibraryLookupTests.swift
//  FinanceTrackerTests
//
//  The per-user collection is a persisted list of tip *ids* (see TipDeck). The hub
//  resolves those ids back to localized tips through the library. These pin that
//  id → tip resolution: it is order-preserving, locale-aware, skips ids the current
//  library doesn't know (so a shrunk/renamed library can't crash the hub), and can
//  never surface a tip whose id isn't in the requested set.
//

import Testing
import Foundation
@testable import FinanceTracker

struct TipLibraryLookupTests {

    private func tip(_ id: String, term: String = "term") -> DailyTip {
        DailyTip(id: id, term: term, explanation: "e", strategy: "s", category: "c")
    }

    private func library(_ ids: [String]) -> TipLibrary {
        let tips = ids.map { tip($0) }
        return TipLibrary(base: tips, localized: tips)
    }

    @Test func canonicalIDsAreTheBaseIdsInOrder() {
        #expect(library(["a", "b", "c"]).canonicalIDs == ["a", "b", "c"])
    }

    @Test func tipForIDResolvesRegardlessOfPosition() {
        let lib = library(["a", "b", "c"])
        #expect(lib.tip(forID: "b")?.id == "b")
        #expect(lib.tip(forID: "missing") == nil)
    }

    /// The reveal log carries ids most-recent-first when the hub reverses it; this
    /// helper must resolve them in exactly the order it is handed.
    @Test func tipsForIDsPreservesRequestedOrder() {
        let lib = library(["a", "b", "c", "d"])
        #expect(lib.tips(forIDs: ["c", "a", "d"]).map(\.id) == ["c", "a", "d"])
    }

    /// An id the current library no longer contains (renamed, or a shrunk library)
    /// is skipped, not crashed on — the rest of the collection still resolves.
    @Test func tipsForIDsSkipsUnknownIDs() {
        let lib = library(["a", "b"])
        #expect(lib.tips(forIDs: ["a", "ghost", "b"]).map(\.id) == ["a", "b"])
    }

    /// Locale fallback still works by id: a Spanish user resolving a revealed id
    /// gets the Spanish term.
    @Test func tipForIDIsLocalized() {
        let base = [tip("a", term: "Sinking fund")]
        let es = [tip("a", term: "Fondo hundido")]
        let lib = TipLibrary(base: base, localized: es)
        #expect(lib.tip(forID: "a")?.term == "Fondo hundido")
    }

    /// Search scoped to the revealed subset can never surface a tip outside it —
    /// the guarantee that the hub's search field can't spoil an unlocked-tomorrow.
    @Test func searchOverRevealedSubsetCannotLeakAnUnrevealedTip() {
        let lib = TipLibrary(
            base: [tip("a", term: "Sinking fund"), tip("b", term: "Zero-based budget")],
            localized: [tip("a", term: "Sinking fund"), tip("b", term: "Zero-based budget")]
        )
        let revealed = lib.tips(forIDs: ["a"])   // only "a" unlocked
        #expect(lib.matching("Sinking", in: revealed).map(\.id) == ["a"])
        #expect(lib.matching("Zero-based", in: revealed).isEmpty)   // "b" not leaked
    }
}
