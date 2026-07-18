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

    @StateObject private var access = AccessManager.shared
    @State private var showPaywall = false

    private var filtered: [Category] {
        Self.visibleCategories(allCategories, kind: currentType, search: search)
    }

    /// Categories shown for a given direction and search query: the COMPLETE kind-set
    /// (primary and secondary, including user-created), optionally narrowed by a
    /// case-insensitive name search. Pure and static so the "see them all in one step"
    /// guarantee is unit-testable without standing up the view.
    static func visibleCategories(_ all: [Category], kind: String, search: String) -> [Category] {
        let typeMatched = all.filter { $0.kindRaw == kind }
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
                        attemptAddCategory()
                    } label: {
                        Label("category.picker.add_new",
                              systemImage: canAddCategory ? "plus.circle.fill" : "lock.fill")
                            .foregroundStyle(Color.accentColor)
                    }

                    if !canAddCategory {
                        Text(String(format: NSLocalizedString("cs.categories.cap_hint", comment: ""),
                                    FreeTierLimits.maxCustomCategories))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .searchable(text: $search)
            .plainTextEntry()
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
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Free-tier cap
    //
    // Blocks creating a NEW custom category past the cap. Every category already
    // in this list — seeded or user-made — stays pickable on every tier.

    private var canAddCategory: Bool {
        access.canAdd(.addCustomCategoryBeyondFreeCap,
                      currentCount: allCategories.customCategoryCount)
    }

    private func attemptAddCategory() {
        CapGate.attempt(.addCustomCategoryBeyondFreeCap,
                        currentCount: allCategories.customCategoryCount,
                        access: access,
                        showPaywall: $showPaywall) { showAddCategory = true }
    }
}
