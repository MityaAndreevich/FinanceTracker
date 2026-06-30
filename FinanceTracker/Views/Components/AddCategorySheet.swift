//
//  AddCategorySheet.swift
//  FinanceTracker
//
//  Reusable "Add Category" sheet with a Suggested presets grid above a custom
//  input. Used from two entry points:
//    1. Settings → Categories (no callback — just inserts and dismisses)
//    2. Quick Entry → preview → CategoryPickerSheet → "Add new" (onCreate
//       returns the freshly created Category so the picker can apply it)
//
//  Presets create user-defined categories (nameCustom) rather than new seed keys,
//  keeping the deliberately consolidated 13-category default seed intact.
//

import SwiftUI
import SwiftData

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Category.order, order: .forward)
    private var categories: [Category]

    @State private var name = ""
    @State private var typeRaw: String
    @State private var icon = ""

    @State private var showIconPicker = false

    // Surfaced when validation or the SwiftData save fails, instead of crashing
    // or silently swallowing the error (Bug 16 / Bug 17).
    @State private var showSaveError = false
    @State private var saveErrorKey = "add.error.save_failed"

    // Re-entrancy guard: a double-tap on Add / a preset (or the sheet briefly
    // re-presenting) must not insert the category more than once (Bug 17: the
    // cascade produced duplicate rows). Reset only when a save actually fails.
    @State private var isCreating = false

    /// Called with the newly created category when one is added (preset or custom).
    /// The Settings path leaves this nil and relies on the @Query refresh.
    private let onCreate: ((Category) -> Void)?

    init(initialKind: String? = nil, onCreate: ((Category) -> Void)? = nil) {
        _typeRaw = State(initialValue: initialKind ?? "expense")
        self.onCreate = onCreate
    }

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
            .alert("common.error", isPresented: $showSaveError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(saveErrorKey))
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
        insertValidated(name: resolved, icon: preset.icon, order: nextOrder)
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let existingDuplicate = categories.first {
            NewCategoryViewModel.matchesName(trimmed, kindRaw: typeRaw, category: $0)
        }
        if let existingDuplicate {
            if let onCreate {
                // Picker path: typing a name that already exists reuses it rather
                // than creating a second copy.
                onCreate(existingDuplicate)
                dismiss()
            } else {
                // Settings path (no callback): surface the collision instead of
                // dismissing silently (Bug 18). The sheet stays open with the name
                // intact so the user can rename and retry without re-entering data.
                saveErrorKey = "category.error.duplicate_name"
                showSaveError = true
            }
            return
        }

        let nextOrder = (categories.filter { $0.kindRaw == typeRaw }.map(\.order).max() ?? 0) + 1
        insertValidated(name: trimmed, icon: icon, order: nextOrder)
    }

    /// Single insert path shared by presets and the custom field. Validates the
    /// input (Bug 16: an unrenderable icon no longer reaches `save()`), wraps the
    /// save in do-catch (Bug 17: no raw "add.error.save_failed" key, no silent
    /// swallow), and rolls back the insert on failure so no half-saved Category
    /// lingers in the context.
    private func insertValidated(name: String, icon: String, order: Int) {
        guard !isCreating else { return }
        isCreating = true
        switch NewCategoryViewModel.makeCategory(name: name, kindRaw: typeRaw, icon: icon, order: order, existing: categories) {
        case .failure(.emptyName):
            saveErrorKey = "add.error.select_category"
            showSaveError = true
            isCreating = false
        case .failure(.duplicateName):
            // Surface instead of silently dropping the input (Bug 18). Presets are
            // pre-filtered for collisions, so this fires only for the custom field.
            saveErrorKey = "category.error.duplicate_name"
            showSaveError = true
            isCreating = false
        case .failure(.invalidIcon):
            // The picker only offers renderable symbols, so this is defensive:
            // drop the bad icon and retry icon-less rather than block the user.
            switch NewCategoryViewModel.makeCategory(name: name, kindRaw: typeRaw, icon: nil, order: order) {
            case .success(let category): persist(category)
            case .failure:
                saveErrorKey = "add.error.save_failed"
                showSaveError = true
                isCreating = false
            }
        case .success(let category):
            persist(category)
        }
    }

    private func persist(_ category: Category) {
        modelContext.insert(category)
        do {
            try modelContext.save()
        } catch {
            // Roll back so a failed save can't leave a dangling object that a
            // later save would flush (a contributor to the cascade in Bug 17).
            modelContext.delete(category)
            saveErrorKey = "add.error.save_failed"
            showSaveError = true
            isCreating = false
            #if DEBUG
            print("AddCategorySheet save failed: \(error.localizedDescription)")
            #endif
            return
        }
        onCreate?(category)
        dismiss()
    }
}
