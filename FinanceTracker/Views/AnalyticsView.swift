//
//  AnalyticsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    var body: some View {
        let summary = monthlyExpenseByCategory()

        NavigationStack {
            List {
                if summary.isEmpty {
                    Text("No expense data for this month yet")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Top categories (this month)") {
                        ForEach(summary.prefix(3), id: \.categoryId) { row in
                            HStack {
                                Text(row.categoryName)
                                Spacer()
                                Text(formatMoney(cents: row.totalCents))
                                    .font(.headline)
                            }
                        }
                    }

                    Section("All categories") {
                        ForEach(summary, id: \.categoryId) { row in
                            HStack {
                                Text(row.categoryName)
                                Spacer()
                                Text(formatMoney(cents: row.totalCents))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("title.analytics")
        }
    }

    // MARK: - Data

    private func monthlyExpenseByCategory() -> [CategoryExpenseRow] {
        let calendar = Calendar.current
        let now = Date()

        // Берём только траты текущего месяца
        let monthExpenses = transactions.filter {
            $0.typeRaw == "expense" &&
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }

        // Группируем по категории и суммируем
        var dict: [UUID: (name: String, total: Int)] = [:]

        for tx in monthExpenses {
            let id = tx.category.id
            let name = tx.category.name
            let current = dict[id]?.total ?? 0
            dict[id] = (name: name, total: current + tx.amountCents)
        }

        // Превращаем в массив, сортируем по убыванию суммы
        let rows = dict.map { (key, value) in
            CategoryExpenseRow(categoryId: key, categoryName: value.name, totalCents: value.total)
        }

        return rows.sorted { $0.totalCents > $1.totalCents }
    }

    // MARK: - Formatting

    private func formatMoney(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

// MARK: - Row model for UI

private struct CategoryExpenseRow {
    let categoryId: UUID
    let categoryName: String
    let totalCents: Int
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
