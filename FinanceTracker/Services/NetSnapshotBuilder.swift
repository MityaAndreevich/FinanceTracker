//
//  NetSnapshotBuilder.swift
//  FinanceTracker
//
//  Builds the display-ready NetSnapshot for the Home Screen widget from the
//  current month's transactions + the user's monthly budget, and writes it to
//  the shared App Group, then nudges WidgetKit to reload. App-target only (uses
//  Money + SwiftData models).
//
//  v1.0.1 redesign: the widget leads with **Safe to spend** (gain-framed budget
//  remainder) and a spent-vs-budget ring. Every display string + fraction is
//  decided here and frozen into the snapshot so the extension stays a dumb, safe
//  renderer. Fraction/ring math lives in pure static helpers (mirrors
//  PaceMetric) so the guards are unit-testable without SwiftData.
//

import Foundation
import WidgetKit

enum NetSnapshotBuilder {

    /// Build, persist to the App Group, and reload widget timelines.
    ///
    /// Item 5: `languageCode` is the app's chosen in-app language ("system"/"en"/
    /// "ru"/…). The widget is a separate process and does NOT inherit the app's
    /// AppleLanguages/`LocalizedBundle` override, so every string is baked here in
    /// the CHOSEN language (resolved against that language's `.lproj`, not the
    /// widget's system locale). The code is also mirrored into the App Group so the
    /// widget could read it later; today it renders the baked strings as-is.
    static func updateSnapshot(transactions: [Transaction],
                               currencyCode: String,
                               monthlyBudgetCents: Int,
                               languageCode: String) {
        // Mirror the chosen language into the shared container (belt-and-suspenders
        // for a future key-based widget; harmless while strings are baked).
        UserDefaults(suiteName: WidgetSharing.appGroupID)?
            .set(languageCode, forKey: "appLanguageCode")

        // No snapshot rather than a wrong one: the widget keeps whatever it last
        // had, which is stale but true, instead of a figure derived from a total
        // that could not be computed.
        guard let snapshot = build(transactions: transactions,
                                   currencyCode: currencyCode,
                                   monthlyBudgetCents: monthlyBudgetCents,
                                   locale: appLocale(for: languageCode)) else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func build(transactions: [Transaction],
                      currencyCode: String,
                      monthlyBudgetCents: Int,
                      locale: Locale = .current) -> NetSnapshot? {
        let scope = PeriodScope.currentMonth
        let month = scope.filter(transactions)

        // Resolve chrome + category names against the locale's `.lproj` explicitly
        // (displayName(locale:)/String(localized:) would read the swizzled main
        // bundle, i.e. whatever the app process happens to be, not this locale).
        let bundle = chromeBundle(for: locale)
        func L(_ key: String) -> String { bundle.localizedString(forKey: key, value: key, table: nil) }

        // nil = this month cannot be summed in Int. The widget then keeps the
        // snapshot it already has rather than showing a wrong figure — same rule
        // as the alert refresher: a number we cannot compute is not published.
        //
        // THIS SITE WAS MISSED BY THE ENUMERATION. It was catalogued as "widget
        // snapshot", i.e. assumed to be off the launch path — but DashboardView
        // calls refreshWidgetSnapshot() on appear, so it runs during the first
        // render like everything else here. The launch test with a poisoned store
        // is what found it, after four human passes had not.
        guard let incomeCents = MonthTotals.incomeCents(month),
              let expenseCents = MonthTotals.expenseCents(month) else { return nil }

        func compact(_ cents: Int) -> String {
            Money.formatCompact(cents: cents, currencyCode: currencyCode, locale: locale)
        }

        // Top-3 expense categories by spend, each with its curated SF Symbol and
        // its share of this period's spend (for the mini bars).
        // A-path (design doc §2.4 A3): sums CategoryAttribution shares so a
        // split purchase's money lands in the splits' categories. The period
        // totals above stay parent-summed (B-path) — never sum shares there.
        var byBucket: [UUID: (Category?, Int)] = [:]
        for tx in month where !tx.isIncome {
            for share in CategoryAttribution.shares(for: tx) {
                let key = share.category.bucketID
                byBucket[key] = (share.category, (byBucket[key]?.1 ?? 0) + share.amountCents)
            }
        }
        let topCategories: [NetSnapshot.Item] = byBucket.values
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { category, cents in
                NetSnapshot.Item(
                    name: category.displayNameOrFallback(bundle: bundle),
                    symbol: category.symbolNameOrFallback,
                    amount: compact(cents),
                    fraction: categoryFraction(cents: cents, totalSpentCents: expenseCents)
                )
            }

        // Ring: spent-vs-budget, else spent-vs-income, else a neutral track.
        let ring = ringComponents(spentCents: expenseCents,
                                  budgetCents: monthlyBudgetCents,
                                  incomeCents: incomeCents)

        // Hero — gain-framed safe-to-spend (loss pain ≈ 2× gain, so never lead
        // with the loss frame). Precedence lives in the pure helper below.
        let hero = heroComponents(spentCents: expenseCents,
                                  budgetCents: monthlyBudgetCents,
                                  incomeCents: incomeCents,
                                  localize: L,
                                  compact: compact)
        let heroLabel = hero.label
        let heroAmount = hero.amount
        let heroSubtitle = hero.subtitle
        let heroIsAlert = hero.isAlert

        let spentText = String(format: L("widget.spent.format"), compact(expenseCents))
        let earnedText = String(format: L("widget.earned.format"), compact(incomeCents))

        return NetSnapshot(
            monthLabel: scope.label(locale: locale),
            currencyCode: currencyCode,
            heroLabel: heroLabel,
            heroAmount: heroAmount,
            heroSubtitle: heroSubtitle,
            heroIsAlert: heroIsAlert,
            ringFraction: ring.fraction,
            ringIsNeutral: ring.isNeutral,
            spentText: spentText,
            earnedText: earnedText,
            topCategories: topCategories,
            spendSeries: cumulativeDailySpend(month),
            hasData: !month.isEmpty || monthlyBudgetCents > 0,
            generatedAt: Date()
        )
    }

    // MARK: - Ambient spend curve (Direction B)

    /// Cumulative daily spend for the current month, normalized 0…1 by the period's
    /// total spend — one value per elapsed day (day 1 … today). The ambient
    /// sparkline plots these by index; its *shape* shows spend pace through the
    /// month. Self-relative on purpose: the spent-vs-budget magnitude is carried by
    /// the ring + hero, so the curve stays visible whatever the budget size.
    ///
    /// Returns `nil` — the widget's signal to draw NO chart — for every case that
    /// can't form an honest continuous curve, applying the ChartGuards discipline
    /// at the source:
    ///   • no spend at all (total 0 → the normalizing divide-by-zero), or
    ///   • fewer than 2 elapsed days (a 1-point line collapses to a zero-width
    ///     domain that traps Charts — same rule as canRenderContinuous).
    /// Every emitted value is finite and clamped 0…1 by construction.
    static func cumulativeDailySpend(_ transactions: [Transaction],
                                     now: Date = Date(),
                                     calendar: Calendar = .current) -> [Double]? {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return nil }
        let today = calendar.component(.day, from: now)   // 1…31
        guard today >= 2 else { return nil }              // need ≥2 points for a line

        // Bucket this month's expenses (income never spends) by day-of-month, up to
        // and including today; a post-dated future expense is ignored.
        var perDay = [Int: Int]()
        for tx in transactions where !tx.isIncome {
            guard month.contains(tx.date), tx.date <= now else { continue }
            let key = calendar.component(.day, from: tx.date)
            let (sum, overflow) = (perDay[key] ?? 0).addingReportingOverflow(tx.amountCents)
            guard !overflow else { return nil }
            perDay[key] = sum
        }

        var running = 0
        var cumulative: [Int] = []
        for day in 1...today {
            let (sum, overflow) = running.addingReportingOverflow(perDay[day, default: 0])
            guard !overflow else { return nil }
            running = sum
            cumulative.append(running)
        }
        let total = running
        guard total > 0 else { return nil }               // nothing to normalize against

        let series = cumulative.map { value -> Double in
            let f = Double(value) / Double(total)
            return f.isFinite ? min(max(f, 0), 1) : 0
        }
        return series.count >= 2 ? series : nil
    }

    // MARK: - Change detection

    /// A cheap fingerprint of everything the snapshot renders from. The Dashboard
    /// keys its debounced widget rebuild on this instead of `transactions.count`
    /// (Item 3): a count-only trigger misses *edits* — changing a transaction's
    /// amount, category, type or date leaves the count invariant, so the widget
    /// kept showing pre-edit data (the "1 000 000 ₽ not reflected" report). Any
    /// field the widget depends on is folded in here so an edit invalidates it.
    static func contentSignature(transactions: [Transaction],
                                 currencyCode: String,
                                 monthlyBudgetCents: Int,
                                 languageCode: String = "system") -> Int {
        var hasher = Hasher()
        hasher.combine(currencyCode)
        hasher.combine(monthlyBudgetCents)
        // Language is part of the fingerprint (Item 5): changing the in-app language
        // must rebuild the baked snapshot even when no transaction changed.
        hasher.combine(languageCode)
        for tx in transactions {
            hasher.combine(tx.uuid)
            hasher.combine(tx.amountCents)
            hasher.combine(tx.typeRaw)
            hasher.combine(tx.date)
            hasher.combine(tx.category?.uuid)
            // Splits move money between the widget's top categories without
            // touching any parent field — fold them in or a split edit leaves
            // the widget stale (the same class of bug as the count-only trigger).
            for split in CategoryAttribution.orderedSplits(of: tx) {
                hasher.combine(split.uuid)
                hasher.combine(split.amountCents)
                hasher.combine(split.category?.uuid)
            }
        }
        return hasher.finalize()
    }

    // MARK: - Pure guarded math (testable without SwiftData)

    /// The frozen hero copy: label, compact amount, subline, danger flag.
    struct HeroCopy {
        let label: String
        let amount: String
        let subtitle: String
        let isAlert: Bool
    }

    /// Gain-framed hero precedence (Item 0). In priority order:
    ///   1. Budget set        → "Safe to spend {budget − spent}" of {budget}
    ///   2. Income known       → "Safe to spend {income − spent}" of {income}
    ///   3. Neither            → "Spent {amount}" (last resort, no subline)
    /// Over-budget / over-income flips the label to the danger state and marks
    /// `isAlert` so the widget can tint it (never hue-alone — icon+label too).
    /// `localize` resolves a key against the chosen language's `.lproj` (Item 5) so
    /// the hero copy is baked in the app language, not the widget's system locale.
    static func heroComponents(spentCents: Int,
                               budgetCents: Int,
                               incomeCents: Int,
                               localize: (String) -> String,
                               compact: (Int) -> String) -> HeroCopy {
        if budgetCents > 0 {
            let remaining = budgetCents - spentCents
            let alert = remaining < 0
            return HeroCopy(
                label: localize(alert ? "widget.over_budget" : "widget.safe_to_spend"),
                amount: compact(abs(remaining)),
                subtitle: String(format: localize("widget.of_budget.format"), compact(budgetCents)),
                isAlert: alert
            )
        }
        if incomeCents > 0 {
            let remaining = incomeCents - spentCents
            let alert = remaining < 0
            return HeroCopy(
                label: localize(alert ? "widget.overspent" : "widget.safe_to_spend"),
                amount: compact(abs(remaining)),
                subtitle: String(format: localize("widget.of_earned.format"), compact(incomeCents)),
                isAlert: alert
            )
        }
        return HeroCopy(
            label: localize("widget.hero.spent"),
            amount: compact(spentCents),
            subtitle: "",
            isAlert: false
        )
    }

    /// Ring fill + whether it's a neutral (track-only) state.
    /// - budget set → spent / budget (the safe-to-spend progress).
    /// - no budget but income → spent / income (burn-through of what came in).
    /// - neither → neutral: nothing meaningful to fill against, so track only.
    /// Always finite and clamped 0…1 (guards divide-by-zero the ChartGuards way).
    static func ringComponents(spentCents: Int, budgetCents: Int, incomeCents: Int) -> (fraction: Double, isNeutral: Bool) {
        if budgetCents > 0 {
            return (clamp01(Double(spentCents) / Double(budgetCents)), false)
        }
        if incomeCents > 0 {
            return (clamp01(Double(spentCents) / Double(incomeCents)), false)
        }
        return (0, true)
    }

    /// A category's share of the period's spend, clamped and divide-by-zero safe.
    static func categoryFraction(cents: Int, totalSpentCents: Int) -> Double {
        guard totalSpentCents > 0 else { return 0 }
        return clamp01(Double(cents) / Double(totalSpentCents))
    }

    private static func clamp01(_ x: Double) -> Double {
        guard x.isFinite else { return 0 }
        return min(max(x, 0), 1)
    }

    // MARK: - Language resolution (Item 5)

    /// The `Locale` used for dates + number/currency formatting for an app language
    /// code. Mirrors LocaleAutoDetect.applyAppleLanguagesOverride's region choices
    /// (es→es-MX, pt→pt-BR); "system" hands back to the current process locale.
    static func appLocale(for code: String) -> Locale {
        switch code {
        case "system", "": return .current
        case "es":         return Locale(identifier: "es-MX")
        case "pt":         return Locale(identifier: "pt-BR")
        default:           return Locale(identifier: code)   // en, ru, uk
        }
    }

    /// The `.lproj` bundle that string lookups (chrome + category names) should
    /// resolve against for `locale`. Falls back to `.main` when the resource
    /// bundle can't be found (e.g. a system locale we don't ship).
    private static func chromeBundle(for locale: Locale) -> Bundle {
        let lang = locale.language.languageCode?.identifier ?? "en"
        let name = LocalizedBundle.lprojName(for: lang) ?? lang
        if let path = Bundle.main.path(forResource: name, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
