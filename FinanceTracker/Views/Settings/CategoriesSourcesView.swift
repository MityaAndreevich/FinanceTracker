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

    // Sheets
    @State private var showAddSource = false
    @State private var showAddCategory = false

    // Alerts
    @State private var showBlockedDeleteAlert = false
    @State private var blockedDeleteMessage = ""

    var body: some View {
        List {
            Section("Sources") {
                if sources.isEmpty {
                    Text("No sources yet").foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name).font(.headline)
                            if let note = source.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSources)
                }

                Button {
                    showAddSource = true
                } label: {
                    Label("Add Source", systemImage: "plus")
                }
            }

            Section("Expense categories") {
                let expense = categories.filter { $0.kindRaw == "expense" }.sorted { $0.order < $1.order }

                if expense.isEmpty {
                    Text("No expense categories").foregroundStyle(.secondary)
                } else {
                    ForEach(expense) { cat in
                        HStack(spacing: 10) {
                            if let icon = cat.icon, !icon.isEmpty {
                                Image(systemName: icon).foregroundStyle(.secondary)
                            }
                            Text(cat.name)
                        }
                    }
                    .onDelete { offsets in
                        deleteCategories(from: expense, at: offsets)
                    }
                }

                Button {
                    showAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }

            Section("Income categories") {
                let income = categories.filter { $0.kindRaw == "income" }.sorted { $0.order < $1.order }

                if income.isEmpty {
                    Text("No income categories").foregroundStyle(.secondary)
                } else {
                    ForEach(income) { cat in
                        HStack(spacing: 10) {
                            if let icon = cat.icon, !icon.isEmpty {
                                Image(systemName: icon).foregroundStyle(.secondary)
                            }
                            Text(cat.name)
                        }
                    }
                    .onDelete { offsets in
                        deleteCategories(from: income, at: offsets)
                    }
                }
            }
        }
        .navigationTitle("Categories & Sources")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showAddSource) {
            AddSourceSheet()
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet()
        }
        .alert("Can't delete", isPresented: $showBlockedDeleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(blockedDeleteMessage)
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
                .map { "“\($0.0)” is used in \($0.1) transaction(s)." }
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
            if count > 0 { blocked.append((cat.name, count)) }
            else { allowed.append(cat) }
        }

        if !blocked.isEmpty {
            blockedDeleteMessage = blocked
                .map { "“\($0.0)” is used in \($0.1) transaction(s)." }
                .joined(separator: "\n")
            showBlockedDeleteAlert = true
        }

        guard !allowed.isEmpty else { return }
        allowed.forEach { modelContext.delete($0) }
        saveContext()
    }

    // MARK: - Counts

    private func countTransactions(using category: Category) -> Int {
        do {
            let categoryId = category.id
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in tx.category.id == categoryId }
            )
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    private func countTransactions(using source: Source) -> Int {
        do {
            let sourceId = source.id
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in tx.source?.id == sourceId }
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

// MARK: - Sheets

private struct AddSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    TextField("Name (e.g., Amazon Flex)", text: $name)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Add Source")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
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
                Section("Category") {
                    TextField("Name (e.g., Rent, Gas)", text: $name)

                    Picker("Type", selection: $typeRaw) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)

                    TextField("SF Symbol (optional)", text: $icon)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        let iconTrimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
                        let nextOrder = (categories.map(\.order).max() ?? 0) + 1

                        let category = Category(
                            name: trimmed,
                            kindRaw: typeRaw,
                            icon: iconTrimmed.isEmpty ? nil : iconTrimmed,
                            order: nextOrder
                        )

                        modelContext.insert(category)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { CategoriesSourcesView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
