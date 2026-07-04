//
//  BudgetSetterSheet.swift
//  FinanceTracker
//
//  Lightweight monthly-budget editor presented from the Dashboard (Brief 28-A #1).
//  The budget was previously only reachable in Settings → General, so the "safe to
//  spend" feature was undiscoverable. This sheet is the Dashboard entry point; it
//  reads/writes the same @AppStorage("monthlyBudgetCents") and reuses the existing
//  settings.budget.* strings (no new keys), so the two surfaces stay in lockstep.
//

import SwiftUI

struct BudgetSetterSheet: View {
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents: Int = 0
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"
    @Environment(\.dismiss) private var dismiss

    @State private var budgetText: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("settings.budget.placeholder", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .focused($fieldFocused)
                            .accessibilityIdentifier("dashboard.budget.field")
                        Text(defaultCurrencyCode)
                            .foregroundStyle(.secondary)
                    }

                    if monthlyBudgetCents > 0 {
                        Button("settings.budget.clear", role: .destructive) {
                            monthlyBudgetCents = 0
                            budgetText = ""
                            dismiss()
                        }
                    }
                } header: {
                    Text("settings.budget.label")
                } footer: {
                    Text("settings.budget.caption")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("settings.budget.label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { commit(); dismiss() }
                }
            }
            .onAppear {
                budgetText = monthlyBudgetCents > 0
                    ? Money.plainDecimalString(cents: monthlyBudgetCents)
                    : ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fieldFocused = true }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Blank clears the budget (0 == unset → hero falls back to net-this-month).
    /// Mirrors GeneralSettingView.commitBudget so both entry points behave identically.
    private func commit() {
        let trimmed = budgetText.trimmingCharacters(in: .whitespacesAndNewlines)
        monthlyBudgetCents = trimmed.isEmpty ? 0 : max(0, Money.parseCents(from: trimmed) ?? 0)
    }
}
