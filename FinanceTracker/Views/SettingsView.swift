//
//  SettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var newCategoryTypeRaw: String = "expense"
    @State private var newCategoryIcon: String = ""

    // MARK: - Alerts
    @State private var showBlockedDeleteAlert = false
    @State private var blockedDeleteMessage = ""
    
    // MARK: - Export
    @State private var exportURL: URL?
    @State private var exportFilename: String = ""
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    
    // MARK: - Import
    @State private var showImporter = false
    @State private var showImportResult = false
    @State private var importResultMessage = ""
    
    // MARK: - Purchases
    @StateObject private var pm = PurchaseManager.shared
    @State private var showPaywall = false
    
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
            
            Section("Data") {

                Button("Export CSV (This Month)") {
                    exportCSV(scope: .month)
                }

                Button("Export CSV (All)") {
                    if pm.isPremium {
                        exportCSV(scope: .all)
                    } else {
                        showPaywall = true
                    }
                }

                Button("Import CSV") {
                    if pm.isPremium {
                        showImporter = true
                    } else {
                        showPaywall = true
                    }
                }

                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Share last export (\(exportFilename))", systemImage: "square.and.arrow.up")
                    }
                }

                if !pm.isPremium {
                    Text("Premium unlocks Import CSV and Export All.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .navigationTitle("title.settings")
        .onTapGesture { hideKeyboard() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import result", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .alert("Can't delete", isPresented: $showBlockedDeleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(blockedDeleteMessage)
        }
        .alert("Export error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
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
        let toDelete = offsets.map { sources[$0] }

        var blocked: [(String, Int)] = []
        var allowed: [Source] = []

        for source in toDelete {
            let count = countTransactions(using: source)
            if count > 0 {
                blocked.append((source.name, count))
            } else {
                allowed.append(source)
            }
        }

        if !blocked.isEmpty {
            blockedDeleteMessage = blocked
                .map { "“\($0.0)” is used in \($0.1) transaction(s)." }
                .joined(separator: "\n")
            showBlockedDeleteAlert = true
        }

        guard !allowed.isEmpty else { return }

        for source in allowed {
            modelContext.delete(source)
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
        let toDelete = offsets.map { subset[$0] }

        var blocked: [(String, Int)] = []
        var allowed: [Category] = []

        for cat in toDelete {
            let count = countTransactions(using: cat)
            if count > 0 {
                blocked.append((cat.name, count))
            } else {
                allowed.append(cat)
            }
        }

        if !blocked.isEmpty {
            blockedDeleteMessage = blocked
                .map { "“\($0.0)” is used in \($0.1) transaction(s)." }
                .joined(separator: "\n")
            showBlockedDeleteAlert = true
        }

        guard !allowed.isEmpty else { return }

        for cat in allowed {
            modelContext.delete(cat)
        }
        saveContext()
    }
    
    //MARK: - Import
    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            // Security scoped resource для Files
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)

            let importResult = try CSVImportService.importCSV(modelContext: modelContext, data: data)

            var lines: [String] = []
            lines.append("Imported: \(importResult.imported)")
            lines.append("Skipped: \(importResult.skipped)")
            lines.append("Created categories: \(importResult.createdCategories)")
            lines.append("Created sources: \(importResult.createdSources)")
            if let first = importResult.firstError {
                lines.append("First error: \(first)")
            }

            importResultMessage = lines.joined(separator: "\n")
            showImportResult = true

        } catch {
            importResultMessage = "Import failed: \(error.localizedDescription)"
            showImportResult = true
        }
    }
    // MARK: - Export
    private func exportCSV(scope: CSVExportScope) {
        do {
            let result = try CSVExportService.makeCSV(modelContext: modelContext, scope: scope)
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)

            exportURL = url
            exportFilename = result.filename
        } catch {
            exportErrorMessage = "Export failed: \(error.localizedDescription)"
            showExportError = true
        }
    }

    // MARK: - Safe counts (reference checks)

    /// Сколько транзакций ссылаются на категорию
    private func countTransactions(using category: Category) -> Int {
        do {
            let categoryId = category.id
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in
                    tx.category.id == categoryId
                }
            )
            return try modelContext.fetchCount(descriptor)
        } catch {
            // fallback (если вдруг SwiftData/Predicate начнёт капризничать)
            do {
                let all = try modelContext.fetch(FetchDescriptor<Transaction>())
                return all.filter { $0.category.id == category.id }.count
            } catch {
                return 0
            }
        }
    }

    /// Сколько транзакций ссылаются на source (source может быть nil)
    private func countTransactions(using source: Source) -> Int {
        do {
            let sourceId = source.id
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { tx in
                    tx.source?.id == sourceId
                }
            )
            return try modelContext.fetchCount(descriptor)
        } catch {
            // fallback
            do {
                let all = try modelContext.fetch(FetchDescriptor<Transaction>())
                return all.filter { $0.source?.id == source.id }.count
            } catch {
                return 0
            }
        }
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


// MARK: - Helpers

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
