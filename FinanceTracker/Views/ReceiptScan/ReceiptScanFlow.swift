//
//  ReceiptScanFlow.swift
//  FinanceTracker
//
//  Capture (paper via VisionKit's document camera, screenshot via the
//  out-of-process PhotosPicker) → on-device recognition → `ReceiptReviewSheet`
//  → `AddTransactionView(prefill:)`. The form's Save is the only save; nothing
//  here writes to the store. Design: outputs/DESIGN_RECEIPT_SCAN.md §4.
//
//  The image lives in memory for the duration of the review and is dropped
//  when the sheet closes (attachment deferred to 1.0.8, founder's decision).
//

import PhotosUI
import SwiftUI
import UIKit
import VisionKit

/// One scan in flight. Owned by the presenting sheet as a `@StateObject`.
@MainActor
final class ReceiptScanCoordinator: ObservableObject {

    enum Stage: Equatable {
        case idle
        case recognizing
        case review
        case failed(String)
    }

    @Published var stage: Stage = .idle
    @Published var showCamera = false
    @Published var photoSelection: PhotosPickerItem?
    @Published private(set) var image: UIImage?
    @Published private(set) var parse: ReceiptParser.Parse?
    @Published private(set) var languagesUsed: [String] = []

    private let appLanguageCode: String?
    private let decimalSeparator: Character

    init(appLanguageCode: String?, decimalSeparator: Character) {
        self.appLanguageCode = appLanguageCode
        self.decimalSeparator = decimalSeparator
    }

    func reset() {
        stage = .idle
        image = nil
        parse = nil
        photoSelection = nil
    }

    /// Entry for both capture paths. Counts against the monthly quota the
    /// moment recognition starts (S1: five free per month).
    func process(_ uiImage: UIImage) {
        guard let cg = uiImage.cgImage else {
            stage = .failed("no cgImage")
            return
        }
        image = uiImage
        stage = .recognizing
        ReceiptScanQuota.recordScan()
        let code = appLanguageCode, sep = decimalSeparator
        Task {
            do {
                let result = try await ReceiptRecognizer.recognize(cg, appLanguageCode: code)
                let parsed = ReceiptParser.parse(lines: result.lines, decimalSeparator: sep,
                                                 calendar: .current, now: Date())
                await MainActor.run {
                    self.languagesUsed = result.languagesUsed
                    self.parse = parsed
                    self.stage = .review
                }
            } catch {
                let ns = error as NSError
                persistenceLog.error("receipt recognition failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
                await MainActor.run { self.stage = .failed(ns.localizedDescription) }
            }
        }
    }

    func loadPickedPhoto() {
        guard let item = photoSelection else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                    await MainActor.run { self.process(ui) }
                } else {
                    await MainActor.run { self.stage = .failed("unreadable image") }
                }
            } catch {
                let ns = error as NSError
                persistenceLog.error("receipt photo load failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
                await MainActor.run { self.stage = .failed(ns.localizedDescription) }
            }
        }
    }
}

// MARK: - The scan button (lives in Quick Entry and the full form)

/// A menu with the two capture paths, gated by the counted cap. On a completed
/// scan it presents the review sheet, which in turn presents the form.
struct ReceiptScanButton: View {
    @AppStorage("appLanguageCode") private var appLanguageCode: String = "system"
    @ObservedObject private var access = AccessManager.shared
    @StateObject private var coordinator: ReceiptScanCoordinator
    @State private var showPaywall = false
    @State private var showReview = false
    @State private var showPhotoPicker = false
    /// Handed on only AFTER the review sheet has finished dismissing, so the
    /// presenting sheet never opens the form while another sheet is going away
    /// (that race left the form unprefilled in the UI journey).
    @State private var pendingPrefill: AddTransactionPrefill?

    /// Called with the prefill when the user taps "Use these".
    let onUse: (AddTransactionPrefill) -> Void

    init(onUse: @escaping (AddTransactionPrefill) -> Void) {
        self.onUse = onUse
        let code = UserDefaults.standard.string(forKey: "appLanguageCode")
        let sep: Character = Locale.current.decimalSeparator == "," ? "," : "."
        _coordinator = StateObject(wrappedValue: ReceiptScanCoordinator(
            appLanguageCode: code == "system" ? nil : code, decimalSeparator: sep))
    }

    var body: some View {
        Menu {
            Button {
                gate { coordinator.showCamera = true }
            } label: {
                Label("scan.menu.camera", systemImage: "camera")
            }
            Button {
                gate {
                    #if DEBUG
                    // UI tests cannot drive the picker; the seam renders a fixture
                    // and hands it to the REAL recogniser instead.
                    if ReceiptScanDebugSeam.isRequested, let fixture = ReceiptScanDebugSeam.renderFixture() {
                        coordinator.process(fixture)
                        return
                    }
                    #endif
                    showPhotoPicker = true
                }
            } label: {
                Label("scan.menu.screenshot", systemImage: "photo.on.rectangle")
            }
        } label: {
            ZStack {
                Circle().fill(Color.bcAccent.opacity(0.16))
                Image(systemName: access.canAdd(.receiptScan, currentCount: ReceiptScanQuota.count()) ? "doc.viewfinder" : "lock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
            }
            .frame(width: 40, height: 40)
        }
        .accessibilityLabel(Text("scan.a11y.button"))
        .accessibilityIdentifier("receipt_scan_button")
        // Out-of-process picker: no photo-library permission, no usage string.
        .photosPicker(isPresented: $showPhotoPicker, selection: $coordinator.photoSelection,
                      matching: .any(of: [.screenshots, .images]))
        .onChange(of: coordinator.photoSelection) { _, item in
            guard item != nil else { return }
            coordinator.loadPickedPhoto()
        }
        .onChange(of: coordinator.stage) { _, stage in
            if case .review = stage { showReview = true }
        }
        .fullScreenCover(isPresented: $coordinator.showCamera) {
            DocumentCameraView { page in
                coordinator.showCamera = false
                if let page { coordinator.process(page) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showReview, onDismiss: {
            coordinator.reset()
            if let prefill = pendingPrefill {
                pendingPrefill = nil
                onUse(prefill)
            }
        }) {
            ReceiptReviewSheet(coordinator: coordinator) { prefill in
                pendingPrefill = prefill
                showReview = false
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("scan.failed.title", isPresented: Binding(
            get: { if case .failed = coordinator.stage { return true } else { return false } },
            set: { if !$0 { coordinator.reset() } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("scan.failed.message")
        }
    }

    private func gate(_ action: @escaping () -> Void) {
        CapGate.attempt(.receiptScan, currentCount: ReceiptScanQuota.count(),
                        access: access, showPaywall: $showPaywall, action: action)
    }
}

// MARK: - VisionKit document camera

struct DocumentCameraView: UIViewControllerRepresentable {
    /// Page 1 of the scan, or nil on cancel / failure.
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Only page 1 is parsed (DESIGN §4.1); a multi-page scan is not an error.
            completion(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { completion(nil) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            let ns = error as NSError
            persistenceLog.error("document camera failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public)")
            completion(nil)
        }
    }
}
