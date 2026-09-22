//
//  ReportContentView.swift
//  FinanceTracker
//
//  Renders one `ReportSnapshot`. Pure presentation: it sums nothing, and the
//  only arithmetic it does is the "Other" fold through `CategoryBreakdown.fold`
//  (guarded — a nil fold shows the categories unfolded rather than a wrong
//  "Other").
//

import SwiftUI

struct ReportContentView: View {
    let snapshot: ReportSnapshot
    let currencyCode: String
    @Environment(\.locale) private var locale

    var body: some View {
        summaryCard
        if let budget = snapshot.budget { budgetCard(budget) }
        categoriesCard
        seriesCard
        if !snapshot.largest.isEmpty { largestCard }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("reports.section.summary")
            summaryRow(labelKey: "reports.income", cents: snapshot.totals.incomeCents, isPositive: true,
                       delta: snapshot.comparison?.income, goodWhenUp: true)
            summaryRow(labelKey: "reports.expenses", cents: snapshot.totals.expenseCents, isPositive: false,
                       delta: snapshot.comparison?.expense, goodWhenUp: false)
            Divider()
            summaryRow(labelKey: "reports.net", cents: snapshot.totals.netCents, isPositive: snapshot.totals.netCents >= 0,
                       delta: snapshot.comparison?.net, goodWhenUp: true, emphasize: true)
            Text(String(format: NSLocalizedString("reports.transactions_count.format", comment: ""), snapshot.transactionCount))
                .font(.caption)
                .foregroundStyle(Color.bcTextSecondary)
        }
        .bcCard(padding: 18)
        .accessibilityIdentifier("report_summary_card")
    }

    private func summaryRow(labelKey: LocalizedStringKey, cents: Int, isPositive: Bool,
                            delta: ReportSnapshot.Delta?, goodWhenUp: Bool, emphasize: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(labelKey)
                .font(emphasize ? .headline : .subheadline)
                .foregroundStyle(emphasize ? Color.bcTextPrimary : Color.bcTextSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.formatSigned(cents: abs(cents), isPositive: isPositive, currencyCode: currencyCode))
                    .font(.system(emphasize ? .title3 : .body, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.moneyDirectional(isPositive: isPositive))
                    .privacySensitive(true)
                if let delta {
                    deltaLabel(delta, goodWhenUp: goodWhenUp)
                }
            }
        }
    }

    /// "▲ 12%" / "▼ 4%" / "▲ +1 240 ₽" when there is no base for a percentage.
    private func deltaLabel(_ delta: ReportSnapshot.Delta, goodWhenUp: Bool) -> some View {
        let up = delta.cents > 0
        let flat = delta.cents == 0
        let text: String
        if flat {
            text = NSLocalizedString("reports.compare.unchanged", comment: "")
        } else if let pct = delta.percent {
            text = (up ? "▲ " : "▼ ") + String(format: "%.0f%%", abs(pct))
        } else {
            text = (up ? "▲ " : "▼ ") + Money.format(cents: abs(delta.cents), currencyCode: currencyCode)
        }
        let good = flat || (up == goodWhenUp)
        return Text(text + " " + NSLocalizedString("reports.compare.vs_previous", comment: ""))
            .font(.caption.monospacedDigit())
            .foregroundStyle(flat ? Color.bcTextSecondary : Color.moneyDirectional(isPositive: good))
            .privacySensitive(true)
    }

    // MARK: - Budget (month only)

    private func budgetCard(_ budget: ReportSnapshot.BudgetLine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("reports.section.budget")
            let used = budget.budgetCents > 0 ? min(1, max(0, Double(budget.spentCents) / Double(budget.budgetCents))) : 0
            bar(fraction: used, color: budget.remainingCents < 0 ? Color.bcExpense : Color.bcIncome)
            Text(String(format: NSLocalizedString("reports.budget.line.format", comment: ""),
                        Money.format(cents: budget.budgetCents, currencyCode: currencyCode),
                        Money.format(cents: budget.spentCents, currencyCode: currencyCode),
                        Money.formatSigned(cents: abs(budget.remainingCents), isPositive: budget.remainingCents >= 0, currencyCode: currencyCode)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.bcTextPrimary)
                .privacySensitive(true)
            if budget.overLimitCount == 1 {
                Text("reports.budget.over_limit.one")
                    .font(.caption).foregroundStyle(Color.bcWarningInk)
            } else if budget.overLimitCount > 1 {
                Text(String(format: NSLocalizedString("reports.budget.over_limit.other.format", comment: ""), budget.overLimitCount))
                    .font(.caption).foregroundStyle(Color.bcWarningInk)
            }
        }
        .bcCard(padding: 18)
    }

    // MARK: - Categories

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("reports.section.categories")
            if snapshot.expenseCategories.isEmpty {
                Text("reports.empty.no_expenses")
                    .font(.subheadline)
                    .foregroundStyle(Color.bcTextSecondary)
            } else {
                ForEach(foldedCategories) { row in
                    categoryRow(row)
                }
            }
        }
        .bcCard(padding: 18)
        .accessibilityIdentifier("report_categories_card")
    }

    private struct FoldedRow: Identifiable {
        let id: UUID
        let name: String
        let symbol: String
        let color: Color
        let cents: Int
        let share: Double
    }

    private var foldedCategories: [FoldedRow] {
        let sorted = snapshot.expenseCategories
        let total = snapshot.totals.expenseCents
        func row(_ c: ReportSnapshot.CategoryShare) -> FoldedRow {
            FoldedRow(id: c.bucketID,
                      name: c.label.name.isEmpty ? NSLocalizedString("category.uncategorized", comment: "") : c.label.name,
                      symbol: c.label.symbol,
                      color: c.label.themeKey.map(Category.themeColor(forKey:)) ?? .gray,
                      cents: c.cents, share: c.share)
        }
        guard let fold = CategoryBreakdown.fold(sorted, maxNamed: ReportsView.maxNamedCategories, cents: \.cents) else {
            return sorted.map(row)
        }
        var rows = fold.named.map(row)
        if fold.otherCents > 0 {
            rows.append(FoldedRow(id: CategoryAttribution.uncategorizedBucketID,
                                  name: NSLocalizedString("analytics.breakdown.other", comment: ""),
                                  symbol: "ellipsis",
                                  color: CategoryTheme.map["other"]?.color ?? .gray,
                                  cents: fold.otherCents,
                                  share: total > 0 ? Double(fold.otherCents) / Double(total) : 0))
        }
        return rows
    }

    private func categoryRow(_ row: FoldedRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: row.symbol).foregroundStyle(row.color).frame(width: 22)
                Text(row.name).font(.subheadline).foregroundStyle(Color.bcTextPrimary).lineLimit(1)
                Spacer()
                Text(String(format: "%.0f%%", row.share * 100))
                    .font(.caption.monospacedDigit()).foregroundStyle(Color.bcTextSecondary)
                Text(Money.format(cents: row.cents, currencyCode: currencyCode))
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(Color.bcTextPrimary)
                    .privacySensitive(true)
            }
            bar(fraction: row.share, color: row.color)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Series

    private var seriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(snapshot.seriesGranularity == .day ? "reports.section.series.day" : "reports.section.series.month")
            let maxAbs = max(1, snapshot.series.map { abs($0.netCents) }.max() ?? 1)
            HStack(alignment: .bottom, spacing: snapshot.series.count > 31 ? 1 : 3) {
                ForEach(snapshot.series) { bucket in
                    let h = CGFloat(abs(bucket.netCents)) / CGFloat(maxAbs)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(bucket.netCents >= 0 ? Color.bcIncome : Color.bcExpense)
                            .frame(height: max(2, 56 * h))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .accessibilityLabel(Text(bucket.start.formatted(date: .abbreviated, time: .omitted)))
                    .accessibilityValue(Text(Money.formatSigned(cents: abs(bucket.netCents), isPositive: bucket.netCents >= 0, currencyCode: currencyCode)))
                }
            }
            HStack {
                Text(snapshot.series.first?.start.formatted(date: .abbreviated, time: .omitted) ?? "")
                Spacer()
                Text(snapshot.series.last?.start.formatted(date: .abbreviated, time: .omitted) ?? "")
            }
            .font(.caption2).foregroundStyle(Color.bcTextSecondary)
        }
        .bcCard(padding: 18)
    }

    // MARK: - Largest

    private var largestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("reports.section.largest")
            ForEach(snapshot.largest) { row in
                HStack {
                    Text(row.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(Color.bcTextSecondary).frame(width: 64, alignment: .leading)
                    Text(row.title).font(.subheadline).foregroundStyle(Color.bcTextPrimary).lineLimit(1)
                    Spacer()
                    Text(Money.format(cents: row.amountCents, currencyCode: currencyCode))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(Color.bcTextPrimary)
                        .privacySensitive(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .bcCard(padding: 18)
    }

    // MARK: - Bits

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.bcTextSecondary)
            .textCase(.uppercase)
    }

    private func bar(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bcSeparator.opacity(0.5))
                Capsule().fill(color).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 6)
    }
}
