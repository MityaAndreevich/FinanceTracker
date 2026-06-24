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
    @StateObject private var pm = PurchaseManager.shared

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

    var body: some View {
        List {
            exportSection
            importSection
        }
        .navigationTitle("data.title")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) { PaywallView() }

        .task {
            await pm.refreshStatus()
        }

        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
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

            Button {
                exportCSV(scope: .month)
            } label: {
                Label("data.export.csv.month", systemImage: "square.and.arrow.up")
            }

            Button {
                gatePremiumOr { exportCSV(scope: .all) }
            } label: {
                Label("data.export.csv.all",
                      systemImage: pm.isPremium ? "square.and.arrow.up" : "lock")
            }

            Button {
                exportPDF(scope: .month)
            } label: {
                Label("data.export.pdf.month", systemImage: "doc.richtext")
            }

            Button {
                gatePremiumOr { exportPDF(scope: .all) }
            } label: {
                Label("data.export.pdf.all",
                      systemImage: pm.isPremium ? "doc.richtext" : "lock")
            }

            Button {
                exportTSV(scope: .month)
            } label: {
                Label("data.export.excel.month", systemImage: "tablecells")
            }

            Button {
                gatePremiumOr { exportTSV(scope: .all) }
            } label: {
                Label("data.export.excel.all",
                      systemImage: pm.isPremium ? "tablecells" : "lock")
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
                gatePremiumOr { showImporter = true }
            } label: {
                Label("data.import.csv",
                      systemImage: pm.isPremium ? "tray.and.arrow.down" : "lock")
            }
            .disabled(isImporting)

            if !pm.isPremium {
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

    private func gatePremiumOr(_ action: () -> Void) {
        if pm.isPremium {
            action()
        } else {
            showPaywall = true
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

            startAsyncImport(data: data)

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

    private func formatImportSummary(_ importResult: CSVImportResult) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("data.import.result.imported.format", comment: ""), importResult.imported))
        lines.append(String(format: NSLocalizedString("data.import.result.skipped.format", comment: ""), importResult.skipped))
        lines.append(String(format: NSLocalizedString("data.import.result.created_categories.format", comment: ""), importResult.createdCategories))
        lines.append(String(format: NSLocalizedString("data.import.result.created_sources.format", comment: ""), importResult.createdSources))

        if let first = importResult.firstError {
            lines.append(String(format: NSLocalizedString("data.import.result.first_error.format", comment: ""), first))
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
