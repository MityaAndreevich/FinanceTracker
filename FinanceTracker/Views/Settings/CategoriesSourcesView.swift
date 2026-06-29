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

    @State private var showBlockedDeleteAlert = false
    @State private var blockedDeleteMessage = ""

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
        .confirmationToast($toastMessage)
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
                .onDelete(perform: deleteSources)
            }

            Button { activeSheet = .source } label: {
                Label("cs.sources.add", systemImage: "plus")
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
                    deleteCategories(from: expenseCategories, at: offsets)
                }
            }

            Button { activeSheet = .category } label: {
                Label("cs.categories.add", systemImage: "plus")
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
                    deleteCategories(from: incomeCategories, at: offsets)
                }
            }

            Button { activeSheet = .category } label: {
                Label("cs.categories.add", systemImage: "plus")
            }
        } header: {
            Text("cs.section.income_categories")
        }
    }

    // MARK: - Delete Sources

    private func deleteSources(at offsets: IndexSet) {
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

    private func deleteCategories(from subset: [Category], at offsets: IndexSet) {
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
        HStack(spacing: 10) {
            if let icon = category.icon, !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("cs.source_sheet.name.placeholder", text: $name)
                    TextField("cs.source_sheet.note.placeholder", text: $note)
                } header: {
                    Text("cs.source_sheet.section")
                }
            }
            .navigationTitle("cs.source_sheet.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        let noteTrimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        let source = Source(name: trimmed, note: noteTrimmed.isEmpty ? nil : noteTrimmed)

                        modelContext.insert(source)
                        try? modelContext.save()
                        onAdded?()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// AddCategorySheet now lives in Views/Components/AddCategorySheet.swift so it can
// be reused from the Quick Entry → CategoryPickerSheet "Add new" path.

// MARK: - Icon Picker



