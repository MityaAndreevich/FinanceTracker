//
//  BudgetCrabWidget.swift
//  BudgetCrabWidget
//
//  Read-only Home Screen widget. Reads a pre-computed NetSnapshot from the
//  shared App Group — never opens SwiftData, never hits the network. Refreshes
//  once per day (.after next midnight).
//
//  v1.0.1 redesign: leads with **Safe to spend** (gain-framed) + a spent-vs-
//  budget progress ring, calm/rounded to match the app. Green is reserved for
//  income only; spend reads muted terracotta, never alarm-red. The extension is
//  a dumb renderer: all copy + fractions arrive baked & guarded in the snapshot;
//  this file only re-guards ring/bar values and paints them.
//

import WidgetKit
import SwiftUI
import UIKit
import AppIntents

// MARK: - Configuration (Item 6)
//
// Two layout variants, picked the Apple way — in the widget's edit mode via an
// AppIntent, NOT an in-app setting. Both obey the same baked snapshot: gain-framed
// hero, calm palette, icon+label over-budget, no truncation.
//
// The edit-mode chrome below (Style / Ring / Minimal / description) is localized via
// the extension's own Localizable.strings (Item 4). This is CORRECT and distinct
// from the baked snapshot: AppIntent configuration labels are static extension
// chrome shown in iOS's widget edit sheet, which resolves against the SYSTEM
// language — exactly like Apple's own widget config. The baked *snapshot content*
// still follows the app's chosen language and stays key-free; do not route it here.

enum WidgetStyle: String, AppEnum {
    case ring
    case minimal

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Style" }
    static var caseDisplayRepresentations: [WidgetStyle: DisplayRepresentation] {
        [.ring: "Ring", .minimal: "Minimal"]
    }
}

struct BudgetCrabConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Budget Crab" }
    static var description: IntentDescription { "Choose how the widget looks." }

    @Parameter(title: "Style", default: .ring)
    var style: WidgetStyle
}

// MARK: - Timeline

struct BudgetCrabEntry: TimelineEntry {
    let date: Date
    let snapshot: NetSnapshot
    var style: WidgetStyle = .ring
}

struct BudgetCrabProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BudgetCrabEntry {
        BudgetCrabEntry(date: Date(), snapshot: .placeholder())
    }

    func snapshot(for configuration: BudgetCrabConfigurationIntent, in context: Context) async -> BudgetCrabEntry {
        BudgetCrabEntry(date: Date(), snapshot: NetSnapshot.load() ?? .placeholder(), style: configuration.style)
    }

    func timeline(for configuration: BudgetCrabConfigurationIntent, in context: Context) async -> Timeline<BudgetCrabEntry> {
        let entry = BudgetCrabEntry(date: Date(),
                                    snapshot: NetSnapshot.load() ?? .placeholder(),
                                    style: configuration.style)

        // Cheap refresh: recompute month rollover at the next local midnight.
        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(24 * 60 * 60)

        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

// MARK: - Palette
//
// The widget extension has no asset catalog, so the app's `bc*` colorsets aren't
// available here. These mirror them EXACTLY (values pulled from
// Assets.xcassets/bc*.colorset + Color+Semantic.swift) as dynamic light/dark
// providers. Source of truth stays the app's tokens — keep in sync if they move.
// Rule (locked): green = income/positive only; spend = muted terracotta, never
// alarm-red; ring track = neutral surface.

private enum Palette {
    private static func dyn(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: dark.0, green: dark.1, blue: dark.2, alpha: 1)
            : UIColor(red: light.0, green: light.1, blue: light.2, alpha: 1) })
    }
    private static func hex(_ r: Int, _ g: Int, _ b: Int) -> (Double, Double, Double) {
        (Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }

    /// Brand mint — income / positive only (bcPositive / bcAccent).
    static let income      = dyn(hex(0x17, 0xB4, 0x7D), hex(0x3D, 0xDC, 0x97))
    /// Muted terracotta for spend (bcExpense) — the ring fill + category bars.
    /// Also the over-budget signal: a SOFTENED danger, never alarm-red (Item 2.4).
    static let spend       = dyn((0.75, 0.33, 0.24), (0.91, 0.53, 0.44))
    /// Kept for the small warning glyph only — the number/ring never go full red.
    static let danger      = dyn(hex(0xB0, 0x43, 0x33), hex(0xE0, 0x6A, 0x59))
    /// Warm branded widget surface — replaces the flat white card (Item 2.2).
    /// Adapts to Light/Dark; the system handles home-screen tinting on top.
    static let widgetBackground = dyn(hex(0xFA, 0xF7, 0xF2), hex(0x12, 0x16, 0x1D))
    /// Neutral bar / divider channel (visible on the warm surface, unlike the old
    /// near-white F4F2EC that read at 1.12:1 — the "worm" track, Item 2.1).
    static let track       = dyn(hex(0xE4, 0xDF, 0xD5), hex(0x28, 0x30, 0x40))
    /// Ring channel: a dim tint of the fill (Activity-ring style) so a low-progress
    /// arc always reads against a visible track rather than as a floating smudge.
    static var ringTrack: Color { spend.opacity(0.20) }
    static let textPrimary = dyn(hex(0x14, 0x18, 0x1F), hex(0xF2, 0xF5, 0xF9))
    static let textSecondary = dyn(hex(0x5F, 0x6B, 0x7A), hex(0x9A, 0xA6, 0xB8))
    static let textMuted   = dyn(hex(0x64, 0x6D, 0x7C), hex(0x7A, 0x86, 0x98))
}

// MARK: - Building blocks

/// Progress ring. Fraction is re-guarded on the way in so a corrupt/NaN blob can
/// never draw a negative or oversized arc (same discipline as ChartGuards).
private struct RingGauge<Center: View>: View {
    let fraction: Double
    let isNeutral: Bool
    let lineWidth: CGFloat
    @ViewBuilder var center: () -> Center

    private var safe: Double {
        guard fraction.isFinite else { return 0 }
        return min(max(fraction, 0), 1)
    }

    var body: some View {
        ZStack {
            // Visible ring channel (Activity-style) so an empty/low ring never
            // reads as a smudge on a near-white card (Item 2.1).
            Circle()
                .stroke(Palette.ringTrack, lineWidth: lineWidth)
            if !isNeutral {
                // A real (non-neutral) value always draws at least a short arc, so
                // low progress reads as an arc with a rounded cap — not a dot/worm.
                Circle()
                    .trim(from: 0, to: max(safe, 0.03))
                    .stroke(Palette.spend, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            center()
        }
    }
}

/// One top-category row: symbol chip, name, mini spend bar, compact amount.
private struct CategoryRow: View {
    let item: NetSnapshot.Item

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.spend)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)   // absorb long category names, no ellipsis
                    Spacer(minLength: 4)
                    Text(item.amount)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                MiniBar(fraction: item.safeFraction)
            }
        }
    }
}

private struct MiniBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule().fill(Palette.spend)
                    .frame(width: max(geo.size.width * min(max(fraction, 0), 1), 3))
            }
        }
        .frame(height: 4)
    }
}

/// The period/state label. Over-budget adds a warning glyph + softened-danger
/// text so the danger reads without relying on hue alone (Item 2.4; ~8% of users
/// are red-green colorblind). `minimumScaleFactor` + `lineLimit(1)` absorb the
/// longest localized labels (ru/pt-BR) without an ellipsis (Item 2.3).
private struct HeroLabel: View {
    let snapshot: NetSnapshot
    var body: some View {
        HStack(spacing: 4) {
            if snapshot.heroIsAlert {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.danger)
            }
            Text(snapshot.heroLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(snapshot.heroIsAlert ? Palette.danger : Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Hero readout: label, big compact amount, optional "of $Y" subline. The number
/// stays neutral even when over budget — the alert is carried by HeroLabel's
/// icon+word, not a large red figure (Item 2.4).
private struct HeroBlock: View {
    let snapshot: NetSnapshot
    var amountSize: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HeroLabel(snapshot: snapshot)
            Text(snapshot.heroAmount)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !snapshot.heroSubtitle.isEmpty {
                Text(snapshot.heroSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// Small brand mark shown in a corner so the widget always reads as Budget Crab.
private struct BrandMark: View {
    var body: some View {
        Image(systemName: "chart.pie.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.income)
    }
}

// MARK: - Sizes

private struct SmallWidgetView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(snapshot.monthLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                BrandMark()
            }
            Spacer(minLength: 0)
            RingGauge(fraction: snapshot.ringFraction, isNeutral: snapshot.ringIsNeutral, lineWidth: 8) {
                Text(snapshot.heroAmount)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
            .frame(width: 96, height: 96)
            Spacer(minLength: 0)
            HeroLabel(snapshot: snapshot)
        }
    }
}

private struct MediumWidgetView: View {
    let snapshot: NetSnapshot
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snapshot.monthLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    BrandMark()
                }
                Spacer(minLength: 0)
                RingGauge(fraction: snapshot.ringFraction, isNeutral: snapshot.ringIsNeutral, lineWidth: 9) {
                    Text(snapshot.heroAmount)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
                .frame(width: 84, height: 84)
                HeroLabel(snapshot: snapshot)
            }
            .frame(maxWidth: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                if snapshot.topCategories.isEmpty {
                    Spacer()
                    Text(snapshot.spentText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Spacer()
                } else {
                    ForEach(snapshot.topCategories) { CategoryRow(item: $0) }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LargeWidgetView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(snapshot.monthLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                BrandMark()
            }

            HStack(spacing: 18) {
                RingGauge(fraction: snapshot.ringFraction, isNeutral: snapshot.ringIsNeutral, lineWidth: 12) {
                    EmptyView()
                }
                .frame(width: 88, height: 88)
                HeroBlock(snapshot: snapshot, amountSize: 34)
                Spacer(minLength: 0)
            }

            if !snapshot.topCategories.isEmpty {
                Rectangle().fill(Palette.track).frame(height: 1)
                VStack(spacing: 12) {
                    ForEach(snapshot.topCategories) { CategoryRow(item: $0) }
                }
            }

            Spacer(minLength: 0)

            Rectangle().fill(Palette.track).frame(height: 1)
            HStack {
                Text(snapshot.spentText)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(snapshot.earnedText)
                    .foregroundStyle(Palette.income)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Minimal variant (Item 6)
//
// Number-forward: the safe-to-spend figure dominates, with a slim spent-vs-budget
// bar instead of the ring. Same baked snapshot, same calm palette + icon/label
// over-budget signal + no-truncation scaling as the Ring variant.

/// Full-width spent-progress bar (the Minimal variant's ring stand-in). Re-guards
/// the fraction and shows only the track when there's nothing to fill against.
private struct ProgressBarWide: View {
    let fraction: Double
    let isNeutral: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ringTrack)
                if !isNeutral {
                    Capsule().fill(Palette.spend)
                        .frame(width: max(geo.size.width * min(max(fraction, 0), 1), 6))
                }
            }
        }
        .frame(height: 6)
    }
}

/// Label, dominant amount, optional subline, slim progress bar.
private struct MinimalHero: View {
    let snapshot: NetSnapshot
    var amountSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HeroLabel(snapshot: snapshot)
            Text(snapshot.heroAmount)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if !snapshot.heroSubtitle.isEmpty {
                Text(snapshot.heroSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ProgressBarWide(fraction: snapshot.safeRingFraction, isNeutral: snapshot.ringIsNeutral)
                .padding(.top, 2)
        }
    }
}

private struct MinimalSmallView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.monthLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                BrandMark()
            }
            Spacer(minLength: 0)
            MinimalHero(snapshot: snapshot, amountSize: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MinimalMediumView: View {
    let snapshot: NetSnapshot
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snapshot.monthLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    BrandMark()
                }
                Spacer(minLength: 0)
                MinimalHero(snapshot: snapshot, amountSize: 30)
            }
            .frame(maxWidth: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                if snapshot.topCategories.isEmpty {
                    Spacer()
                    Text(snapshot.spentText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Spacer()
                } else {
                    ForEach(snapshot.topCategories) { CategoryRow(item: $0) }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MinimalLargeView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(snapshot.monthLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                BrandMark()
            }

            MinimalHero(snapshot: snapshot, amountSize: 40)

            if !snapshot.topCategories.isEmpty {
                Rectangle().fill(Palette.track).frame(height: 1)
                VStack(spacing: 12) {
                    ForEach(snapshot.topCategories) { CategoryRow(item: $0) }
                }
            }

            Spacer(minLength: 0)

            Rectangle().fill(Palette.track).frame(height: 1)
            HStack {
                Text(snapshot.spentText)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(snapshot.earnedText)
                    .foregroundStyle(Palette.income)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Entry view

struct BudgetCrabWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BudgetCrabEntry

    var body: some View {
        Group {
            switch (entry.style, family) {
            case (.minimal, .systemSmall):  MinimalSmallView(snapshot: entry.snapshot)
            case (.minimal, .systemMedium): MinimalMediumView(snapshot: entry.snapshot)
            case (.minimal, _):             MinimalLargeView(snapshot: entry.snapshot)
            case (.ring, .systemSmall):     SmallWidgetView(snapshot: entry.snapshot)
            case (.ring, .systemMedium):    MediumWidgetView(snapshot: entry.snapshot)
            case (.ring, _):                LargeWidgetView(snapshot: entry.snapshot)
            }
        }
        .widgetURL(WidgetSharing.widgetURL)
    }
}

// MARK: - Widget

@main
struct BudgetCrabWidget: Widget {
    private let kind = "BudgetCrabWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: BudgetCrabConfigurationIntent.self,
                               provider: BudgetCrabProvider()) { entry in
            BudgetCrabWidgetEntryView(entry: entry)
                // Warm branded surface that adapts to Light/Dark; the system applies
                // home-screen tinting on top of it (Item 2.2 — no more flat white).
                .containerBackground(for: .widget) { Palette.widgetBackground }
        }
        .configurationDisplayName("Budget Crab")
        .description("See what's safe to spend at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
