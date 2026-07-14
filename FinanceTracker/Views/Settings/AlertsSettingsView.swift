//
//  AlertsSettingsView.swift
//  FinanceTracker
//
//  One weekly, gain-framed notification — on the user's schedule, or not at all.
//
//  Three blocked states, each of which is a real person rather than an error: a free user
//  (paywall), someone who denied notifications at the OS level (a plain pointer to
//  Settings, shown once, never nagged), and someone with no budget (without one there is
//  no safe-to-spend number, so there is nothing truthful to say).
//

import SwiftUI
import UIKit
import UserNotifications

struct AlertsSettingsView: View {
    @AppStorage("alertsEnabled") private var alertsEnabled = false
    @AppStorage("alertWeekday") private var alertWeekday = 6      // Friday
    @AppStorage("alertHour") private var alertHour = 18
    @AppStorage("alertMinute") private var alertMinute = 0
    @AppStorage("monthlyBudgetCents") private var monthlyBudgetCents = 0

    @ObservedObject private var access = AccessManager.shared

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPaywall = false
    @State private var showBudgetSetter = false

    private var isBudgetSet: Bool { monthlyBudgetCents > 0 }
    private var isDenied: Bool { authStatus == .denied }

    var body: some View {
        List {
            if !access.isAllowed(.proactiveAlerts) {
                premiumSection
            } else if !isBudgetSet {
                needsBudgetSection
            } else {
                if isDenied { deniedSection }
                alertSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task { authStatus = await ProactiveAlertScheduler.authorizationStatus() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showBudgetSetter) { BudgetSetterSheet() }
    }

    // MARK: - The real thing

    private var alertSection: some View {
        Section {
            Toggle("alerts.toggle", isOn: $alertsEnabled)
                .onChange(of: alertsEnabled) { _, isOn in
                    Task { await toggled(on: isOn) }
                }

            if alertsEnabled && !isDenied {
                Picker("alerts.day", selection: $alertWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdayName(weekday)).tag(weekday)
                    }
                }

                DatePicker(
                    "alerts.time",
                    selection: Binding(
                        get: { timeOfDay },
                        set: { newValue in
                            let comps = Calendar.current.dateComponents(
                                [.hour, .minute], from: newValue
                            )
                            alertHour = comps.hour ?? 18
                            alertMinute = comps.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("alerts.section.title")
        } footer: {
            Text("alerts.footer")
        }
    }

    // MARK: - Blocked states

    private var premiumSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                Label("alerts.toggle", systemImage: "lock")
            }
        } footer: {
            Text("alerts.footer")
        }
    }

    private var needsBudgetSection: some View {
        Section {
            Button {
                showBudgetSetter = true
            } label: {
                Label("alerts.needs_budget.cta", systemImage: "target")
            }
        } header: {
            Text("alerts.needs_budget.title")
        } footer: {
            Text("alerts.needs_budget.message")
        }
    }

    /// Stated once, in place. No repeat prompting — the user already said no, and the
    /// brief is explicit that we do not nag.
    private var deniedSection: some View {
        Section {
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Label("alerts.denied.cta", systemImage: "gear")
            }
        } header: {
            Text("alerts.denied.title")
        } footer: {
            Text("alerts.denied.message")
        }
    }

    // MARK: - Behaviour

    /// Permission is asked for here and nowhere else — the moment the user opts in, never
    /// at launch.
    private func toggled(on isOn: Bool) async {
        guard isOn else {
            ProactiveAlertScheduler.cancel()
            return
        }
        if authStatus == .notDetermined {
            _ = await ProactiveAlertScheduler.requestAuthorization()
            authStatus = await ProactiveAlertScheduler.authorizationStatus()
        }
        // The scheduling itself happens on the next refresh (foreground / didSave), which
        // is the one place that owns the ledger snapshot.
    }

    private var timeOfDay: Date {
        Calendar.current.date(
            from: DateComponents(hour: alertHour, minute: alertMinute)
        ) ?? .now
    }

    private func weekdayName(_ weekday: Int) -> String {
        // Calendar weekday numbering is 1-based (1 = Sunday); the symbols array is 0-based.
        let symbols = Calendar.current.standaloneWeekdaySymbols
        let index = max(0, min(symbols.count - 1, weekday - 1))
        return symbols[index].capitalized
    }
}

#Preview {
    NavigationStack { AlertsSettingsView() }
}
