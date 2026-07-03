//
//  AppearanceMode.swift
//  FinanceTracker
//
//  User-selectable app appearance (System / Light / Dark). Dark is the default
//  for the redesigned Budget Crab look — see outputs/DESIGN_DIRECTION_v2.md §1.
//  Stored in @AppStorage("appearanceMode") and applied via .preferredColorScheme
//  at the app root (RootView).
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// The scheme to force, or nil to follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .system: return "settings.appearance.system"
        case .light:  return "settings.appearance.light"
        case .dark:   return "settings.appearance.dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon.stars"
        }
    }
}
