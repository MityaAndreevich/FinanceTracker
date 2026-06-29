//
//  AboutView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import SwiftUI
import StoreKit

struct AboutView: View {
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        List {
            Section {
                HStack {
                    Text("about.app")
                    Spacer()
                    Text("about.app_name") // можно и ключом, и Bundle display name
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("about.version")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    requestReview()
                } label: {
                    Label("about.rate", systemImage: "star")
                }

                ShareLink(item: Self.appStoreURL,
                          message: Text("about.tell_friend.share")) {
                    Label("about.tell_friend", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Text("about.privacy_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)   // Bug 10: full wrap for longer RU/UK copy
            }
        }
        .navigationTitle("settings.about")
        .listStyle(.insetGrouped)
    }

    /// App Store URL — replace `idTBD` with the real App ID once Apple assigns it post-submission.
    private static let appStoreURL = URL(string: "https://apps.apple.com/app/budget-crab/idTBD")!

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
