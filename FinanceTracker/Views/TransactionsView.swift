//
//  TransactionView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    /// Rows the importer flagged as possible duplicates. Queried separately from
    /// `transactions` on purpose: a flagged row may sit in ANY period, so scoping
    /// the banner to the selected month would hide the very rows it exists to
    /// surface.
    @Query(filter: #Predicate<Transaction> { $0.isPossibleDuplicate })
    private var possibleDuplicates: [Transaction]

    @State private var scope: PeriodScope = .currentMonth
    // One-shot hint teaching the ‹ › month pager, first Transactions visit (Brief 28 Part B).
    @AppStorage("hasSeenPeriodHint") private var hasSeenPeriodHint = false
    @State private var searchText: String = ""
    @State private var typeFilter: TransactionFilter = .all

    @State private var editTx: Transaction?
    @State private var presentQuickEntry = false
    @State private var presentDuplicateReview = false

    // Pending destructive deletion — set by the swipe / context-menu trash button,
    // performed only after the user confirms in the alert below (data-loss safety).
    @State private var pendingDeleteTx: Transaction?

    // MARK: - Derived

    private var filtered: [Transaction] {
        var base = scope.filter(transactions)

        switch typeFilter {
        case .all:     break
        case .income:  base = base.filter { $0.isIncome }
        case .expense: base = base.filter { !$0.isIncome }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }

        // Multi-token, diacritic/case-insensitive, amount-searchable match.
        // See TransactionSearch for the documented semantics.
        return base.filter { tx in
            TransactionSearch.matches(
                query: q,
                fields: [tx.merchant, tx.category.displayName(), tx.category.name, tx.source?.name, tx.note],
                amountCents: tx.amountCents
            )
        }
    }

    /// A search or type filter is actively narrowing the list (period scope
    /// excluded — that has its own "nothing in this period" message).
    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || typeFilter != .all
    }

    private var grouped: [Date: [Transaction]] {
        let cal = Calendar.current
        return Dictionary(grouping: filtered) { tx in
            cal.startOfDay(for: tx.date)
        }
    }

    private var sortedDays: [Date] {
        grouped.keys.sorted(by: >)
    }

    var body: some View {
        List {
            // Sits above the period-scoped content because the flagged rows it
            // points at may live in any month — including one the user isn't
            // looking at.
            if !possibleDuplicates.isEmpty {
                duplicateBanner
            }

            if filtered.isEmpty {
                if transactions.isEmpty {
                    firstRunEmptyRow
                } else if isFiltering {
                    noResultsRow
                } else {
                    noneInPeriodRow
                }
            } else {
                ForEach(sortedDays, id: \.self) { day in
                    daySection(for: day)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bcPage.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            // PeriodSelector + filter chips live ABOVE the list, below the search
            // drawer. Keeping them out of the List avoids a hit-test conflict that
            // left the .searchable drawer visible but untappable on device.
            // `spacing: 0` sits the bar flush under the nav bar (no extra gap that
            // pushed content too far down).
            VStack(spacing: 8) {
                PeriodSelector(scope: $scope)
                    .padding(.horizontal, 12)

                if !hasSeenPeriodHint && scope.isMonth {
                    InlineHintBubble(text: "onboarding.hint.period") {
                        withAnimation { hasSeenPeriodHint = true }
                    }
                    .padding(.horizontal, 12)
                }

                filterChips
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("title.transactions")
        // Inline (matching DashboardView) keeps the title fixed in the nav bar.
        // The default large title collapsed under the always-on search drawer +
        // period bar, leaving it half-hidden behind the bar's blur on device.
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("transactions.search.prompt")
        )
        .refreshable {
            await PurchaseManager.shared.refreshStatus()
        }
        .navigationDestination(item: $editTx) { tx in
            EditTransactionView(transaction: tx)
        }
        .sheet(isPresented: $presentQuickEntry) {
            QuickEntryView()
        }
        .sheet(isPresented: $presentDuplicateReview) {
            DuplicateReviewView()
        }
        .alert(
            "common.delete",
            isPresented: Binding(
                get: { pendingDeleteTx != nil },
                set: { if !$0 { pendingDeleteTx = nil } }
            )
        ) {
            Button("common.cancel", role: .cancel) { pendingDeleteTx = nil }
            Button("common.delete", role: .destructive) {
                if let tx = pendingDeleteTx { delete(tx) }
                pendingDeleteTx = nil
            }
        }
        // Re-localize filter chips, day headers and empty state live on an in-app
        // language change (device QA round 1 #2), navigation preserved.
        .languageReactive()
        // Drop a stale search when leaving the tab (device QA round 2 #1). Without
        // this, a search like "Футболка 550" survives a tab switch and silently
        // hides the whole list on return, reading as data loss. Keep it while
        // pushing into edit (editTx != nil) so returning from an edit still shows
        // the same filtered results the user tapped from.
        .onDisappear {
            if editTx == nil { searchText = "" }
        }
    }

    /// "N possible duplicates — review". The count is rendered as a standalone
    /// numeral chip rather than interpolated into the sentence: ru and uk have
    /// three plural forms, the project ships no .stringsdict, and "2 возможных
    /// дубликата" vs "5 возможных дубликатов" is not something %d can fake. A
    /// numeral beside a non-inflected noun phrase is correct in all five locales.
    private var duplicateBanner: some View {
        Button {
            presentDuplicateReview = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bcWarningInk)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("duplicates.banner.title")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bcTextPrimary)

                        Text("\(possibleDuplicates.count)")
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.bcWarningInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.bcWarning.opacity(0.16)))
                    }

                    Text("duplicates.banner.subtitle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bcTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bcTextMuted)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.bcSurface1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("duplicates.banner.title")
            + Text(", \(possibleDuplicates.count), ")
            + Text("duplicates.banner.subtitle")
        )
        .accessibilityAddTraits(.isButton)
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(TransactionFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { typeFilter = filter }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filter.symbol)
                            .font(.caption.weight(.medium))
                        Text(filter.labelKey)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(typeFilter == filter ? Color.bcAccent : Color.bcSurface2)
                    )
                    .foregroundStyle(typeFilter == filter ? Color.black : Color.bcTextPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// True empty state — there are zero transactions at all. Only here do we
    /// invite "Add your first"; showing this while data exists reads as loss.
    private var firstRunEmptyRow: some View {
        emptyState(
            icon: "list.bullet.rectangle",
            title: "transactions.empty.title"
        ) {
            Button {
                presentQuickEntry = true
            } label: {
                Text("transactions.empty.cta")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.bcAccent))
            }
            .buttonStyle(.plain)
        }
    }

    /// Data exists but a search / type filter hides all of it. Never "Add your
    /// first" here — offer to clear the narrowing instead.
    private var noResultsRow: some View {
        emptyState(
            icon: "magnifyingglass",
            title: "transactions.noresults.title"
        ) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchText = ""
                    typeFilter = .all
                }
            } label: {
                Text("transactions.noresults.clear")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.bcAccent))
            }
            .buttonStyle(.plain)
        }
    }

    /// Data exists but none falls in the selected period. Neutral — the ‹ ›
    /// pager is the affordance, so no button here.
    private var noneInPeriodRow: some View {
        emptyState(
            icon: "calendar",
            title: "transactions.noneinperiod.title"
        ) { EmptyView() }
    }

    private func emptyState<Action: View>(
        icon: String,
        title: LocalizedStringKey,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.bcTextMuted)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)
                .multilineTextAlignment(.center)

            action()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func daySection(for day: Date) -> some View {
        Section {
            let dayItems = grouped[day] ?? []

            // Identity on the stable app-level uuid, never the default
            // persistentModelID: a freshly inserted row's persistentModelID is
            // temporary until save and flips to permanent on save, which makes a
            // ForEach keyed on it transiently double-render during rapid saves at
            // scale (Round 9 ghost duplication, gone after restart). uuid is fixed
            // at init.
            ForEach(dayItems, id: \.uuid) { tx in
                Button { editTx = tx } label: {
                    CategoryTileRow(tx: tx)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.bcSurface1)
                .listRowSeparatorTint(Color.bcDivider)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {

                    Button(role: .destructive) { pendingDeleteTx = tx } label: {
                        Label("common.delete", systemImage: "trash")
                    }

                    Button { editTx = tx } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button { editTx = tx } label: {
                        Label("common.edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) { pendingDeleteTx = tx } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            dayHeader(for: day)
        }
    }

    /// Day header: relative/formatted date + a calm neutral subtotal of that day's
    /// spending (running clarity). Neutral, not alarm-colored — a day's spend is
    /// normal, not a status.
    private func dayHeader(for day: Date) -> some View {
        let items = grouped[day] ?? []
        let spend = items.filter { !$0.isIncome }.reduce(0) { $0 + $1.amountCents }
        return HStack {
            sectionHeader(for: day)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bcTextSecondary)
                .textCase(nil)
            Spacer()
            if spend > 0 {
                Text(Money.format(cents: spend, currencyCode: defaultCurrencyCode))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.bcTextMuted)
                    .privacySensitive(true)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(for day: Date) -> Text {
        let cal = Calendar.current

        if cal.isDateInToday(day) { return Text("common.today") }
        if cal.isDateInYesterday(day) { return Text("common.yesterday") }

        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .medium
        df.timeStyle = .none

        return Text(df.string(from: day))
    }

    private func delete(_ tx: Transaction) {
        modelContext.delete(tx)
        do { try modelContext.save() }
        catch {
            #if DEBUG
            print("Failed to delete transaction: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Type filter

enum TransactionFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case income = "income"
    case expense = "expense"

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .all:     "transactions.filter.all"
        case .income:  "transactions.filter.income"
        case .expense: "transactions.filter.expense"
        }
    }

    var symbol: String {
        switch self {
        case .all:     "list.bullet"
        case .income:  "arrow.up.right"
        case .expense: "arrow.down.right"
        }
    }
}

#Preview {
    NavigationStack { TransactionsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
