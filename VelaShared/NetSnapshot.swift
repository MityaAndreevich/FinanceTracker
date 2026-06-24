//
//  NetSnapshot.swift
//  Vela — shared by the app target and the VelaWidget extension.
//
//  A tiny, display-ready, Codable snapshot of the current month that the app
//  writes to the shared App Group on data changes and the widget reads. The
//  widget never opens SwiftData — it only renders these pre-computed strings,
//  so no model code or store access lives in the extension. Fully on-device:
//  the App Group container never leaves the phone.
//

import Foundation

/// Constants shared between the app and the widget extension.
enum WidgetSharing {
    /// App Group identifier — must match the entitlement on both targets.
    static let appGroupID = "group.com.dmitrylogachev.vela"
    static let snapshotKey = "net_snapshot_v1"
}

struct NetSnapshot: Codable {
    var monthLabel: String          // e.g. "June 2026" (already localized by the app)
    var netCents: Int               // sign drives the widget's +/− and color
    var heroAmount: String          // formatted absolute net, e.g. "$234"
    var spentText: String           // formatted, e.g. "Spent $567"
    var earnedText: String          // formatted, e.g. "Earned $801"
    var topCategories: [Item]
    var recent: [Recent]
    var generatedAt: Date

    struct Item: Codable, Identifiable {
        var id: String { name }
        var name: String
        var amount: String          // formatted
    }

    struct Recent: Codable, Identifiable {
        var id: String
        var title: String
        var amount: String          // formatted, signed
        var isIncome: Bool
    }

    var isPositive: Bool { netCents >= 0 }
}

// MARK: - Shared App Group persistence

extension NetSnapshot {
    static func load() -> NetSnapshot? {
        guard let defaults = UserDefaults(suiteName: WidgetSharing.appGroupID),
              let data = defaults.data(forKey: WidgetSharing.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(NetSnapshot.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: WidgetSharing.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: WidgetSharing.snapshotKey)
    }

    /// Neutral placeholder used for the widget gallery / before the first write.
    static func placeholder() -> NetSnapshot {
        NetSnapshot(
            monthLabel: "—",
            netCents: 0,
            heroAmount: "—",
            spentText: "",
            earnedText: "",
            topCategories: [],
            recent: [],
            generatedAt: Date()
        )
    }
}
