//
//  CategoryPickerSheet.swift
//  FinanceTracker
//
//  Searchable category picker used to override the auto-detected category in
//  Quick Entry. Filters by transaction kind so income inputs only show income
//  categories and vice versa.
//

import SwiftUI
import SwiftData

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentType: String   // "income" or "expense"
    let onPick: (Category) -> Void

    @State private var search = ""
    @State private var showAddCategory = false
    @Query(sort: \Category.order) private var allCategories: [Category]

    private var filtered: [Category] {
        let typeMatched = allCategories.filter { $0.kindRaw == currentType }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return typeMatched }
        return typeMatched.filter { $0.displayName().lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { cat in
                        Button {
                            onPick(cat)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CategoryIconTile(category: cat, size: 30)
                                Text(cat.displayName())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("category.picker.add_new", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("quickadd.pick_category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet(initialKind: currentType) { newCategory in
                    onPick(newCategory)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
