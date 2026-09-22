//
//  ReportsSettingsView.swift
//  FinanceTracker
//
//  Automatic weekly / monthly report notifications — the AlertsSettingsView
//  shape: premium gate, a plain pointer to Settings when notifications are
//  denied (shown once, never nagged), permission asked only when a toggle is
//  turned on. Scheduling happens on the next refresh pass, which is the one
//  place that owns the entitlement check.
//

import SwiftUI
import UIKit
import UserNotifications

struct ReportsSettingsView: View {
    @AppStorage(ReportNotificationPolicy.Keys.weeklyEnabled) private var weeklyEnabled = false
    @AppStorage(ReportNotificationPolicy.Keys.weeklyWeekday) private var weeklyWeekday = ReportNotificationPolicy.Settings.defaults.weeklyWeekday
    @AppStorage(ReportNotificationPolicy.Keys.weeklyHour) private var weeklyHour = ReportNotificationPolicy.Settings.defaults.weeklyHour
    @AppStorage(ReportNotificationPolicy.Keys.weeklyMinute) private var weeklyMinute = ReportNotificationPolicy.Settings.defaults.weeklyMinute
    @AppStorage(ReportNotificationPolicy.Keys.monthlyEnabled) private var monthlyEnabled = false
    @AppStorage(ReportNotificationPolicy.Keys.monthlyHour) private var monthlyHour = ReportNotificationPolicy.Settings.defaults.monthlyHour
    @AppStorage(ReportNotificationPolicy.Keys.monthlyMinute) private var monthlyMinute = ReportNotificationPolicy.Settings.defaults.monthlyMinute

    @ObservedObject private var access = AccessManager.shared
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPaywall = false

    private var isDenied: Bool { authStatus == .denied }

    var body: some View {
        List {
            if !access.isAllowed(.scheduledReports) {
                premiumSection
            } else {
                if isDenied { deniedSection }
                weeklySection
                monthlySection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("reports.settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { authStatus = await ReportNotificationScheduler.authorizationStatus() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .languageReactive()
    }

    private var weeklySection: some View {
        Section {
            Toggle("reports.settings.weekly.toggle", isOn: $weeklyEnabled)
                .onChange(of: weeklyEnabled) { _, isOn in Task { await toggled(on: isOn) } }
                .accessibilityIdentifier("reports_weekly_toggle")
            if weeklyEnabled && !isDenied {
                Picker("reports.settings.day", selection: $weeklyWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdayName(weekday)).tag(weekday)
                    }
                }
                timePicker(hour: $weeklyHour, minute: $weeklyMinute)
            }
        } footer: {
            Text("reports.settings.weekly.footer")
        }
    }

    private var monthlySection: some View {
        Section {
            Toggle("reports.settings.monthly.toggle", isOn: $monthlyEnabled)
                .onChange(of: monthlyEnabled) { _, isOn in Task { await toggled(on: isOn) } }
                .accessibilityIdentifier("reports_monthly_toggle")
            if monthlyEnabled && !isDenied {
                timePicker(hour: $monthlyHour, minute: $monthlyMinute)
            }
        } footer: {
            Text("reports.settings.monthly.footer")
        }
    }

    private func timePicker(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        DatePicker(
            "reports.settings.time",
            selection: Binding(
                get: { Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? .now },
                set: { newValue in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    hour.wrappedValue = comps.hour ?? 9
                    minute.wrappedValue = comps.minute ?? 0
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    private var premiumSection: some View {
        Section {
            Button { showPaywall = true } label: {
                Label("reports.settings.weekly.toggle", systemImage: "lock")
            }
            Button { showPaywall = true } label: {
                Label("reports.settings.monthly.toggle", systemImage: "lock")
            }
        } footer: {
            Text("reports.settings.footer")
        }
    }

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
            Text("reports.settings.denied.message")
        }
    }

    private func toggled(on isOn: Bool) async {
        guard isOn else {
            // The refresh pass will drop the request for a disabled cadence; do it
            // now too so the change is visible immediately in Settings → Notifications.
            ReportNotificationRefresher.apply(isAllowed: access.isAllowed(.scheduledReports))
            return
        }
        if authStatus == .notDetermined {
            _ = await ReportNotificationScheduler.requestAuthorization()
            authStatus = await ReportNotificationScheduler.authorizationStatus()
        }
        ReportNotificationRefresher.apply(isAllowed: access.isAllowed(.scheduledReports))
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        let index = weekday - 1
        return symbols.indices.contains(index) ? symbols[index] : "\(weekday)"
    }
}
