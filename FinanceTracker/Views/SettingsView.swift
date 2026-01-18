//
//  SettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Source.name, order: .forward)
    private var sources: [Source]

    @Query(sort: \Category.order, order: .forward)
    private var categories: [Category]

    // MARK: - New Source
    @State private var newSourceName: String = ""
    @State private var newSourceNote: String = ""

    // MARK: - New Category
    @State private var newCategoryName: String = ""
    @State private var newCategoryTypeRaw: String = "expense" // "expense" or "income"
    @State private var newCategoryIcon: String = ""

    var body: some View {
        Form {
            // ===== Sources =====
            Section("Add source") {
                TextField("Name (e.g., Amazon Flex)", text: $newSourceName)
                TextField("Note (optional)", text: $newSourceNote)

                Button("Add") { addSource() }
                    .disabled(newSourceName.trimmed.isEmpty)
            }

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
            }

            // ===== Categories =====
            Section("Add category") {
                TextField("Name (e.g., Rent, Gas, Gym)", text: $newCategoryName)

                Picker("Type", selection: $newCategoryTypeRaw) {
                    Text("Expense").tag("expense")
                    Text("Income").tag("income")
                }
                .pickerStyle(.segmented)

                TextField("SF Symbol (optional)", text: $newCategoryIcon)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Add") { addCategory() }
                    .disabled(newCategoryName.trimmed.isEmpty)
            }

            Section("Expense categories") {
                let expense = categories.filter { $0.kindRaw == "expense" }.sorted { $0.order < $1.order }

                if expense.isEmpty {
                    Text("No expense categories").foregroundStyle(.secondary)
                } else {
                    ForEach(expense) { cat in
                        HStack(spacing: 10) {
                            if let icon = cat.icon, !icon.isEmpty {
                                Image(systemName: icon)
                                    .foregroundStyle(.secondary)
                            }
                            Text(cat.name)
                        }
                    }
                    .onDelete { offsets in
                        deleteCategories(from: expense, at: offsets)
                    }
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
                                Image(systemName: icon)
                                    .foregroundStyle(.secondary)
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
        .navigationTitle("title.settings")
        .onTapGesture { hideKeyboard() }
    }

    // MARK: - Actions: Sources

    private func addSource() {
        let name = newSourceName.trimmed
        guard !name.isEmpty else { return }

        let note = newSourceNote.trimmed
        let source = Source(name: name, note: note.isEmpty ? nil : note)

        modelContext.insert(source)
        saveContext()

        newSourceName = ""
        newSourceNote = ""
        hideKeyboard()
    }

    private func deleteSources(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sources[index])
        }
        saveContext()
    }

    // MARK: - Actions: Categories

    private func addCategory() {
        let name = newCategoryName.trimmed
        guard !name.isEmpty else { return }

        let icon = newCategoryIcon.trimmed
        let nextOrder = (categories.map(\.order).max() ?? 0) + 1

        let category = Category(
            name: name,
            kindRaw: newCategoryTypeRaw,
            icon: icon.isEmpty ? nil : icon,
            order: nextOrder
        )

        modelContext.insert(category)
        saveContext()

        newCategoryName = ""
        newCategoryIcon = ""
        newCategoryTypeRaw = "expense"
        hideKeyboard()
    }

    private func deleteCategories(from subset: [Category], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(subset[index])
        }
        saveContext()
    }

    // MARK: - Persistence

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Settings save failed: \(error)")
        }
    }
}

// MARK: - Small helpers

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
