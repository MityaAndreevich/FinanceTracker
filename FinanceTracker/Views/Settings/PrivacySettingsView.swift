//
//  PrivacySettingsView.swift
//  FinanceTracker
//

import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("requireAuthMode") private var requireAuthMode: RequireAuthMode = .always

    private static let privacyURL = URL(string: "https://dmitrylogachev.github.io/FinanceTracker/PRIVACY_POLICY.html")!

    var body: some View {
        List {
            heroSection
            onDeviceSection
            whatWeDoNotSection
            policySection
        }
        .navigationTitle("settings.privacy")
        .listStyle(.insetGrouped)
    }

    // MARK: - Sections

    private var heroSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("settings.privacy.title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("settings.privacy.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private var onDeviceSection: some View {
        Section("privacy.section.ondevice") {
            Picker("auth.setting.title", selection: $requireAuthMode) {
                Text("auth.setting.always").tag(RequireAuthMode.always)
                Text("auth.setting.after_5min").tag(RequireAuthMode.after5min)
                Text("auth.setting.never").tag(RequireAuthMode.never)
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var whatWeDoNotSection: some View {
        Section("privacy.section.whatwedonot") {
            ForEach(claims, id: \.self) { key in
                Label {
                    Text(LocalizedStringKey(key))
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var policySection: some View {
        Section {
            Link(destination: Self.privacyURL) {
                Label("privacy.policy.link", systemImage: "doc.text")
            }
        } footer: {
            Text("privacy.policy.hint")
        }
    }

    private let claims: [String] = [
        "privacy.claim.no_bank_login",
        "privacy.claim.no_cloud_account",
        "privacy.claim.no_data_uploaded",
        "privacy.claim.no_data_sold",
        "privacy.claim.no_ad_tracking",
        "privacy.claim.no_sdk",
    ]
}

#Preview {
    NavigationStack { PrivacySettingsView() }
}
