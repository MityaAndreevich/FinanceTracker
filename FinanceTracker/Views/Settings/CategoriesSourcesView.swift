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

    @State private var showAddSource = false
    @State private var showAddCategory = false

    @State private var showBlockedDeleteAlert = false
    @State private var blockedDeleteMessage = ""

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
        .sheet(isPresented: $showAddSource) { AddSourceSheet() }
        .sheet(isPresented: $showAddCategory) { AddCategorySheet() }
        .alert(Text("cs.alert.cant_delete.title"), isPresented: $showBlockedDeleteAlert) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(blockedDeleteMessage)
        }
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

            Button { showAddSource = true } label: {
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

            Button { showAddCategory = true } label: {
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
        if let k = cat.nameKey, !k.isEmpty { return NSLocalizedString(k, comment: "") }
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
        catch { print("Save failed: \(error)") }
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
    let category: Category

    var body: some View {
        HStack(spacing: 10) {
            if let icon = category.icon, !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(LocalizedStringKey(category.displayKeyOrName))
        }
    }
}

// MARK: - Sheets

private struct AddSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Category.order, order: .forward)
    private var categories: [Category]

    @State private var name = ""
    @State private var typeRaw = "expense"
    @State private var icon = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("cs.category_sheet.name.placeholder", text: $name)

                    Picker("add.type.picker.title", selection: $typeRaw) {
                        Text("add.type.expense").tag("expense")
                        Text("add.type.income").tag("income")
                    }
                    .pickerStyle(.segmented)

                    TextField("cs.category_sheet.icon.placeholder", text: $icon)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("cs.category_sheet.section")
                }
            }
            .navigationTitle("cs.category_sheet.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.add") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let iconTrimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextOrder = (categories.filter { $0.kindRaw == typeRaw }.map(\.order).max() ?? 0) + 1

        let category = Category(
            name: trimmed,
            kindRaw: typeRaw,
            icon: iconTrimmed.isEmpty ? nil : iconTrimmed,
            order: nextOrder,
            nameKey: nil,
            nameCustom: trimmed
        )

        modelContext.insert(category)
        try? modelContext.save()
        dismiss()
    }
}
