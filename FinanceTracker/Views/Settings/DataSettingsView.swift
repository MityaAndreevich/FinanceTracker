//
//  DataSettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var access = AccessManager.shared

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"

    // Export
    @State private var exportURL: URL?
    @State private var exportFilename: String = ""
    @State private var showExportError = false
    @State private var exportErrorMessage = ""

    // Import
    @State private var showImporter = false
    @State private var showImportResult = false
    @State private var importResultMessage = ""
    @State private var showPaywall = false

    // Import progress (indeterminate — see note in startAsyncImport)
    @State private var isImporting = false

    // Tier-2 flexible import: mapping sheet for foreign (non-our-export) files.
    @State private var showMappingSheet = false
    @State private var pendingImportData: Data?
    @State private var mappingPreview: CSVImportService.CSVPreview?
    @State private var detectedPreset: SourcePreset = .custom

    var body: some View {
        List {
            exportSection
            importSection
        }
        .navigationTitle("data.title")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) { PaywallView() }

        .task {
            await access.refreshFromStoreKit()
        }

        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }

        .sheet(isPresented: $showMappingSheet) {
            if let preview = mappingPreview {
                ImportMappingView(
                    preview: preview,
                    initialPreset: detectedPreset,
                    onCancel: {
                        showMappingSheet = false
                        pendingImportData = nil
                    },
                    onImport: { mapping in
                        showMappingSheet = false
                        if let data = pendingImportData {
                            startMappedImport(data: data, mapping: mapping)
                        }
                        pendingImportData = nil
                    }
                )
            }
        }

        .alert("data.alert.import_result.title", isPresented: $showImportResult) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }

        .alert("data.alert.export_error.title", isPresented: $showExportError) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }

        // Modal progress overlay during import. Blocks interaction so the user
        // can't fire a second import while one is running.
        .overlay {
            if isImporting {
                importProgressOverlay
            }
        }
    }

    // MARK: - Import types

    private var allowedImportTypes: [UTType] {
        // CSV is sometimes delivered as plainText (Google Sheets etc).
        [.commaSeparatedText, .plainText]
    }

    // MARK: - Sections

    private var exportSection: some View {
        Section("data.section.export") {

            // CSV is the raw-data escape hatch and is FREE at every scope,
            // including all-time. We never hold a user's own records hostage to
            // make them subscribe — that is the whole point of the brand.
            Button {
                exportCSV(scope: .month)
            } label: {
                Label("data.export.csv.month", systemImage: "square.and.arrow.up")
            }

            Button {
                exportCSV(scope: .all)
            } label: {
                Label("data.export.csv.all", systemImage: "square.and.arrow.up")
            }

            Button {
                exportPDF(scope: .month)
            } label: {
                Label("data.export.pdf.month", systemImage: "doc.richtext")
            }

            // All-time PDF / Excel are presentation conveniences layered on top
            // of data the user can already take with them as CSV for free.
            Button {
                gate(.exportPDFAll) { exportPDF(scope: .all) }
            } label: {
                Label("data.export.pdf.all",
                      systemImage: access.isAllowed(.exportPDFAll) ? "doc.richtext" : "lock")
            }

            Button {
                exportTSV(scope: .month)
            } label: {
                Label("data.export.excel.month", systemImage: "tablecells")
            }

            Button {
                gate(.exportExcelAll) { exportTSV(scope: .all) }
            } label: {
                Label("data.export.excel.all",
                      systemImage: access.isAllowed(.exportExcelAll) ? "tablecells" : "lock")
            }

            if let url = exportURL {
                ShareLink(item: url) {
                    let title = String(
                        format: NSLocalizedString("data.export.share_last.format", comment: ""),
                        exportFilename
                    )
                    Label(title, systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var importSection: some View {
        Section("data.section.import") {

            Button {
                gate(.csvImport) { showImporter = true }
            } label: {
                Label("data.import.csv",
                      systemImage: access.isAllowed(.csvImport) ? "tray.and.arrow.down" : "lock")
            }
            .disabled(isImporting)

            if !access.isAllowed(.csvImport) {
                Text("data.premium_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                Text("data.import.in_progress")
                    .font(.headline)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isImporting)
    }

    // MARK: - Premium gate

    /// Authoritative gate. Never trusts the cached flag alone — re-reads
    /// `currentEntitlements` (fast, local; no network sync) at tap time so an
    /// already-entitled user (paid, Apple intro trial, lifetime — or our reverse
    /// trial) proceeds directly and NEVER sees the paywall. Only a genuinely
    /// free user falls through to it.
    private func gate(_ capability: AppCapability, _ action: @escaping () -> Void) {
        if access.isAllowed(capability) {
            action()
            return
        }
        Task {
            await access.refreshFromStoreKit()
            if access.isAllowed(capability) {
                action()
            } else {
                showPaywall = true
            }
        }
    }

    // MARK: - Import

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            // Read on the calling thread so we honor the security-scoped resource lifetime.
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)

            // Our own export (carries UUIDs) keeps the legacy idempotent round-trip
            // path. Any other CSV goes through the flexible mapping sheet so the
            // user confirms columns before a single row is written.
            if CSVImportService.isOwnExport(data: data) {
                startAsyncImport(data: data)
            } else if let preview = CSVImportService.parsePreview(data: data), !preview.header.isEmpty {
                pendingImportData = data
                mappingPreview = preview
                detectedPreset = SourcePreset.detect(header: preview.header)
                showMappingSheet = true
            } else {
                // Unreadable / empty file: fall back to the legacy importer, which
                // reports a proper parse error in the result alert.
                startAsyncImport(data: data)
            }

        } catch {
            importResultMessage = String(
                format: NSLocalizedString("data.import.failed.format", comment: ""),
                error.localizedDescription
            )
            showImportResult = true
        }
    }

    private func startAsyncImport(data: Data) {
        isImporting = true

        // Run the import on a dedicated background ModelActor (CSVImportActor) so
        // the parse + insert loop never touches the main thread — this is what
        // keeps 10k-row imports from tripping the 0x8badf00d watchdog.
        //
        // Task.detached (NOT a plain Task) is required: a @ModelActor adopts the
        // executor of whatever thread constructs it, so it must be built off the
        // MainActor. We capture only the Sendable ModelContainer; all SwiftData
        // work happens inside the actor, and we hop back to MainActor only to
        // update @State for the result UI.
        let container = modelContext.container
        Task.detached(priority: .medium) {
            do {
                let importer = CSVImportActor(modelContainer: container)
                let result = try await importer.importData(data: data) { _, _ in
                    // Progress is intentionally a no-op: the overlay is an
                    // indeterminate spinner. Wire a determinate bar here later.
                }

                await MainActor.run {
                    self.isImporting = false
                    self.importResultMessage = self.formatImportSummary(result)
                    self.showImportResult = true
                }
            } catch {
                let message = String(
                    format: NSLocalizedString("data.import.failed.format", comment: ""),
                    error.localizedDescription
                )
                await MainActor.run {
                    self.isImporting = false
                    self.importResultMessage = message
                    self.showImportResult = true
                }
            }
        }
    }

    /// Tier-2 mapped import. Same background-actor discipline as `startAsyncImport`
    /// (detached so the @ModelActor is built off the MainActor), but drives the
    /// column mapping through `importMappedData`.
    private func startMappedImport(data: Data, mapping: ColumnMapping) {
        isImporting = true
        let container = modelContext.container
        Task.detached(priority: .medium) {
            do {
                let importer = CSVImportActor(modelContainer: container)
                let result = try await importer.importMappedData(data: data, mapping: mapping) { _, _ in }
                await MainActor.run {
                    self.isImporting = false
                    self.importResultMessage = self.formatImportSummary(result)
                    self.showImportResult = true
                }
            } catch {
                let message = String(
                    format: NSLocalizedString("data.import.failed.format", comment: ""),
                    error.localizedDescription
                )
                await MainActor.run {
                    self.isImporting = false
                    self.importResultMessage = message
                    self.showImportResult = true
                }
            }
        }
    }

    private func formatImportSummary(_ importResult: CSVImportResult) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("data.import.result.imported.format", comment: ""), importResult.imported))
        lines.append(String(format: NSLocalizedString("data.import.result.skipped.format", comment: ""), importResult.skipped))
        if importResult.duplicatesSkipped > 0 {
            lines.append(String(format: NSLocalizedString("data.import.result.duplicates_skipped.format", comment: ""), importResult.duplicatesSkipped))
        }
        if importResult.possibleDuplicates > 0 {
            lines.append(String(format: NSLocalizedString("data.import.result.possible_duplicates.format", comment: ""), importResult.possibleDuplicates))
        }
        if importResult.failedRows > 0 {
            lines.append(String(format: NSLocalizedString("data.import.result.failed_rows.format", comment: ""), importResult.failedRows))
        }
        if importResult.currencyAssumed > 0 {
            lines.append(String(format: NSLocalizedString("data.import.result.currency_assumed.format", comment: ""), importResult.currencyAssumed))
        }
        lines.append(String(format: NSLocalizedString("data.import.result.created_categories.format", comment: ""), importResult.createdCategories))
        lines.append(String(format: NSLocalizedString("data.import.result.created_sources.format", comment: ""), importResult.createdSources))

        if let first = importResult.firstError {
            lines.append(String(format: NSLocalizedString("data.import.result.first_error.format", comment: ""), first))
        }

        // Bonus safety: when separator-inconsistent failures dominate, point at the
        // decimal-separator control instead of leaving a wall of failed rows.
        if importResult.separatorFailedRows >= 3,
           importResult.separatorFailedRows >= importResult.imported {
            lines.append(NSLocalizedString("data.import.result.separator_hint", comment: ""))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Export

    private func exportCSV(scope: CSVExportScope) {
        do {
            let result = try CSVExportService.makeCSV(modelContext: modelContext, scope: scope)
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
        } catch {
            exportErrorMessage = String(
                format: NSLocalizedString("data.export.failed.format", comment: ""),
                error.localizedDescription
            )
            showExportError = true
        }
    }

    private func exportPDF(scope: CSVExportScope) {
        do {
            let result = try PDFExportService.makeMonthlyReportPDF(
                modelContext: modelContext,
                scope: scope,
                currencyCode: defaultCurrencyCode
            )
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
        } catch {
            exportErrorMessage = String(
                format: NSLocalizedString("data.export.failed.format", comment: ""),
                error.localizedDescription
            )
            showExportError = true
        }
    }

    private func exportTSV(scope: CSVExportScope) {
        do {
            let result = try TSVExportService.makeTSV(modelContext: modelContext, scope: scope)
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
        } catch {
            exportErrorMessage = String(
                format: NSLocalizedString("data.export.failed.format", comment: ""),
                error.localizedDescription
            )
            showExportError = true
        }
    }
}

#Preview {
    NavigationStack { DataSettingsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
