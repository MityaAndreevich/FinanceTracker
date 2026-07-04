//
//  LanguageReactive.swift
//  FinanceTracker
//
//  In-place live re-localization (device QA round 1 #2).
//
//  `environment(\.locale)` refreshes `Text("key")` when the in-app language
//  changes, but already-realized `List`/`Form` rows and code-resolved
//  `String(localized:)` chrome do NOT re-resolve until the view is recreated —
//  so switching EN↔RU left rows in the launch language until relaunch.
//
//  Attaching `.languageReactive()` to a screen's *content* (its List / ScrollView,
//  BELOW the NavigationStack) rebuilds just that content when the language changes,
//  re-resolving every string in the new language — while the enclosing
//  NavigationStack and TabView keep their state, so the user stays exactly where
//  they are (no pop, no bounce, no restart). The modifier owns the observation, so
//  the screen it decorates doesn't need to observe anything itself.
//

import SwiftUI

private struct LanguageReactiveModifier: ViewModifier {
    // Observing the shared bundle re-invokes this modifier's body when the active
    // language changes; the new `.id` recreates `content`, forcing a fresh string
    // resolution. Scoped to `content`, so navigation state living above it survives.
    @ObservedObject private var bundle = LocalizedBundle.shared

    func body(content: Content) -> some View {
        content.id(bundle.languageCode ?? "system")
    }
}

extension View {
    /// Rebuilds this content in place whenever the in-app language changes so its
    /// `List`/`Form` rows and `String(localized:)` strings re-localize live, without
    /// resetting the enclosing navigation. Apply to a screen's root content view.
    func languageReactive() -> some View {
        modifier(LanguageReactiveModifier())
    }
}
