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

    var body: some View {
        List {
            Section("Export") {
                Button {
                    exportCSV(scope: .month)
                } label: {
                    Label("Export CSV (This Month)", systemImage: "square.and.arrow.up")
                }

                Button {
                    gatePremiumOr { exportCSV(scope: .all) }
                } label: {
                    Label("Export CSV (All)", systemImage: pm.isPremium ? "square.and.arrow.up" : "lock")
                }

                Button {
                    exportPDF(scope: .month)
                } label: {
                    Label("Export PDF (This Month)", systemImage: "doc.richtext")
                }

                Button {
                    gatePremiumOr { exportPDF(scope: .all) }
                } label: {
                    Label("Export PDF (All)", systemImage: pm.isPremium ? "doc.richtext" : "lock")
                }

                Button {
                    exportTSV(scope: .month)
                } label: {
                    Label("Export Excel/Numbers (This Month)", systemImage: "tablecells")
                }

                Button {
                    gatePremiumOr { exportTSV(scope: .all) }
                } label: {
                    Label("Export Excel/Numbers (All)", systemImage: pm.isPremium ? "tablecells" : "lock")
                }

                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Share last export (\(exportFilename))", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section("Import") {
                Button {
                    gatePremiumOr { showImporter = true }
                } label: {
                    Label("Import CSV", systemImage: pm.isPremium ? "tray.and.arrow.down" : "lock")
                }

                if !pm.isPremium {
                    Text("Premium unlocks Import CSV and Export All.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Data")
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import result", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .alert("Export error", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
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

            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let importResult = try CSVImportService.importCSV(modelContext: modelContext, data: data)

            var lines: [String] = []
            lines.append("Imported: \(importResult.imported)")
            lines.append("Skipped: \(importResult.skipped)")
            lines.append("Created categories: \(importResult.createdCategories)")
            lines.append("Created sources: \(importResult.createdSources)")
            if let first = importResult.firstError {
                lines.append("First error: \(first)")
            }

            importResultMessage = lines.joined(separator: "\n")
            showImportResult = true
        } catch {
            importResultMessage = "Import failed: \(error.localizedDescription)"
            showImportResult = true
        }
    }

    // MARK: - Export

    private func exportCSV(scope: CSVExportScope) {
        do {
            let result = try CSVExportService.makeCSV(modelContext: modelContext, scope: scope)
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
        } catch {
            exportErrorMessage = "Export failed: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func exportPDF(scope: CSVExportScope) {
        do {
            let result = try PDFExportService.makeMonthlyReportPDF(modelContext: modelContext, scope: scope)
            let url = try TemporaryFileService.writeTemporaryFile(data: result.data, filename: result.filename)
            exportURL = url
            exportFilename = result.filename
        } catch {
            exportErrorMessage = "Export failed: \(error.localizedDescription)"
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
            exportErrorMessage = "Export failed: \(error.localizedDescription)"
            showExportError = true
        }
    }
}

#Preview {
    NavigationStack { DataSettingsView() }
        .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
