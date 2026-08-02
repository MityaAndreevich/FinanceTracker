//
//  UsageSummaryBuilder.swift
//  FinanceTracker
//
//  Builds the optional block of text that the feedback composer offers to put
//  in the mail body, so the 1.0.3 split-transaction pre-test (does anyone
//  actually split a purchase? — the falsifiable gate on receipt OCR) has any
//  readable answer at all in an app with no analytics.
//
//  THE RULES, which are load-bearing and not stylistic:
//
//  1. BUCKETS, NEVER COUNTS. "51–200", not "137". An exact transaction count
//     is a fingerprint; it is also the difference between a summary that reads
//     as a summary and one that reads as surveillance to the person staring at
//     it in their mail composer.
//  2. NO LEDGER CONTENT. No amounts, no merchants, no category names, no
//     dates, no currency, no account names. Everything below is a bucket
//     index or a yes/no. Adding a field that carries content breaks the
//     promise this whole surface is built on.
//  3. IT IS TEXT, NOT A PAYLOAD. `render` produces prose the user reads. The
//     app never sends it — `MFMailComposeViewController` hands it to Mail and
//     the user presses Send, or doesn't.
//
//  Labels are localized (the user has to understand what they are sending —
//  that is the entire premise) but the VALUES are locale-neutral numerals and
//  the LINE ORDER is fixed, so a reply in Ukrainian is still mechanically
//  readable: line 3 is always the transaction bucket. That fixed order is
//  documented in `outputs/DECISION_RECEIPT_INPUT_PRETEST.md`; do not reorder
//  the cases below without updating it.
//

import Foundation
import SwiftData

struct UsageSummary {

    // MARK: - Buckets

    /// Transactions in the ledger, demo rows excluded.
    enum TransactionBucket: String {
        case none = "0–10"          // 0–10 lives here too; the label is the value
        case small = "11–50"
        case medium = "51–200"
        case large = "200+"

        init(count: Int) {
            switch count {
            case ..<11: self = .none
            case ..<51: self = .small
            case ..<201: self = .medium
            default: self = .large
            }
        }
    }

    /// Transactions carrying at least one split — NOT the number of split rows.
    /// "I split six purchases" is the question the pre-test asks; "I made six
    /// child records" is not.
    enum SplitBucket: String {
        case zero = "0"
        case few = "1–5"
        case many = "6+"

        init(count: Int) {
            switch count {
            case 0: self = .zero
            case ..<6: self = .few
            default: self = .many
            }
        }
    }

    /// Whole months since first launch.
    enum TenureBucket: String {
        case underOne = "<1"
        case oneToThree = "1–3"
        case threeToSix = "3–6"
        case sixToTwelve = "6–12"
        case overTwelve = "12+"

        init(months: Int) {
            switch months {
            case ..<1: self = .underOne
            case ..<3: self = .oneToThree
            case ..<6: self = .threeToSix
            case ..<12: self = .sixToTwelve
            default: self = .overTwelve
            }
        }
    }

    // MARK: - Fields

    var transactions: TransactionBucket
    var splitTransactions: SplitBucket
    /// True if a split was ever created, even if none survive today.
    var splitsEverUsed: Bool
    var tenure: TenureBucket

    var usedRecurring: Bool
    var usedCategoryLimits: Bool
    var usedVoiceEntry: Bool
    var usedCSVImport: Bool
    var usedExport: Bool

    // MARK: - Rendering

    /// The block appended to the mail body. `bundle` is the in-app language
    /// bundle (`LocalizedBundle.shared.bundle`) — `Bundle.main` would render
    /// this in the device language, not the one the user actually reads the
    /// app in.
    func render(bundle: Bundle, now: Date = Date()) -> String {
        func t(_ key: String) -> String {
            bundle.localizedString(forKey: key, value: "", table: nil)
        }
        let yes = t("feedback.usage.yes")
        let no = t("feedback.usage.no")
        func flag(_ value: Bool) -> String { value ? yes : no }

        var lines: [String] = []
        lines.append(t("feedback.usage.heading"))
        // Line order is contractual — see the file header.
        lines.append("\(t("feedback.usage.tenure")): \(tenure.rawValue)")
        lines.append("\(t("feedback.usage.transactions")): \(transactions.rawValue)")
        lines.append("\(t("feedback.usage.splits")): \(flag(splitsEverUsed)) · \(splitTransactions.rawValue)")
        lines.append("\(t("feedback.usage.recurring")): \(flag(usedRecurring))")
        lines.append("\(t("feedback.usage.category_limits")): \(flag(usedCategoryLimits))")
        lines.append("\(t("feedback.usage.voice")): \(flag(usedVoiceEntry))")
        lines.append("\(t("feedback.usage.import")): \(flag(usedCSVImport))")
        lines.append("\(t("feedback.usage.export")): \(flag(usedExport))")

        let rule = String(repeating: "—", count: 12)
        return "\n\(rule)\n" + lines.joined(separator: "\n") + "\n\(rule)\n"
    }
}

enum UsageSummaryBuilder {

    /// Reads the ledger and the six "ever used" flags. Called once, on the
    /// main actor, when the feedback sheet opens — never on a timer, never in
    /// the background, never at save time.
    @MainActor
    static func build(
        modelContext: ModelContext,
        firstLaunchInterval: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageSummary {
        UsageSummary(
            transactions: .init(count: transactionCount(in: modelContext)),
            splitTransactions: .init(count: splitTransactionCount(in: modelContext)),
            splitsEverUsed: FeatureUsageSignals.wasUsed(.splits)
                || splitTransactionCount(in: modelContext) > 0,
            tenure: .init(months: monthsSinceFirstLaunch(
                firstLaunchInterval: firstLaunchInterval, now: now, calendar: calendar
            )),
            usedRecurring: FeatureUsageSignals.wasUsed(.recurring)
                || hasRecurringTransaction(in: modelContext),
            usedCategoryLimits: FeatureUsageSignals.wasUsed(.categoryLimits)
                || hasCategoryLimit(in: modelContext),
            usedVoiceEntry: FeatureUsageSignals.wasUsed(.voiceEntry),
            usedCSVImport: FeatureUsageSignals.wasUsed(.csvImport),
            usedExport: FeatureUsageSignals.wasUsed(.export)
        )
    }

    /// `firstLaunchInterval == 0` means the key was never written (a build
    /// that predates it, or a wiped defaults domain). Report the newest
    /// bucket rather than "125 years", which would be a lie in the loud
    /// direction.
    static func monthsSinceFirstLaunch(
        firstLaunchInterval: Double,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard firstLaunchInterval > 0 else { return 0 }
        let first = Date(timeIntervalSinceReferenceDate: firstLaunchInterval)
        guard first <= now else { return 0 }
        return calendar.dateComponents([.month], from: first, to: now).month ?? 0
    }

    // MARK: - Ledger reads (counts only — nothing is read out of a row)

    @MainActor
    private static func transactionCount(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isDemo == false }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Counts PARENTS, not split rows, and skips orphans and demo parents.
    /// The splits table is empty for anyone who never used the feature, so
    /// fetching it whole is cheap in exactly the case that matters.
    @MainActor
    private static func splitTransactionCount(in context: ModelContext) -> Int {
        let splits = (try? context.fetch(FetchDescriptor<TransactionSplit>())) ?? []
        var parents = Set<UUID>()
        for split in splits {
            guard let parent = split.parent, parent.isDemo == false else { continue }
            parents.insert(parent.uuid)
        }
        return parents.count
    }

    @MainActor
    private static func hasRecurringTransaction(in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isDemo == false && $0.recurrenceRaw != nil }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    @MainActor
    private static func hasCategoryLimit(in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.limitCents != nil }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
}
