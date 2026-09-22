//
//  ReportsView.swift
//  FinanceTracker
//
//  The on-demand report: pick a period, see where the money went, share it.
//  Design: outputs/DESIGN_REPORTS_1_0_6.md §4.
//
//  Every figure on this screen comes from ONE `ReportSnapshot`, built off the
//  main actor by `LedgerAggregator.reportSnapshot`. The screen never sums
//  anything itself. When the snapshot is nil the money area is replaced by
//  `TotalsUnavailableCard` — never a number.
//
//  No Swift Charts here, deliberately: the two chart views on Analytics carry
//  the open EXC_BREAKPOINT (#22, ARCHITECTURE.md "Deferred BEHIND #22"), and a
//  report needs bars, not a scrubbable axis. Plain capsules.
//

import SwiftUI
import SwiftData

/// `ReportsView` inside its own stack — for the sheet presentations (Analytics
/// toolbar, notification tap). Settings pushes `ReportsView` directly.
struct ReportsScreen: View {
    let initialPeriod: ReportPeriod
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ReportsView(initialPeriod: initialPeriod)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.done") { dismiss() }
                    }
                }
        }
        .languageReactive()
    }
}

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @AppStorage("defaultCurrencyCode") private var currencyCode: String = "USD"
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents: Int = 0
    @ObservedObject private var localizedBundle = LocalizedBundle.shared
    @ObservedObject private var access = AccessManager.shared

    @State private var period: ReportPeriod
    @State private var kind: ReportPeriod.Kind
    @State private var customStart: Date
    @State private var customEnd: Date
    @State private var customTooLong = false

    @State private var snapshot: ReportSnapshot?
    /// True once a build has finished and returned nil.
    @State private var unavailable = false
    @State private var loading = false
    @State private var aggregator: LedgerAggregator?
    @State private var buildTask: Task<Void, Never>?

    @State private var includeTransactionsInPDF: Bool
    @State private var exportURL: URL?
    @State private var exportFilename: String = ""
    @State private var exportError: String?
    @State private var showPaywall = false

    /// Fold size on this screen — a presentation parameter, see the design §4.2.
    static let maxNamedCategories = 8

    init(initialPeriod: ReportPeriod) {
        _period = State(initialValue: initialPeriod)
        _kind = State(initialValue: initialPeriod.kind)
        let cal = Calendar.current
        let range = initialPeriod.range(calendar: cal)
        _customStart = State(initialValue: range.lowerBound)
        _customEnd = State(initialValue: min(cal.date(byAdding: .day, value: -1, to: range.upperBound) ?? Date(), Date()))
        // Founder's decision 2026-09-21: transactions in the PDF are on for
        // week/month, off for year/custom (a 3 000-row year is ~90 pages).
        _includeTransactionsInPDF = State(initialValue: initialPeriod.kind == .week || initialPeriod.kind == .month)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                periodBar
                if kind == .custom { customRangePickers }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(String(format: NSLocalizedString("reports.share.last.format", comment: ""), exportFilename),
                              systemImage: "square.and.arrow.up")
                    }
                    .bcCard(padding: 14)
                    .accessibilityIdentifier("reports_share_link")
                }
                if unavailable {
                    TotalsUnavailableCard()
                } else if let snapshot {
                    ReportContentView(snapshot: snapshot, currencyCode: currencyCode)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.bcPage.ignoresSafeArea())
        .navigationTitle("reports.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                shareMenu
                NavigationLink {
                    ReportsSettingsView()
                } label: {
                    Image(systemName: "bell.badge")
                        .accessibilityLabel(Text("reports.settings.title"))
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(
            "data.alert.export_error.title",
            isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
        ) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .onAppear { rebuild() }
        .onDisappear { buildTask?.cancel() }
        .onChange(of: period) { _, _ in
            exportURL = nil
            rebuild()
        }
        .onChange(of: kind) { _, newKind in switchKind(newKind) }
        .onChange(of: customStart) { _, _ in applyCustom() }
        .onChange(of: customEnd) { _, _ in applyCustom() }
        .onChange(of: monthlyBudgetCents) { _, _ in rebuild() }
        .onChange(of: localizedBundle.languageCode) { _, _ in rebuild() }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in rebuild() }
        .languageReactive()
    }

    // MARK: - Period bar

    private var periodBar: some View {
        VStack(spacing: 10) {
            Picker("reports.kind", selection: $kind) {
                Text("reports.kind.week").tag(ReportPeriod.Kind.week)
                Text("reports.kind.month").tag(ReportPeriod.Kind.month)
                Text("reports.kind.year").tag(ReportPeriod.Kind.year)
                Text("reports.kind.custom").tag(ReportPeriod.Kind.custom)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("reports_kind_picker")

            HStack {
                Button {
                    period = period.shifted(by: -1, calendar: .current)
                } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 36, height: 36)
                }
                .accessibilityLabel(Text("scope.previous_month"))
                .accessibilityIdentifier("reports_previous")

                Spacer()
                Text(period.label(locale: locale, calendar: .current))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("reports_period_label")
                Spacer()

                Button {
                    period = period.shifted(by: 1, calendar: .current)
                } label: {
                    Image(systemName: "chevron.right").font(.body.weight(.semibold)).frame(width: 36, height: 36)
                }
                .disabled(!period.canShiftForward(now: Date(), calendar: .current))
                .accessibilityLabel(Text("scope.next_month"))
                .accessibilityIdentifier("reports_next")
            }
            .foregroundStyle(Color.bcTextPrimary)
        }
    }

    private var customRangePickers: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker("reports.custom.start", selection: $customStart, in: ...Date(), displayedComponents: .date)
            DatePicker("reports.custom.end", selection: $customEnd, in: ...Date(), displayedComponents: .date)
            if customTooLong {
                Text("reports.custom.too_long")
                    .font(.footnote)
                    .foregroundStyle(Color.bcWarningInk)
            }
        }
        .bcCard(padding: 14)
    }

    private func switchKind(_ newKind: ReportPeriod.Kind) {
        guard newKind != period.kind else { return }
        let cal = Calendar.current
        // Keep the user's place: anchor the new kind on the current period's
        // start, clamped so the new period is never in the future.
        let anchor = min(period.range(calendar: cal).lowerBound, Date())
        switch newKind {
        case .week: period = .week(containing: anchor)
        case .month: period = .month(containing: anchor)
        case .year: period = .year(containing: anchor)
        case .custom:
            customStart = period.range(calendar: cal).lowerBound
            customEnd = min(cal.date(byAdding: .day, value: -1, to: period.range(calendar: cal).upperBound) ?? Date(), Date())
            applyCustom()
        }
        includeTransactionsInPDF = (newKind == .week || newKind == .month)
    }

    private func applyCustom() {
        guard kind == .custom else { return }
        let cal = Calendar.current
        if customEnd < customStart { customEnd = customStart }
        let candidate = ReportPeriod.custom(start: customStart, end: customEnd)
        let maxDays = ReportPeriod.maxCustomYears * 366
        customTooLong = candidate.dayCount(calendar: cal) > maxDays
        guard !customTooLong else { return }
        period = candidate
    }

    // MARK: - Building

    private func rebuild() {
        buildTask?.cancel()
        let period = self.period
        let budget = monthlyBudgetCents
        let bundle = localizedBundle.bundle
        loading = snapshot == nil
        buildTask = Task { @MainActor in
            // Pre-migration launches reach here while the store is still gated;
            // never let this be the first container touch.
            guard let container = SharedModelContainer.readyContainer() else { return }
            if aggregator == nil { aggregator = LedgerAggregator(modelContainer: container) }
            guard let aggregator else { return }
            let result = await aggregator.reportSnapshot(period: period, calendar: .current,
                                                         monthlyBudgetCents: budget, bundle: bundle)
            guard !Task.isCancelled, period == self.period else { return }
            loading = false
            if let result {
                unavailable = false
                snapshot = result
                FeatureUsageSignals.markUsed(.reportOpened)
            } else {
                unavailable = true
                snapshot = nil
            }
        }
    }

    // MARK: - Share

    private var shareMenu: some View {
        Menu {
            Button {
                gate(exportCapability(.pdf)) { exportPDF() }
            } label: {
                Label("reports.share.pdf", systemImage: access.isAllowed(exportCapability(.pdf)) ? "doc.richtext" : "lock")
            }
            Button {
                gate(exportCapability(.excel)) { exportTSV() }
            } label: {
                Label("reports.share.excel", systemImage: access.isAllowed(exportCapability(.excel)) ? "tablecells" : "lock")
            }
            Toggle("reports.share.include_transactions", isOn: $includeTransactionsInPDF)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .accessibilityLabel(Text("reports.share"))
        }
        .accessibilityIdentifier("reports_share_menu")
        .disabled(snapshot == nil && !unavailable)
    }

    private enum ExportKind { case pdf, excel }

    /// A month report's exports are free (`exportPDFMonth` / `exportExcelMonth`);
    /// any other period is "beyond this month" — the existing all-time gates.
    private func exportCapability(_ export: ExportKind) -> AppCapability {
        switch (export, period.kind) {
        case (.pdf, .month): return .exportPDFMonth
        case (.pdf, _): return .exportPDFAll
        case (.excel, .month): return .exportExcelMonth
        case (.excel, _): return .exportExcelAll
        }
    }

    /// Same shape as `DataSettingsView.gate`: allowed → run; else refresh the
    /// entitlement once from StoreKit and re-check; else paywall.
    private func gate(_ capability: AppCapability, _ action: @escaping () -> Void) {
        if access.isAllowed(capability) { action(); return }
        Task { @MainActor in
            await access.refreshFromStoreKit()
            if access.isAllowed(capability) { action() } else { showPaywall = true }
        }
    }

    private func exportPDF() {
        do {
            let rows = try periodTransactions()
            let result = ReportPDFRenderer.makeReportPDF(
                snapshot: snapshot, period: period, transactions: rows,
                currencyCode: currencyCode, includeTransactions: includeTransactionsInPDF,
                bundle: localizedBundle.bundle
            )
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
            FeatureUsageSignals.markUsed(.export)
        } catch {
            exportError = String(format: NSLocalizedString("data.export.failed.format", comment: ""), error.localizedDescription)
        }
    }

    private func exportTSV() {
        do {
            let result = try TSVExportService.makeTSV(modelContext: modelContext, period: period)
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
            FeatureUsageSignals.markUsed(.export)
        } catch {
            exportError = String(format: NSLocalizedString("data.export.failed.format", comment: ""), error.localizedDescription)
        }
    }

    private func periodTransactions() throws -> [Transaction] {
        let range = period.range(calendar: .current)
        let lo = range.lowerBound, hi = range.upperBound
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= lo && $0.date < hi },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
