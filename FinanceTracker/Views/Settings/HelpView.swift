//
//  HelpView.swift
//  FinanceTracker
//
//  The eight annotated help articles. Brief 28I Section N1; all copy is localized
//  and the articles are read-only.
//
//  The `HelpView` list container that used to live here is gone — the articles are
//  now presented by `LearnAndTipsView`, so there is one "Learn & Tips" destination
//  rather than a Help row and a Tips row that both look like where you go to learn
//  things. `HelpArticle` and `HelpArticleView` are unchanged, which is what keeps
//  every existing `help.*` translation valid.
//

import SwiftUI

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
    NavigationStack { HelpArticleView(article: .quickAdd) }
}
