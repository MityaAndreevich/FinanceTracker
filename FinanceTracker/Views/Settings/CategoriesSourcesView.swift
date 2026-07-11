//
//  CategoriesSourcesView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import SwiftUI
import SwiftData

struct CategoriesSourcesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Source.name, order: .forward)
    private var sources: [Source]

    @Query(sort: \Category.order, order: .forward)
    private var categories: [Category]

    // Single source of truth for the add sheets. Two sibling .sheet(isPresented:)
    // modifiers could wedge UIKit's presentation state ("Attempt to present … which
    // is already presenting …"), leaving the Settings tab unresponsive. A single
    // .sheet(item:) presents at most one at a time.
    private enum ActiveSheet: String, Identifiable {
        case source, category
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet?

    @StateObject private var access = AccessManager.shared
    @State private var showPaywall = false

    @State private var showBlockedDeleteAlert = false
    @State private var blockedDeleteMessage = ""

    // Pending destructive deletion — set by the swipe gesture, performed only after
    // the user confirms in the alert below (data-loss safety, Bug 10).
    @State private var pendingDelete: PendingDelete?
    private enum PendingDelete {
        case sources(IndexSet)
        case categories(subset: [Category], offsets: IndexSet)
    }

    // Bug 9: categories/sources already refresh instantly via @Query — this toast
    // just makes the silent add visible so the user doesn't wonder whether it worked.
    @State private var toastMessage: LocalizedStringKey?

    // MARK: - Derived

    private var expenseCategories: [Category] {
        categories
            .filter { $0.kindRaw == "expense" }
            .sorted { $0.order < $1.order }
    }

    private var incomeCategories: [Category] {
        categories
            .filter { $0.kindRaw == "income" }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            sourcesSection
            expenseSection
            incomeSection
        }
        .navigationTitle("settings.categories")
        .listStyle(.insetGrouped)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .source:   AddSourceSheet { toastMessage = "cs.toast.source_added" }
            case .category: AddCategorySheet { _ in toastMessage = "cs.toast.category_added" }
            }
        }
        .alert("cs.alert.cant_delete.title", isPresented: $showBlockedDeleteAlert) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(blockedDeleteMessage)
        }
        // Confirm destructive category/account deletion before touching the store.
        .alert(
            "common.delete",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("common.cancel", role: .cancel) { pendingDelete = nil }
            Button("common.delete", role: .destructive) { performPendingDelete() }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationToast($toastMessage)
    }

    // MARK: - Free-tier caps
    //
    // The caps gate the ADD button only. Every account and category already in
    // the list stays listed, editable and usable no matter what tier the user is
    // on — including the ones they created during the reverse trial and can no
    // longer re-create. We do not hold data hostage to sell a subscription.

    private var canAddSource: Bool {
        access.canAdd(.addAccountBeyondFreeCap, currentCount: sources.count)
    }

    private var canAddCategory: Bool {
        access.canAdd(.addCustomCategoryBeyondFreeCap,
                      currentCount: categories.customCategoryCount)
    }

    private func attemptAddSource() {
        CapGate.attempt(.addAccountBeyondFreeCap,
                        currentCount: sources.count,
                        access: access,
                        showPaywall: $showPaywall) { activeSheet = .source }
    }

    private func attemptAddCategory() {
        CapGate.attempt(.addCustomCategoryBeyondFreeCap,
                        currentCount: categories.customCategoryCount,
                        access: access,
                        showPaywall: $showPaywall) { activeSheet = .category }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sourcesSection: some View {
        Section {
            if sources.isEmpty {
                Text("cs.sources.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sources, id: \.uuid) { source in
                    SourceRow(source: source)
                }
                .onDelete { offsets in pendingDelete = .sources(offsets) }
            }

            Button { attemptAddSource() } label: {
                Label("cs.sources.add",
                      systemImage: canAddSource ? "plus" : "lock")
            }

            if !canAddSource {
                Text(String(format: NSLocalizedString("cs.sources.cap_hint", comment: ""),
                            FreeTierLimits.maxAccounts))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("cs.section.sources")
        }
    }

    @ViewBuilder
    private var expenseSection: some View {
        Section {
            if expenseCategories.isEmpty {
                Text("cs.expense.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(expenseCategories, id: \.uuid) { cat in
                    CategoryRow(category: cat)
                }
                .onDelete { offsets in
                    pendingDelete = .categories(subset: expenseCategories, offsets: offsets)
                }
            }

            Button { attemptAddCategory() } label: {
                Label("cs.categories.add",
                      systemImage: canAddCategory ? "plus" : "lock")
            }

            if !canAddCategory {
                Text(String(format: NSLocalizedString("cs.categories.cap_hint", comment: ""),
                            FreeTierLimits.maxCustomCategories))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("cs.section.expense_categories")
        }
    }

    @ViewBuilder
    private var incomeSection: some View {
        Section {
            if incomeCategories.isEmpty {
                Text("cs.income.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(incomeCategories, id: \.uuid) { cat in
                    CategoryRow(category: cat)
                }
                .onDelete { offsets in
                    pendingDelete = .categories(subset: incomeCategories, offsets: offsets)
                }
            }

            Button { attemptAddCategory() } label: {
                Label("cs.categories.add",
                      systemImage: canAddCategory ? "plus" : "lock")
            }

            if !canAddCategory {
                Text(String(format: NSLocalizedString("cs.categories.cap_hint", comment: ""),
                            FreeTierLimits.maxCustomCategories))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("cs.section.income_categories")
        }
    }

    // MARK: - Confirmed deletion dispatch

    /// Runs the pending deletion after the user confirms. Deferred to the next
    /// runloop so the confirmation alert finishes dismissing before a follow-up
    /// "can't delete" alert (for in-use items) can present.
    private func performPendingDelete() {
        let request = pendingDelete
        pendingDelete = nil
        DispatchQueue.main.async {
            switch request {
            case .sources(let offsets):
                performDeleteSources(at: offsets)
            case .categories(let subset, let offsets):
                performDeleteCategories(from: subset, at: offsets)
            case .none:
                break
            }
        }
    }

    // MARK: - Delete Sources

    private func performDeleteSources(at offsets: IndexSet) {
        let toDelete = offsets.map { sources[$0] }

        var blocked: [(String, Int)] = []
        var allowed: [Source] = []

        for source in toDelete {
            let count = countTransactions(using: source)
            if count > 0 { blocked.append((source.name, count)) }
            else { allowed.append(source) }
        }

        if !blocked.isEmpty {
            blockedDeleteMessage = blocked
                .map { name, count in
                    String(
                        format: NSLocalizedString("cs.alert.used_in_transactions.format", comment: ""),
                        name, count
                    )
                }
                .joined(separator: "\n")
            showBlockedDeleteAlert = true
        }

        guard !allowed.isEmpty else { return }
        allowed.forEach { modelContext.delete($0) }
        saveContext()
    }

    // MARK: - Delete Categories

    private func performDeleteCategories(from subset: [Category], at offsets: IndexSet) {
        let toDelete = offsets.map { subset[$0] }

        var blocked: [(String, Int)] = []
        var allowed: [Category] = []

        for cat in toDelete {
            let count = countTransactions(using: cat)
            if count > 0 {
                blocked.append((visibleCategoryNameForAlerts(cat), count))
            } else {
                allowed.append(cat)
            }
        }

        if !blocked.isEmpty {
            blockedDeleteMessage = blocked
                .map { name, count in
                    String(
                        format: NSLocalizedString("cs.alert.used_in_transactions.format", comment: ""),
                        name, count
                    )
                }
                .joined(separator: "\n")
            showBlockedDeleteAlert = true
        }

        guard !allowed.isEmpty else { return }
        allowed.forEach { modelContext.delete($0) }
        saveContext()
    }

    private func visibleCategoryNameForAlerts(_ cat: Category) -> String {
        if let custom = cat.nameCustom, !custom.isEmpty { return custom }
        if let k = cat.nameKey, !k.isEmpty {
            let v = NSLocalizedString(k, comment: "")
            return v == k ? k : v
        }
        return cat.name
    }

    // MARK: - Counts

    private func countTransactions(using category: Category) -> Int {
        do {
            let categoryUUID = category.uuid
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in
                    tx.category.uuid == categoryUUID
                }
            )
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    private func countTransactions(using source: Source) -> Int {
        do {
            let sourceUUID = source.uuid
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in
                    tx.source?.uuid == sourceUUID
                }
            )
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    private func saveContext() {
        do { try modelContext.save() }
        catch {
            #if DEBUG
            print("Save failed: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Rows

private struct SourceRow: View {
    let source: Source

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source.name).font(.headline)

            if let note = source.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CategoryRow: View {
    @Bindable var category: Category

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconTile(category: category, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(category.displayKeyOrName))
                Text(LocalizedStringKey(category.isPrimary
                    ? "cs.category.primary_label"
                    : "cs.category.secondary_label"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("cs.category.shown_by_default", isOn: $category.isPrimary)
                .labelsHidden()
        }
    }
}

// MARK: - Sheets

private struct AddSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Fired after a source is successfully inserted (not on cancel).
    var onAdded: (() -> Void)? = nil

    @State private var name = ""
    @State private var note = ""

    // Keyboard dismissal for the two fields (device QA Item 2: the Form left the
    // keyboard up with no return/Done/tap-outside affordance).
    private enum Field { case name, note }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("cs.source_sheet.name.placeholder", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .note }
                    TextField("cs.source_sheet.note.placeholder", text: $note)
                        .focused($focusedField, equals: .note)
                        .submitLabel(.done)
                        .onSubmit { add() }
                } header: {
                    Text("cs.source_sheet.section")
                }
            }
            // Drag anywhere in the form dismisses the keyboard (tap-outside affordance).
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("cs.source_sheet.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.add") { add() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                // Explicit Done above the keyboard — a keyboard-attached field in a
                // Form has no built-in dismiss otherwise (device QA Item 2).
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done") { focusedField = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let noteTrimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(name: trimmed, note: noteTrimmed.isEmpty ? nil : noteTrimmed)

        modelContext.insert(source)
        try? modelContext.save()
        onAdded?()
        dismiss()
    }
}

// AddCategorySheet now lives in Views/Components/AddCategorySheet.swift so it can
// be reused from the Quick Entry → CategoryPickerSheet "Add new" path.

// MARK: - Icon Picker



