//
//  DuplicateReviewView.swift
//  FinanceTracker
//
//  The resolve half of the possible-duplicate flag: the flagged rows, with Keep
//  and Delete on each.
//
//  This is deliberately NOT an auto-merge engine. A foreign CSV row carries no
//  stable id, so a content match is genuinely ambiguous — it is either a
//  re-import of a row we already have, or a second real coffee at the same café
//  for the same amount on the same day. Both happen constantly. So we state the
//  ambiguity plainly and let the user resolve it: Keep clears the flag, Delete
//  removes the row. Keep-all is offered before delete-all because only one of
//  them destroys data.
//

import SwiftUI
import SwiftData

struct DuplicateReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<Transaction> { $0.isPossibleDuplicate },
        sort: \Transaction.date,
        order: .reverse
    )
    private var flagged: [Transaction]

    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Group {
                if flagged.isEmpty {
                    emptyState
                } else {
                    reviewList
                }
            }
            .background(Color.bcPage.ignoresSafeArea())
            .navigationTitle("duplicates.review.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
                if !flagged.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("duplicates.review.keep_all") { keepAll() }
                        Spacer()
                        Button("duplicates.review.delete_all", role: .destructive) {
                            confirmDeleteAll = true
                        }
                        .tint(Color.bcDanger)
                    }
                }
            }
            // Bulk delete is the only irreversible action here, so it is the only
            // one that asks. The message says what SURVIVES, not just what goes —
            // the fear at this moment is "will this eat my real transactions?".
            .alert("duplicates.review.delete_all.confirm.title", isPresented: $confirmDeleteAll) {
                Button("common.cancel", role: .cancel) {}
                Button("duplicates.review.delete_all", role: .destructive) { deleteAll() }
            } message: {
                Text("duplicates.review.delete_all.confirm.message")
            }
            .languageReactive()
        }
    }

    private var reviewList: some View {
        List {
            Section {
                ForEach(flagged, id: \.uuid) { tx in
                    row(for: tx)
                }
            } header: {
                Text("duplicates.review.explainer")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bcTextSecondary)
                    .textCase(nil)
                    .padding(.bottom, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(for tx: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CategoryTileRow(tx: tx)

            HStack(spacing: 8) {
                Button {
                    keep(tx)
                } label: {
                    Label("duplicates.review.keep", systemImage: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.bcAccent)

                Button(role: .destructive) {
                    delete(tx)
                } label: {
                    Label("duplicates.review.delete", systemImage: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.bcDanger)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.bcSurface1)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.bcTextMuted)

            Text("duplicates.review.empty.title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)

            Text("duplicates.review.empty.subtitle")
                .font(.system(size: 14))
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func keep(_ tx: Transaction) {
        perform { try DuplicateReviewService.keep(tx, in: modelContext) }
    }

    private func delete(_ tx: Transaction) {
        perform { try DuplicateReviewService.delete(tx, in: modelContext) }
    }

    private func keepAll() {
        perform { try DuplicateReviewService.keepAll(in: modelContext) }
        dismiss()
    }

    private func deleteAll() {
        perform { try DuplicateReviewService.deleteAll(in: modelContext) }
        dismiss()
    }

    private func perform(_ work: () throws -> Void) {
        do { try work() }
        catch {
            #if DEBUG
            print("Duplicate review action failed: \(error.localizedDescription)")
            #endif
        }
    }
}
