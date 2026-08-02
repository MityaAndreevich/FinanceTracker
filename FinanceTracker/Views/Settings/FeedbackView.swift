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
//  1.0.4 addition — the optional usage summary. The app has no analytics, so
//  the only way to read the split-transaction pre-test (see
//  `outputs/DECISION_RECEIPT_INPUT_PRETEST.md`) is to ask the person writing
//  in. That makes the consent step below load-bearing rather than decorative:
//
//    - the summary is RENDERED, VERBATIM, on screen before Mail ever opens.
//      What you read on the consent screen is byte-for-byte what lands in the
//      body; there is no second, richer payload.
//    - the app transmits NOTHING. `MFMailComposeViewController` hands a draft
//      to Mail; the user presses Send, edits it first, or cancels.
//    - a labelled toggle removes the block entirely, and it persists.
//
//  When no mail account is configured, MFMailComposeViewController cannot be
//  presented at all, so the sheet degrades to showing the address with a copy
//  button instead of failing silently.
//

import SwiftUI
import SwiftData
import MessageUI
import UIKit

enum FeedbackComposer {

    /// The published support address (matches the website + App Store listing).
    static let address = "support@budgetcrab.app"

    /// Persisted opt-out for the usage summary. Defaults to ON deliberately:
    /// the block is shown in full before sending and one tap removes it, so
    /// default-off would buy no additional honesty and would collect nothing.
    static let includeUsageSummaryKey = "feedbackIncludeUsageSummary"

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// "Budget Crab 1.0.3 (6) · en · iPhone14,5" — version, language, hardware.
    /// Deliberately locale-neutral (it's routing metadata, not prose) and
    /// deliberately free of anything personal. This is NOT governed by the
    /// usage-summary toggle — it is how a support mail gets triaged at all,
    /// it predates the summary, and the consent screen says so plainly rather
    /// than letting the toggle imply it covers the subject line too.
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

    /// The full mail body: the prompt, then the summary block if the user
    /// left it on. The summary goes AFTER the prompt so the cursor lands in
    /// the empty space where they actually write.
    static func body(summary: UsageSummary?) -> String {
        guard let summary else { return bodyPrompt }
        return bodyPrompt + summary.render(bundle: LocalizedBundle.shared.bundle)
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

/// The Settings row's sheet: the consent screen → mail composer when mail is
/// configured, the copy-the-address fallback otherwise.
struct FeedbackView: View {
    var body: some View {
        if FeedbackComposer.canSendMail {
            FeedbackConsentView()
        } else {
            FeedbackFallbackView()
        }
    }
}

// MARK: - Consent

/// Shows what will be sent, lets the user drop the usage block, then opens
/// Mail. Deliberately one screen and one button — this sits in front of the
/// only feedback channel the app has, so it must not read as a form.
private struct FeedbackConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(FeedbackComposer.includeUsageSummaryKey) private var includeUsage = true
    @AppStorage("firstLaunchDate") private var firstLaunchInterval: Double = 0

    /// Built once when the sheet appears, not on every toggle flip — the
    /// numbers must not appear to move while the user is deciding.
    @State private var summary: UsageSummary?
    @State private var isComposing = false

    private var renderedSummary: String {
        summary?.render(bundle: LocalizedBundle.shared.bundle) ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("feedback.consent.explainer")
                        .font(.subheadline)
                        .foregroundStyle(Color.bcTextSecondary)
                }

                Section {
                    Toggle("feedback.consent.toggle", isOn: $includeUsage)
                        .tint(Color.bcAccent)
                } footer: {
                    Text("feedback.consent.toggle_caption")
                }

                if includeUsage, summary != nil {
                    Section {
                        Text(verbatim: renderedSummary.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.bcTextPrimary)
                            .textSelection(.enabled)
                    } header: {
                        Text("feedback.consent.preview_header")
                    } footer: {
                        Text("feedback.consent.subject_note")
                    }
                }
            }
            .navigationTitle("feedback.row")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("feedback.consent.continue") { isComposing = true }
                }
            }
            .task {
                guard summary == nil else { return }
                summary = UsageSummaryBuilder.build(
                    modelContext: modelContext,
                    firstLaunchInterval: firstLaunchInterval
                )
            }
            .fullScreenCover(isPresented: $isComposing) {
                MailComposeView(
                    recipient: FeedbackComposer.address,
                    subject: FeedbackComposer.subject,
                    body: FeedbackComposer.body(summary: includeUsage ? summary : nil),
                    onFinish: {
                        isComposing = false
                        dismiss()
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Mail

private struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}

// MARK: - Fallback

/// No mail account: show the address, offer a one-tap copy. Never a dead end.
/// No usage summary here — there is no body to put it in, and pasting a block
/// of stats into someone's clipboard uninvited is exactly the move this
/// feature is built to avoid.
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
