//
//  RecurrenceTwinCollapseTests.swift
//  FinanceTrackerTests
//
//  The double charge does not come from resolution in `fetchTemplate` — that
//  one takes `.first` and drives *a* twin, once. It comes from the ROW COUNT in
//  `dueRecurring`: the fetch is `recurrenceRaw != nil`, so a series that exists
//  as two rows after a first-sync union produces two prompts, and the user is
//  asked to log the same charge twice in one sitting.
//
//  Collapsing them raises a question the one-row world never had: if the twins
//  DIVERGED before the union — the amount was edited on device A only — which
//  twin's values does the surviving prompt carry? Both devices run this collapse
//  independently and never compare notes, so `.first` of a fetch gives them
//  different answers and re-introduces the divergence the collapse was meant to
//  remove.
//
//  The rule pinned here is a total order over SYNCED fields only:
//
//    1. later `updatedAt` wins       — an edit is newer than a non-edit, and
//                                      last-writer-wins is the rule CloudKit
//                                      already applies to everything else
//    2. then earlier `createdAt`     — the original row of the series
//    3. then a content order         — amount, type, currency, date, merchant, note
//
//  `persistentModelID` is deliberately absent: it is assigned per device, so
//  ordering on it is the one thing guaranteed to make two devices disagree.
//
//  If two rows tie on all of (3), they are identical in every synced field, so
//  either choice yields the same VALUES. Determinism of the outcome is what the
//  rule has to guarantee; determinism of which row object wins is not reachable
//  and not needed.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("Twin recurring templates collapse to one series")
@MainActor
struct RecurrenceTwinCollapseTests {

    /// 60 days back, so a monthly series is unambiguously due exactly once.
    private var anchor: Date { Date().addingTimeInterval(-60 * 86_400) }

    private func clearWatermark(_ uuid: UUID) {
        RecurrenceService.clearHandled(for: uuid)
    }

    // MARK: - The row-count bug

    @Test("two rows of one series produce ONE prompt, not one per row")
    func onePromptPerSeriesNotPerRow() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(in: ctx, anchor: anchor)
        clearWatermark(twins.uuid)
        defer { clearWatermark(twins.uuid) }

        let prompts = RecurrenceService.dueRecurring(modelContext: ctx)

        #expect(prompts.count == 1, "one series, one decision to ask the user for")
        #expect(prompts.first?.id == twins.uuid)
    }

    @Test("a single-row series is unaffected by the collapse")
    func singleRowSeriesStillPrompts() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let uuid = UUID()
        RecurrenceTwinFixture.insertTemplate(in: ctx, uuid: uuid, anchor: anchor)
        try ctx.save()
        clearWatermark(uuid)
        defer { clearWatermark(uuid) }

        let prompts = RecurrenceService.dueRecurring(modelContext: ctx)

        #expect(prompts.count == 1)
        #expect(prompts.first?.id == uuid)
    }

    @Test("two DIFFERENT series still produce two prompts")
    func distinctSeriesAreNotCollapsed() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let a = UUID(), b = UUID()
        RecurrenceTwinFixture.insertTemplate(in: ctx, uuid: a, anchor: anchor, merchant: "Netflix")
        RecurrenceTwinFixture.insertTemplate(in: ctx, uuid: b, anchor: anchor, merchant: "Spotify")
        try ctx.save()
        clearWatermark(a); clearWatermark(b)
        defer { clearWatermark(a); clearWatermark(b) }

        let prompts = RecurrenceService.dueRecurring(modelContext: ctx)

        #expect(prompts.count == 2)
        #expect(Set(prompts.map(\.id)) == Set([a, b]))
    }

    // MARK: - Divergent twins: which values survive

    @Test("the collapsed prompt carries the most recently updated twin's values")
    func collapsedPromptTakesNewerTwin() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor,
            olderAmountCents: 5200, newerAmountCents: 7300
        )
        clearWatermark(twins.uuid)
        defer { clearWatermark(twins.uuid) }

        let prompts = RecurrenceService.dueRecurring(modelContext: ctx)

        #expect(prompts.count == 1)
        #expect(prompts.first?.amountCents == 7300, "the edit on the other device wins")
    }

    /// The real test of determinism: the same two twins, inserted in opposite
    /// order into two independent stores — which is exactly what "both devices
    /// run the collapse independently" looks like. Both must land on the same
    /// values without ever comparing notes.
    @Test("both insertion orders resolve to the same twin")
    func collapseIsIndependentOfInsertionOrder() throws {
        let uuid = UUID()
        let anchor = anchor
        clearWatermark(uuid)
        defer { clearWatermark(uuid) }

        func promptAmount(insertNewerFirst: Bool) throws -> Int? {
            let (_, ctx) = try RecurrenceTwinFixture.makeStore()
            RecurrenceTwinFixture.insertTwins(
                in: ctx, uuid: uuid, anchor: anchor,
                olderAmountCents: 5200, newerAmountCents: 7300,
                insertNewerFirst: insertNewerFirst
            )
            return RecurrenceService.dueRecurring(modelContext: ctx).first?.amountCents
        }

        let deviceA = try promptAmount(insertNewerFirst: false)
        let deviceB = try promptAmount(insertNewerFirst: true)

        #expect(deviceA == deviceB, "two devices must not disagree about the same series")
        #expect(deviceA == 7300)
    }

    @Test("merchant divergence resolves the same way as amount divergence")
    func collapsedPromptTakesNewerMerchant() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor,
            olderMerchant: "Netflix", newerMerchant: "Netflix Premium"
        )
        clearWatermark(twins.uuid)
        defer { clearWatermark(twins.uuid) }

        let prompts = RecurrenceService.dueRecurring(modelContext: ctx)

        #expect(prompts.first?.merchant == "Netflix Premium")
    }

    // MARK: - Confirming has to materialize the SAME twin the prompt showed

    /// Collapsing the prompt is worthless if `confirm()` then copies the other
    /// twin: the user would approve 73.00 and get a 52.00 row.
    @Test("confirm materializes the values the prompt showed")
    func confirmMaterializesCanonicalTwin() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor,
            olderAmountCents: 5200, newerAmountCents: 7300
        )
        clearWatermark(twins.uuid)
        defer { clearWatermark(twins.uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)
        RecurrenceService.confirm(prompt, modelContext: ctx)

        let instances = try ctx.fetch(
            FetchDescriptor<Transaction>(predicate: #Predicate { $0.recurrenceRaw == nil })
        )
        #expect(instances.count == 1, "one confirmation, one ledger row")
        #expect(instances.first?.amountCents == prompt.amountCents)
        #expect(instances.first?.amountCents == 7300)
    }
}
