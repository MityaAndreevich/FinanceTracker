//
//  RecurrencePromptResolutionTests.swift
//  FinanceTrackerTests
//
//  Step 1 of PLAN_RECURRENCE_SYNC_IDENTITY: a due prompt resolves back to its
//  template by `PersistentIdentifier`, not by `uuid`.
//
//  Step 2 already made the uuid lookup pick the *canonical* twin rather than an
//  arbitrary one, which is why this needs a test that can tell the two apart at
//  all. The distinguishing scenario is the one sync actually produces: the store
//  changes between the moment the prompt is built and the moment the user taps
//  Add. A uuid lookup re-runs the canonical rule against the NEW state and can
//  hand back a different row than the one the user was shown; an identifier
//  stays pinned to the row that was on screen.
//
//  The deletion cases are the payoff of DeletedModelIdentifierTests: resolution
//  has to come back empty, not trap, when the template was removed on another
//  device between prompt and tap.
//

import Foundation
import Testing
import SwiftData
@testable import FinanceTracker

@Suite("A due prompt resolves to its template by identifier")
@MainActor
struct RecurrencePromptResolutionTests {

    private var anchor: Date { Date().addingTimeInterval(-60 * 86_400) }

    private func instances(in ctx: ModelContext) throws -> [Transaction] {
        try ctx.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.recurrenceRaw == nil }))
    }

    @Test("the prompt carries the canonical template's identifier")
    func promptCarriesCanonicalIdentifier() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor,
            olderAmountCents: 5200, newerAmountCents: 7300
        )
        RecurrenceService.clearHandled(for: twins.uuid)
        defer { RecurrenceService.clearHandled(for: twins.uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)

        #expect(prompt.templateID == twins.newer.persistentModelID)
        #expect(prompt.templateID != twins.older.persistentModelID)
    }

    /// The scenario a uuid lookup cannot survive: the other device's edit lands
    /// between the prompt being built and the user tapping Add, flipping which
    /// twin the canonical rule picks. The user must get the row they approved.
    @Test("confirm stays pinned to the row the prompt showed when the store changes underneath")
    func confirmIsPinnedAcrossACanonicalFlip() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor,
            olderAmountCents: 5200, newerAmountCents: 7300
        )
        RecurrenceService.clearHandled(for: twins.uuid)
        defer { RecurrenceService.clearHandled(for: twins.uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)
        #expect(prompt.amountCents == 7300, "the prompt shows the newer twin")

        // A replicated edit arrives for the OTHER twin, making it canonical.
        twins.older.updatedAt = twins.newer.updatedAt.addingTimeInterval(3600)
        try ctx.save()
        #expect(
            RecurrenceService.canonicalTemplate(among: [twins.older, twins.newer])?.amountCents == 5200,
            "precondition: the canonical rule now prefers the other twin"
        )

        RecurrenceService.confirm(prompt, modelContext: ctx)

        let posted = try instances(in: ctx)
        #expect(posted.count == 1)
        #expect(posted.first?.amountCents == 7300, "the user gets what they approved, not what re-resolution found")
    }

    @Test("confirm on a template deleted since the prompt is a no-op, not a crash")
    func confirmOnDeletedTemplateIsNoOp() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let uuid = UUID()
        let template = RecurrenceTwinFixture.insertTemplate(in: ctx, uuid: uuid, anchor: anchor)
        try ctx.save()
        RecurrenceService.clearHandled(for: uuid)
        defer { RecurrenceService.clearHandled(for: uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)

        ctx.delete(template)
        try ctx.save()

        RecurrenceService.confirm(prompt, modelContext: ctx)

        #expect(try instances(in: ctx).isEmpty, "no template, no ledger row")
    }

    @Test("skip on a template deleted since the prompt still advances the boundary")
    func skipOnDeletedTemplateStillAdvances() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let uuid = UUID()
        let template = RecurrenceTwinFixture.insertTemplate(in: ctx, uuid: uuid, anchor: anchor)
        try ctx.save()
        RecurrenceService.clearHandled(for: uuid)
        defer { RecurrenceService.clearHandled(for: uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)

        ctx.delete(template)
        try ctx.save()

        RecurrenceService.skip(prompt, modelContext: ctx)

        #expect(RecurrenceService.handledDate(for: uuid) != nil)
    }

    /// The shape `DashboardView.handleEditRecurring` needs (audit site 1.2):
    /// one shared resolver, so the Edit prefill cannot come from a different
    /// twin than the prompt displayed.
    @Test("the shared resolver returns the prompt's own row")
    func sharedResolverReturnsPromptRow() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let twins = RecurrenceTwinFixture.insertTwins(
            in: ctx, anchor: anchor,
            olderAmountCents: 5200, newerAmountCents: 7300
        )
        RecurrenceService.clearHandled(for: twins.uuid)
        defer { RecurrenceService.clearHandled(for: twins.uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)
        let resolved = RecurrenceService.template(for: prompt, modelContext: ctx)

        #expect(resolved?.persistentModelID == twins.newer.persistentModelID)
        #expect(resolved?.amountCents == 7300)
    }

    @Test("the shared resolver returns nil for a deleted template")
    func sharedResolverReturnsNilWhenDeleted() throws {
        let (_, ctx) = try RecurrenceTwinFixture.makeStore()
        let uuid = UUID()
        let template = RecurrenceTwinFixture.insertTemplate(in: ctx, uuid: uuid, anchor: anchor)
        try ctx.save()
        RecurrenceService.clearHandled(for: uuid)
        defer { RecurrenceService.clearHandled(for: uuid) }

        let prompt = try #require(RecurrenceService.dueRecurring(modelContext: ctx).first)
        ctx.delete(template)
        try ctx.save()

        #expect(RecurrenceService.template(for: prompt, modelContext: ctx) == nil)
    }
}
