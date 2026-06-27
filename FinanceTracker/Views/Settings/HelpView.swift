//
//  HelpView.swift
//  FinanceTracker
//
//  In-app Help & Tips — eight short articles plus contact links. Brief 28I
//  Section N1. All copy is localized (EN/RU/ES/pt-BR); articles are read-only.
//

import SwiftUI

struct HelpView: View {
    private let supportEmail = URL(string: "mailto:support@budgetcrab.app")!
    private let onlineFAQ = URL(string: "https://budgetcrab.app/support.html")!

    var body: some View {
        List {
            Section("help.getting_started.title") {
                articleLink(.quickAdd, icon: "sparkles")
                articleLink(.voiceEntry, icon: "mic")
                articleLink(.categories, icon: "tag")
            }

            Section("help.advanced.title") {
                articleLink(.analytics, icon: "chart.pie")
                articleLink(.widget, icon: "rectangle.on.rectangle")
                articleLink(.siri, icon: "waveform")
            }

            Section("help.privacy.title") {
                articleLink(.privacy, icon: "lock.iphone")
                articleLink(.languageChange, icon: "globe")
            }

            Section("help.contact.title") {
                Link(destination: supportEmail) {
                    Label("help.contact_support", systemImage: "envelope")
                }
                Link(destination: onlineFAQ) {
                    Label("help.online_faq", systemImage: "safari")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func articleLink(_ article: HelpArticle, icon: String) -> some View {
        NavigationLink {
            HelpArticleView(article: article)
        } label: {
            Label(article.rowLabelKey, systemImage: icon)
        }
    }
}

// MARK: - Articles

enum HelpArticle: String, Identifiable {
    case quickAdd, voiceEntry, categories, analytics, widget, siri
    case privacy, languageChange

    var id: String { rawValue }

    var rowLabelKey: LocalizedStringKey {
        switch self {
        case .quickAdd:       return "help.quick_add"
        case .voiceEntry:     return "help.voice_entry"
        case .categories:     return "help.categories"
        case .analytics:      return "help.analytics"
        case .widget:         return "help.widget"
        case .siri:           return "help.siri"
        case .privacy:        return "help.privacy_local_storage"
        case .languageChange: return "help.language_change"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .quickAdd:       return "help.quick_add.title"
        case .voiceEntry:     return "help.voice_entry.title"
        case .categories:     return "help.categories.title"
        case .analytics:      return "help.analytics.title"
        case .widget:         return "help.widget.title"
        case .siri:           return "help.siri.title"
        case .privacy:        return "help.privacy_local_storage.title"
        case .languageChange: return "help.language_change.title"
        }
    }

    var bodyKey: LocalizedStringKey {
        switch self {
        case .quickAdd:       return "help.quick_add.body"
        case .voiceEntry:     return "help.voice_entry.body"
        case .categories:     return "help.categories.body"
        case .analytics:      return "help.analytics.body"
        case .widget:         return "help.widget.body"
        case .siri:           return "help.siri.body"
        case .privacy:        return "help.privacy.body"
        case .languageChange: return "help.language_change.body"
        }
    }
}

struct HelpArticleView: View {
    let article: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.titleKey)
                    .font(.title2.bold())
                Text(article.bodyKey)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Short articles must not rubber-band above the nav bar and "freeze"
        // overscrolled past the top boundary (Round 9 R2). Bounce only when the
        // content is actually taller than the viewport.
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(article.titleKey)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HelpView() }
}
