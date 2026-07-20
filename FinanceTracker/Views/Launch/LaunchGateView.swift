//
//  LaunchGateView.swift
//  FinanceTracker
//
//  The launch sequence around the V1→V2 store migration (design doc §9.3):
//
//    decide → [pre-migration screen] → guarded bootstrap → RootView
//                                    ↘ backup failed (halt — no migration
//                                      without its safety net)
//                                    ↘ degraded floor (data intact, view/export
//                                      only) after the ladder is exhausted
//
//  Rules enforced here:
//    • NOTHING in the pre-migration branches touches SharedModelContainer.shared —
//      the store must not open before the backup exists. The export button uses
//      the read-only V1 container, which cannot migrate or mutate.
//    • The model container attaches INSIDE the ready branch, never at scene level.
//    • A restore-from-backup is always announced with a full-screen,
//      must-acknowledge notice carrying the live post-restore transaction
//      count. No silent restores.
//    • The pre-migration screen is shown until resolved (a force-quit on it
//      legitimately re-shows it — the choice was never made). There is NO
//      separate "seen" flag: sticky presentation state whose only reset is the
//      thing it gates is exactly the editTx bug class.
//

import SwiftUI
import SwiftData

struct LaunchGateView: View {

    enum Phase {
        case deciding
        case preMigration
        case migrating
        case ready(ModelContainer, showRestoreNotice: Bool)
        case backupFailed(Error)
        case floor(Error)
    }

    @State private var phase: Phase = .deciding

    var body: some View {
        switch phase {
        case .deciding:
            // One synchronous decision — no store access, just a file check.
            Color.bcPage.ignoresSafeArea()
                .onAppear { decide() }

        case .preMigration:
            PreMigrationView(onContinue: { runBootstrap() })

        case .migrating:
            MigrationProgressView()

        case .ready(let container, let showRestoreNotice):
            RootView()
                .modelContainer(container)
                .fullScreenCover(isPresented: .constant(showRestoreNotice)) {
                    RestoreNoticeView(container: container) {
                        UserDefaults.appGroup.removeObject(
                            forKey: SharedModelContainer.restorePendingNoticeKey)
                        phase = .ready(container, showRestoreNotice: false)
                    }
                    .interactiveDismissDisabled()
                }

        case .backupFailed(let error):
            BackupFailedView(error: error) { decide() }

        case .floor(let error):
            MigrationFloorView(error: error)
        }
    }

    private func decide() {
        if SharedModelContainer.needsGuardedMigration {
            phase = .preMigration
        } else {
            runBootstrap()   // fresh install or already-migrated fast path
        }
    }

    private func runBootstrap() {
        phase = .migrating
        // Bootstrap is synchronous main-actor work (SwiftData migration runs
        // on open); a Task hop lets the progress frame render first.
        Task { @MainActor in
            let outcome = SharedModelContainer.bootstrap()
            switch outcome {
            case .ready(let container, let restored):
                MerchantLearningHandoff.importIfPresent(into: container.mainContext)
                let noticePending = restored
                    || UserDefaults.appGroup.bool(forKey: SharedModelContainer.restorePendingNoticeKey)
                phase = .ready(container, showRestoreNotice: noticePending)
            case .backupFailed(let error):
                phase = .backupFailed(error)
            case .failedPermanently(let error):
                phase = .floor(error)
            }
        }
    }
}

// MARK: - Pre-migration screen (§9.4)

/// Calm, gain-framed, one decision. The automatic file backup has ALREADY been
/// made by the time the user sees this — the export is the user-held copy, not
/// the safety mechanism — so no red, no warning triangle.
private struct PreMigrationView: View {
    let onContinue: () -> Void

    @State private var exportURL: URL?
    @State private var exportFailed = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 48)

            Image("MascotCrab")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)

            Text("premigration.title")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.bcTextPrimary)
                .multilineTextAlignment(.center)

            Text("premigration.caption")
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 10) {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        exportLabel
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.bcAccent)
                } else {
                    Button {
                        prepareExport()
                    } label: {
                        exportLabel
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.bcAccent)
                }

                if exportFailed {
                    Text("premigration.export_failed")
                        .font(.footnote)
                        .foregroundStyle(Color.bcTextSecondary)
                }

                // Always enabled, one tap, never guilt-framed — declining the
                // user-held copy must not block anyone (§9.4).
                Button(action: onContinue) {
                    Text("premigration.continue")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.bcAccent)
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Color.bcPage.ignoresSafeArea())
    }

    private var exportLabel: some View {
        Label("premigration.export", systemImage: "square.and.arrow.up")
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    /// Read-only V1 open → existing CSV export → temp file for the ShareLink.
    /// Failure lands back here with "Continue" still available — the export is
    /// optional in every path.
    private func prepareExport() {
        do {
            let result = try CSVExportService.makeCSVFromV1Store()
            exportURL = try TemporaryFileService.writeTemporaryFile(
                data: result.data, filename: result.filename)
            exportFailed = false
        } catch {
            logSaveFailure("PreMigrationView.export", error)
            exportFailed = true
        }
    }
}

// MARK: - Progress

private struct MigrationProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("migration.working")
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bcPage.ignoresSafeArea())
    }
}

// MARK: - Backup failed (halt — gap fix)

/// The backup could not be written, so the migration was NOT attempted and the
/// store is untouched. Surfaced, never silent; retry re-runs the whole decide
/// path.
private struct BackupFailedView: View {
    let error: Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 48)
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.bcWarningInk)
            Text("backupfail.title")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.bcTextPrimary)
                .multilineTextAlignment(.center)
            Text("backupfail.caption")
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: onRetry) {
                Text("backupfail.retry")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.bcAccent)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Color.bcPage.ignoresSafeArea())
    }
}

// MARK: - Degraded floor (§10.4)

/// The ladder is exhausted. The store on disk is the restored pristine V1
/// copy — intact, viewable via the V1 read-only path, exportable. Full app
/// functionality waits for a fix release; the user's data never does.
private struct MigrationFloorView: View {
    let error: Error

    @State private var exportURL: URL?
    @State private var exportFailed = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 48)
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44))
                .foregroundStyle(Color.bcAccent)
            Text("floor.title")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.bcTextPrimary)
                .multilineTextAlignment(.center)
            Text("floor.caption")
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if exportFailed {
                Text("premigration.export_failed")
                    .font(.footnote)
                    .foregroundStyle(Color.bcTextSecondary)
            }
            Spacer()

            VStack(spacing: 10) {
                if let exportURL {
                    ShareLink(item: exportURL) { floorExportLabel }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.bcAccent)
                } else {
                    Button { prepareExport() } label: { floorExportLabel }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.bcAccent)
                }

                Button {
                    openSupportMail()
                } label: {
                    Label("floor.contact", systemImage: "envelope")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.bcAccent)
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Color.bcPage.ignoresSafeArea())
    }

    private var floorExportLabel: some View {
        Label("floor.export", systemImage: "square.and.arrow.up")
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    private func prepareExport() {
        do {
            let result = try CSVExportService.makeCSVFromV1Store()
            exportURL = try TemporaryFileService.writeTemporaryFile(
                data: result.data, filename: result.filename)
            exportFailed = false
        } catch {
            logSaveFailure("MigrationFloorView.export", error)
            exportFailed = true
        }
    }

    /// mailto with version + the migration error's domain/code — never ledger
    /// contents (PersistenceLog privacy rule).
    private func openSupportMail() {
        let ns = error as NSError
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let subject = "Budget Crab \(version) — storage update failed (\(ns.domain) \(ns.code))"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(FeedbackComposer.address)?subject=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Restore notice (§10.5)

/// Full-screen, must-acknowledge — never a toast. The count comes from the
/// LIVE post-restore store, so the sentence is verifiable by the user against
/// their own ledger.
private struct RestoreNoticeView: View {
    let container: ModelContainer
    let onAcknowledge: () -> Void

    private var transactionCount: Int {
        (try? container.mainContext.fetchCount(FetchDescriptor<Transaction>())) ?? 0
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 48)
            Image(systemName: "arrow.counterclockwise.circle")
                .font(.system(size: 44))
                .foregroundStyle(Color.bcAccent)
            Text("restore.title")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.bcTextPrimary)
                .multilineTextAlignment(.center)
            Text(String(format: NSLocalizedString("restore.caption.format", comment: ""),
                        transactionCount))
                .font(.subheadline)
                .foregroundStyle(Color.bcTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
            Spacer()
            Button(action: onAcknowledge) {
                Text("restore.ack")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.bcAccent)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .background(Color.bcPage.ignoresSafeArea())
    }
}
