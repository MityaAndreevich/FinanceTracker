//
//  FeedbackView.swift
//  FinanceTracker
//
//  "Tell me what's missing" (1.0.3 Item 5) — the only feedback channel a
//  privacy-first app can have: a mail composer the USER sends, pre-addressed
//  to support with app version + language + device model in the subject.
//  Nothing else is attached: no identifiers, no settings dump, and never
//  anything from the ledger.
//
//  When no mail account is configured, MFMailComposeViewController cannot be
//  presented at all, so the sheet degrades to showing the address with a copy
//  button instead of failing silently.
//

import SwiftUI
import MessageUI
import UIKit

enum FeedbackComposer {

    /// The published support address (matches the website + App Store listing).
    static let address = "support@budgetcrab.app"

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// "Budget Crab 1.0.3 (6) · en · iPhone14,5" — version, language, hardware.
    /// Deliberately locale-neutral (it's routing metadata, not prose) and
    /// deliberately free of anything personal.
    static var subject: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let language = LocalizedBundle.shared.languageCode ?? "?"
        return "Budget Crab \(version) (\(build)) · \(language) · \(deviceModelIdentifier)"
    }

    /// A localized opening prompt so the empty body doesn't stare back.
    static var bodyPrompt: String {
        LocalizedBundle.shared.bundle
            .localizedString(forKey: "feedback.body_prompt", value: "", table: nil) + "\n\n"
    }

    /// Hardware identifier ("iPhone14,5"); "arm64" in the simulator. Routing
    /// metadata only — it identifies a product line, never a person.
    private static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

/// The Settings row's sheet: the mail composer when mail is configured, the
/// copy-the-address fallback otherwise.
struct FeedbackView: View {
    var body: some View {
        if FeedbackComposer.canSendMail {
            MailComposeView(
                recipient: FeedbackComposer.address,
                subject: FeedbackComposer.subject,
                body: FeedbackComposer.bodyPrompt
            )
            .ignoresSafeArea()
        } else {
            FeedbackFallbackView()
        }
    }
}

private struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let recipient: String
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}

/// No mail account: show the address, offer a one-tap copy. Never a dead end.
private struct FeedbackFallbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 24)

                Image(systemName: "envelope.badge")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.bcAccent)

                Text("feedback.mail_unavailable.title")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.bcTextPrimary)
                    .multilineTextAlignment(.center)

                Text("feedback.mail_unavailable.caption")
                    .font(.subheadline)
                    .foregroundStyle(Color.bcTextSecondary)
                    .multilineTextAlignment(.center)

                Text(verbatim: FeedbackComposer.address)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.bcTextPrimary)
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = FeedbackComposer.address
                    copied = true
                } label: {
                    Label(copied ? "feedback.copied" : "feedback.copy_address",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.bcAccent)
                .sensoryFeedback(.success, trigger: copied)

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.bcPage.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}
