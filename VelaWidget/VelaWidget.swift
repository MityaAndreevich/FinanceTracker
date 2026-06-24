//
//  VelaWidget.swift
//  VelaWidget
//
//  Read-only Home Screen widget showing the current month's NET. Reads a
//  pre-computed NetSnapshot from the shared App Group — never opens SwiftData,
//  never hits the network. Refreshes once per day (.after next midnight).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct VelaEntry: TimelineEntry {
    let date: Date
    let snapshot: NetSnapshot
}

struct VelaProvider: TimelineProvider {
    func placeholder(in context: Context) -> VelaEntry {
        VelaEntry(date: Date(), snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (VelaEntry) -> Void) {
        completion(VelaEntry(date: Date(), snapshot: NetSnapshot.load() ?? .placeholder()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VelaEntry>) -> Void) {
        let entry = VelaEntry(date: Date(), snapshot: NetSnapshot.load() ?? .placeholder())

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

private let velaMint = Color(red: 0.239, green: 0.863, blue: 0.592) // #3DDC97

private extension NetSnapshot {
    var heroColor: Color { isPositive ? .green : .red }
    var directionSymbol: String { isPositive ? "arrow.up.right" : "arrow.down.right" }
}

// MARK: - Entry view

struct VelaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: VelaEntry

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
            HStack { Spacer(); Image(systemName: "chart.line.uptrend.xyaxis").font(.caption).foregroundStyle(velaMint) }
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
struct VelaWidget: Widget {
    private let kind = "VelaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VelaProvider()) { entry in
            VelaWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Vela")
        .description("See your monthly net at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
