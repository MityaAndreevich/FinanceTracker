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
        .alert("cs.alert.cant_delete.title", isPresented: $showBlockedDeleteAlert) {
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

            Button { showAddCategory = true } label: {
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
        .presentationDetents([.medium])
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

    @State private var showIconPicker = false

    var body: some View {
        NavigationStack {
            Form {
                suggestedSection

                Section {
                    TextField("cs.category_sheet.name.placeholder", text: $name)

                    Picker("add.type.picker.title", selection: $typeRaw) {
                        Text("add.type.expense").tag("expense")
                        Text("add.type.income").tag("income")
                    }
                    .pickerStyle(.segmented)

                    // ✅ Icon selector row
                    HStack(spacing: 12) {
                        Image(systemName: icon.isEmpty ? "questionmark.square.dashed" : icon)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.secondary)

                        Button {
                            showIconPicker = true
                        } label: {
                            HStack {
                                if icon.isEmpty {
                                    Text("cs.category_sheet.icon.placeholder")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: icon)
                                    Text(icon)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            showIconPicker = true
                        } label: {
                            Text("common.choose")
                        }
                    }

                    Text("cs.category_sheet.icon_hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("addcat.section.custom")
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
            .sheet(isPresented: $showIconPicker) {
                SFSymbolPicker(selected: $icon)
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Suggested presets

    private struct Preset: Identifiable {
        let labelKey: String   // localization key; also resolved to the stored custom name
        let icon: String
        var id: String { labelKey }
    }

    private static let expensePresets: [Preset] = [
        Preset(labelKey: "addcat.preset.bills",     icon: "doc.text.fill"),
        Preset(labelKey: "addcat.preset.pets",      icon: "pawprint.fill"),
        Preset(labelKey: "addcat.preset.gifts",     icon: "gift.fill"),
        Preset(labelKey: "addcat.preset.education", icon: "book.fill"),
        Preset(labelKey: "addcat.preset.fitness",   icon: "dumbbell.fill"),
        Preset(labelKey: "addcat.preset.kids",      icon: "person.2.fill"),
    ]

    private static let incomePresets: [Preset] = [
        Preset(labelKey: "addcat.preset.salary",     icon: "banknote.fill"),
        Preset(labelKey: "addcat.preset.bonus",      icon: "star.fill"),
        Preset(labelKey: "addcat.preset.freelance",  icon: "laptopcomputer"),
        Preset(labelKey: "addcat.preset.investment", icon: "chart.line.uptrend.xyaxis"),
        Preset(labelKey: "addcat.preset.gifts",      icon: "gift.fill"),
        Preset(labelKey: "addcat.preset.refund",     icon: "arrow.uturn.left"),
    ]

    /// Presets for the selected kind, minus any whose name already exists.
    private var availablePresets: [Preset] {
        let existing = Set(
            categories
                .filter { $0.kindRaw == typeRaw }
                .map { $0.displayName().lowercased() }
        )
        let all = typeRaw == "income" ? Self.incomePresets : Self.expensePresets
        return all.filter { !existing.contains(NSLocalizedString($0.labelKey, comment: "").lowercased()) }
    }

    @ViewBuilder
    private var suggestedSection: some View {
        let presets = availablePresets
        if !presets.isEmpty {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(presets) { preset in
                        Button {
                            createPreset(preset)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: preset.icon)
                                    .font(.title3)
                                Text(LocalizedStringKey(preset.labelKey))
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("addcat.section.suggested")
            }
        }
    }

    private func createPreset(_ preset: Preset) {
        let resolved = NSLocalizedString(preset.labelKey, comment: "")
        let nextOrder = (categories.filter { $0.kindRaw == typeRaw }.map(\.order).max() ?? 0) + 1
        let category = Category(
            name: resolved,
            kindRaw: typeRaw,
            icon: preset.icon,
            order: nextOrder,
            nameKey: nil,
            nameCustom: resolved
        )
        modelContext.insert(category)
        try? modelContext.save()
        dismiss()
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let lowerName = trimmed.lowercased()
        let isDuplicate = categories.filter { $0.kindRaw == typeRaw }.contains { cat in
            if let custom = cat.nameCustom?.trimmingCharacters(in: .whitespacesAndNewlines),
               !custom.isEmpty, custom.lowercased() == lowerName { return true }
            if let key = cat.nameKey, !key.isEmpty {
                let loc = NSLocalizedString(key, comment: "").lowercased()
                return loc != key.lowercased() && loc == lowerName
            }
            return false
        }
        guard !isDuplicate else { dismiss(); return }

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

// MARK: - Icon Picker



