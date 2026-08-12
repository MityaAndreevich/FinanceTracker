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

// MARK: - Setup guide (Settings → "Set up Widget & Siri")

/// The two capabilities that are configured OUTSIDE the app — the Home Screen
/// widget and the Siri / Shortcuts intents — given one findable home.
///
/// Both shipped and were never mentioned anywhere in the product: the widget has
/// been redesigned twice and the intents are auto-surfaced to Siri, the Action
/// Button and Shortcuts, yet the only place either was described was an article
/// four taps inside Learn & Tips. Because the setup steps happen on another
/// screen entirely, no coach-mark or in-context hint can reach them — a signpost
/// is the whole available fix, and this is it.
///
/// Deliberately no new article copy: `help.widget.body` already gives the exact
/// Home Screen procedure and `help.siri.body` the exact phrasing to say.
struct SetupGuideView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    HelpArticleView(article: .widget)
                } label: {
                    Label("help.widget", systemImage: "rectangle.on.rectangle")
                }

                NavigationLink {
                    HelpArticleView(article: .siri)
                } label: {
                    Label("help.siri", systemImage: "waveform")
                }
            } footer: {
                Text("settings.setup_guide.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.setup_guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HelpArticleView(article: .quickAdd) }
}
