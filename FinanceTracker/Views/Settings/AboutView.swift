//
//  AboutView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 25.01.2026.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("App")
                    Spacer()
                    Text("FinanceTracker")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Privacy Policy and Terms will be added before App Store release.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .listStyle(.insetGrouped)
    }

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

#Preview {
    NavigationStack { AboutView() }
}
