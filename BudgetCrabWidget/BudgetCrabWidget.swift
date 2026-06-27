//
//  BudgetCrabWidget.swift
//  BudgetCrabWidget
//
//  Read-only Home Screen widget showing the current month's NET. Reads a
//  pre-computed NetSnapshot from the shared App Group — never opens SwiftData,
//  never hits the network. Refreshes once per day (.after next midnight).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BudgetCrabEntry: TimelineEntry {
    let date: Date
    let snapshot: NetSnapshot
}

struct BudgetCrabProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetCrabEntry {
        BudgetCrabEntry(date: Date(), snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetCrabEntry) -> Void) {
        completion(BudgetCrabEntry(date: Date(), snapshot: NetSnapshot.load() ?? .placeholder()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetCrabEntry>) -> Void) {
        let entry = BudgetCrabEntry(date: Date(), snapshot: NetSnapshot.load() ?? .placeholder())

        // Cheap refresh: recompute month rollover at the next local midnight.
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(24 * 60 * 60)

        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - Palette

private let budgetCrabMint = Color(red: 0.239, green: 0.863, blue: 0.592) // #3DDC97

private extension NetSnapshot {
    var heroColor: Color { isPositive ? .green : .red }
    var directionSymbol: String { isPositive ? "arrow.up.right" : "arrow.down.right" }
}

// MARK: - Entry view

struct BudgetCrabWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BudgetCrabEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium: MediumWidgetView(snapshot: entry.snapshot)
        default:            LargeWidgetView(snapshot: entry.snapshot)
        }
    }
}

private struct HeroView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.monthLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: snapshot.directionSymbol)
                    .font(.headline)
                    .foregroundStyle(snapshot.heroColor)
                Text(snapshot.heroAmount)
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(snapshot.heroColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }
}

private struct SmallWidgetView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Spacer(); Image(systemName: "chart.line.uptrend.xyaxis").font(.caption).foregroundStyle(budgetCrabMint) }
            Spacer()
            HeroView(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumWidgetView: View {
    let snapshot: NetSnapshot
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading) {
                HeroView(snapshot: snapshot)
                Spacer()
                Text(snapshot.spentText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(snapshot.topCategories) { item in
                    HStack {
                        Text(item.name).font(.caption).lineLimit(1)
                        Spacer()
                        Text(item.amount).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LargeWidgetView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeroView(snapshot: snapshot)

            HStack(spacing: 12) {
                Text(snapshot.spentText)
                Text(snapshot.earnedText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if !snapshot.topCategories.isEmpty {
                Divider()
                ForEach(snapshot.topCategories) { item in
                    HStack {
                        Text(item.name).font(.caption).lineLimit(1)
                        Spacer()
                        Text(item.amount).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }

            if !snapshot.recent.isEmpty {
                Divider()
                ForEach(snapshot.recent) { tx in
                    HStack {
                        Text(tx.title).font(.caption).lineLimit(1)
                        Spacer()
                        Text(tx.amount)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(tx.isIncome ? .green : .primary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

@main
struct BudgetCrabWidget: Widget {
    private let kind = "BudgetCrabWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetCrabProvider()) { entry in
            BudgetCrabWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Budget Crab")
        .description("See your monthly net at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
