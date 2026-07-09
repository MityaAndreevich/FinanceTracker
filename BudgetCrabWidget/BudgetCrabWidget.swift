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
    case ambient
    case minimal

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Style" }
    static var caseDisplayRepresentations: [WidgetStyle: DisplayRepresentation] {
        [.ambient: "Ambient", .minimal: "Minimal"]
    }
}

struct BudgetCrabConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Budget Crab" }
    static var description: IntentDescription { "Choose how the widget looks." }

    @Parameter(title: "Style", default: .ambient)
    var style: WidgetStyle
}

// MARK: - Timeline

struct BudgetCrabEntry: TimelineEntry {
    let date: Date
    let snapshot: NetSnapshot
    var style: WidgetStyle = .ambient
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
    /// A whisper of brand warmth laid over the system material on iOS 26 so the
    /// glass still reads as Budget Crab, not a generic frosted panel. Deliberately
    /// faint — the system owns the glass/refraction; this only tints it.
    static var glassWarmth: Color { widgetBackground.opacity(0.14) }
    /// Calm ambient-chart tint — green only when positive, muted terracotta when
    /// over budget (state comes from heroIsAlert, never hue alone). Low-opacity so
    /// the hero number stays the legible foreground (Direction B ambient layer).
    static func ambient(alert: Bool) -> Color { (alert ? spend : income) }
}

// MARK: - Liquid Glass surface (Item: material)
//
// The material path is SYSTEM-rendered, not hand-rolled. On iOS 26 the widget
// auto-adopts Liquid Glass on recompile; we hand the container a genuine system
// `.regularMaterial` (which the system renders as glass, preserving legibility
// over any wallpaper) with only a faint brand tint on top. `.liquidMaterial` is
// NOT a real SDK symbol — do not reintroduce it. Below iOS 26 there is no Liquid
// Glass, so we fall back to the calm, adaptive OPAQUE card (never flat white).
// No blur/gradient/shadow is hand-built in either path (that fights the material).

private extension View {
    @ViewBuilder
    func liquidGlassSurface() -> some View {
        if #available(iOS 26, *) {
            containerBackground(for: .widget) {
                Rectangle().fill(.regularMaterial)
                    .overlay(Palette.glassWarmth)
            }
        } else {
            containerBackground(for: .widget) { Palette.widgetBackground }
        }
    }
}

// MARK: - Building blocks

/// Ambient cumulative-spend sparkline (Direction B). An area+line drawn by hand
/// with `Path` — NOT Swift Charts — so an out-of-process widget can never trap on
/// a degenerate Charts domain. The caller only renders this when
/// `snapshot.canRenderSpendChart` (≥2 finite, clamped points); values arrive
/// pre-guarded via `safeSpendSeries`. Low opacity so the hero number stays the
/// legible foreground; the tint is calm green normally, muted terracotta when over
/// budget (state from `alert`, never hue alone — the hero also carries icon+word).
private struct AmbientSpendChart: View {
    let series: [Double]        // guarded 0…1, ≥2 points
    let alert: Bool

    var body: some View {
        // Canvas (not a ViewBuilder closure) lets the point math live inline and
        // renders to a static drawing — safe in a widget snapshot. Nothing draws
        // unless there are ≥2 points and a positive size, so no divide-by-zero.
        Canvas { context, size in
            let n = series.count
            let w = size.width, h = size.height
            guard n >= 2, w > 0, h > 0 else { return }
            let tint = Palette.ambient(alert: alert)
            let step = w / CGFloat(n - 1)
            func point(_ i: Int) -> CGPoint {
                CGPoint(x: step * CGFloat(i), y: h * (1 - CGFloat(series[i])))
            }
            var area = Path()
            area.move(to: CGPoint(x: 0, y: h))
            area.addLine(to: point(0))
            for i in 1..<n { area.addLine(to: point(i)) }
            area.addLine(to: CGPoint(x: w, y: h))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.30), tint.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))

            var line = Path()
            line.move(to: point(0))
            for i in 1..<n { line.addLine(to: point(i)) }
            context.stroke(line, with: .color(tint.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}

/// Small translucent chip holding the brand pie glyph (Direction B, top-right).
/// On iOS 26 it's genuine system glass (`glassEffect`); below that, a calm material
/// capsule. The mint glyph is a BRAND mark, not a data signal — the "green = income
/// only" rule governs financial state, which this never encodes.
private struct IconChip: View {
    var body: some View {
        Image(systemName: "chart.pie.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.income)
            .frame(width: 26, height: 26)
            .modifier(ChipGlass())
    }
}

private struct ChipGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

/// Direction B hero: bottom-left weighted, gain-framed number dominant. Over budget
/// the number itself reads restrained terracotta (never alarm-red / full-card fill);
/// otherwise it stays neutral. A green up-tick precedes a genuine safe-to-spend; the
/// neutral "Spent" last-resort state (empty subtitle) shows no tick — no false gain.
private struct DirectionBHero: View {
    let snapshot: NetSnapshot
    var amountSize: CGFloat

    private var showsUpTick: Bool { !snapshot.heroIsAlert && !snapshot.heroSubtitle.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if snapshot.heroIsAlert {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.danger)
                } else if showsUpTick {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.income)      // up-tick, green = positive
                }
                Text(snapshot.heroLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(snapshot.heroIsAlert ? Palette.danger : Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)                   // longest ru/pt-BR labels, no clip
            }
            Text(snapshot.heroAmount)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(snapshot.heroIsAlert ? Palette.spend : Palette.textPrimary)
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

// MARK: - Sizes (Ambient variant — Direction B)

/// Month label + brand chip, the top row shared by all Ambient sizes.
private struct WidgetHeader: View {
    let monthLabel: String
    var size: CGFloat = 11
    var weight: Font.Weight = .medium
    var body: some View {
        HStack {
            Text(monthLabel)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            IconChip()
        }
    }
}

/// The Direction B hero laid over the ambient spend curve (chart pinned to the
/// bottom, hero weighted bottom-left). The chart draws only when the period yields
/// a renderable ≥2-point curve; otherwise the hero simply sits on the calm surface.
private struct AmbientHeroStack: View {
    let snapshot: NetSnapshot
    var chartHeight: CGFloat
    var amountSize: CGFloat
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if snapshot.canRenderSpendChart {
                AmbientSpendChart(series: snapshot.safeSpendSeries, alert: snapshot.heroIsAlert)
                    .frame(height: chartHeight)
                    .frame(maxWidth: .infinity, alignment: .bottom)
            }
            DirectionBHero(snapshot: snapshot, amountSize: amountSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AmbientSmallView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(monthLabel: snapshot.monthLabel)
            Spacer(minLength: 0)
            AmbientHeroStack(snapshot: snapshot, chartHeight: 44, amountSize: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AmbientMediumView: View {
    let snapshot: NetSnapshot
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(monthLabel: snapshot.monthLabel)
                Spacer(minLength: 0)
                AmbientHeroStack(snapshot: snapshot, chartHeight: 42, amountSize: 28)
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
                    ForEach(snapshot.topCategories.prefix(2)) { CategoryRow(item: $0) }   // medium ~2
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AmbientLargeView: View {
    let snapshot: NetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(monthLabel: snapshot.monthLabel, size: 13, weight: .semibold)

            AmbientHeroStack(snapshot: snapshot, chartHeight: 62, amountSize: 40)

            if !snapshot.topCategories.isEmpty {
                Rectangle().fill(Palette.track).frame(height: 1)
                VStack(spacing: 12) {
                    ForEach(snapshot.topCategories.prefix(3)) { CategoryRow(item: $0) }   // large ~3
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
                IconChip()
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
                    IconChip()
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
                IconChip()
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
            case (.ambient, .systemSmall):  AmbientSmallView(snapshot: entry.snapshot)
            case (.ambient, .systemMedium): AmbientMediumView(snapshot: entry.snapshot)
            case (.ambient, _):             AmbientLargeView(snapshot: entry.snapshot)
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
                // System Liquid Glass on iOS 26 (auto-adopted on recompile) with a
                // calm opaque-card fallback below it — see liquidGlassSurface().
                .liquidGlassSurface()
        }
        .configurationDisplayName("Budget Crab")
        .description("See what's safe to spend at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
