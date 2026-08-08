//
//  LearnAndTipsView.swift
//  FinanceTracker
//
//  The Learn & Tips hub: today's tip, the browsable tip library, and the annotated
//  help articles — one destination, so there is no second row that also looks like
//  "where I go to learn things". Free; no premium gate.
//
//  The help sections and their articles are the ones that used to live in HelpView;
//  HelpArticle and HelpArticleView are reused as-is so every `help.*` translation
//  survives the move.
//

import SwiftUI
import UIKit

struct LearnAndTipsView: View {
    private let supportEmailAddress = "support@budgetcrab.app"
    private let supportEmail = URL(string: "mailto:support@budgetcrab.app?subject=Budget%20Crab%20Support")!
    private let onlineFAQ = URL(string: "https://budgetcrab.app/support.html")!

    @State private var searchText = ""
    @State private var showCopiedToast = false

    // The per-user collection. Observed so the list updates the instant a launch
    // reveals a new tip while this screen is open.
    @ObservedObject private var tips = TipCollection.shared

    private var library: TipLibrary { TipLibraryCache.current }

    /// Today's hero: the user's most-recently unlocked tip.
    private var todaysTip: DailyTip? { tips.todaysTip }

    /// The rest of the unlocked collection, most-recent first. Today's hero is shown
    /// above this list, so it is filtered out here to avoid showing it twice. Empty
    /// on day 1 (only today's tip unlocked) — the section footer promises more.
    private var seenHistory: [DailyTip] {
        let heroID = todaysTip?.id
        return tips.collection.filter { $0.id != heroID }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Search is scoped to the UNLOCKED collection. Scoping to the full library
    /// would surface a still-locked tip through the search field and spoil the daily
    /// reveal the hub exists to preserve. Filtering lives on `TipLibrary` so it is
    /// unit-tested rather than trapped in a view.
    private var searchResults: [DailyTip] {
        library.matching(searchText, in: tips.collection)
    }

    /// The progress line under the collection: a count only, never any locked
    /// content. Once everything is unlocked, it says so instead of a count.
    private var unlockedProgress: String {
        tips.isComplete
            ? String(localized: "learn.collection_complete", bundle: LocalizedBundle.shared.bundle)
            : String(format: String(localized: "learn.unlocked_count", bundle: LocalizedBundle.shared.bundle),
                     tips.unlockedCount, tips.totalCount)
    }

    var body: some View {
        List {
            if library.isEmpty {
                // No content shipped yet: say so plainly rather than showing an empty
                // section with a search bar over nothing.
                Section {
                    EmptyStateView(
                        systemImage: "lightbulb",
                        title: "learn.empty.title",
                        message: "learn.empty.message"
                    )
                    .listRowBackground(Color.clear)
                }
            } else if isSearching {
                // Scoped to the unlocked collection only, so the search field can
                // never reveal a tip the user hasn't unlocked yet.
                Section("learn.seen_tips") {
                    if searchResults.isEmpty {
                        Text("learn.no_results")
                            .font(.bcCaption)
                            .foregroundStyle(Color.bcTextSecondary)
                    } else {
                        ForEach(searchResults) { tip in
                            tipNavigationRow(tip)
                        }
                    }
                }
            } else {
                if let tip = todaysTip {
                    Section("learn.tip_of_day") {
                        tipNavigationRow(tip)
                    }
                }

                // Only tips the user has already unlocked. Still-locked tips are
                // never listed or previewed — the collection grows one per day, and
                // that daily surprise is the whole point of the hub. The footer shows
                // progress as a count so there is a sense of "more to come" without
                // revealing anything locked.
                Section {
                    ForEach(seenHistory) { tip in
                        tipNavigationRow(tip)
                    }
                } header: {
                    Text("learn.seen_tips")
                } footer: {
                    Text(verbatim: unlockedProgress)
                        .font(.bcCaption)
                        .foregroundStyle(Color.bcTextSecondary)
                }
            }

            // Search is scoped to the tip library, so the help sections would be
            // unfiltered noise while a query is active.
            if !isSearching {
                helpSections
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: Text("learn.search"))
        .plainTextEntry()
        .navigationTitle("settings.learn_tips")
        .navigationBarTitleDisplayMode(.inline)
        .alert("help.email_copied", isPresented: $showCopiedToast) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private func tipNavigationRow(_ tip: DailyTip) -> some View {
        NavigationLink {
            TipDetailView(tip: tip)
        } label: {
            tipRow(tip)
        }
    }

    private func tipRow(_ tip: DailyTip) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(tip.term)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bcTextPrimary)
            Text(tip.explanation)
                .font(.bcCaption)
                .foregroundStyle(Color.bcTextSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Help (moved from HelpView)

    @ViewBuilder
    private var helpSections: some View {
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
            // Copy-to-clipboard works on any iPhone, even one with no Mail account
            // configured (Round 9 R3: mailto failed with "не удалось отправить" on
            // such devices). The mailto link is offered too for users who do have
            // Mail set up.
            Button {
                UIPasteboard.general.string = supportEmailAddress
                showCopiedToast = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                HStack {
                    Label("help.copy_email", systemImage: "doc.on.doc")
                    Spacer()
                    Text(verbatim: supportEmailAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Link(destination: supportEmail) {
                Label("help.open_in_mail", systemImage: "envelope.open")
            }

            Link(destination: onlineFAQ) {
                Label("help.online_faq", systemImage: "safari")
            }
        }
    }

    private func articleLink(_ article: HelpArticle, icon: String) -> some View {
        NavigationLink {
            HelpArticleView(article: article)
        } label: {
            Label(article.rowLabelKey, systemImage: icon)
        }
    }
}

// MARK: - Tip detail

struct TipDetailView: View {
    let tip: DailyTip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.compact) {
                Text(tip.term)
                    .font(.title2.bold())
                    .foregroundStyle(Color.bcTextPrimary)

                Text(tip.explanation)
                    .font(.bcBody)
                    .lineSpacing(4)
                    .foregroundStyle(Color.bcTextSecondary)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("learn.try_this")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bcAccent)
                    Text(tip.strategy)
                        .font(.bcBody)
                        .lineSpacing(4)
                        .foregroundStyle(Color.bcTextPrimary)
                }
                .padding(Spacing.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(Color.bcSurface1)
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Short articles must not rubber-band above the nav bar and "freeze"
        // overscrolled past the top (Round 9 R2).
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.bcPage.ignoresSafeArea())
        .navigationTitle(Text(verbatim: tip.term))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LearnAndTipsView() }
}
