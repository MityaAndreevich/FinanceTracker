//
//  PeriodSelector.swift
//  FinanceTracker
//
//  A reusable scope picker used by Dashboard / Transactions / Analytics.
//  Lets the user toggle Month/All and navigate between months.
//

import SwiftUI

struct PeriodSelector: View {
    @Binding var scope: PeriodScope
    @Environment(\.locale) private var locale

    private enum Kind: String, CaseIterable, Identifiable {
        case month, all
        var id: String { rawValue }
    }

    private var kindBinding: Binding<Kind> {
        Binding(
            get: { scope.isMonth ? .month : .all },
            set: { newKind in
                switch newKind {
                case .month: scope = .currentMonth
                case .all:   scope = .all
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            Picker("scope.picker.title", selection: kindBinding) {
                Text("scope.month").tag(Kind.month)
                Text("scope.all").tag(Kind.all)
            }
            .pickerStyle(.segmented)

            if scope.isMonth {
                monthNavigator
            }
        }
    }

    private var monthNavigator: some View {
        HStack(spacing: 12) {
            Button {
                scope = scope.shifted(byMonths: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(Text("scope.previous_month"))
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button {
                scope = .currentMonth
            } label: {
                Text(scope.label(locale: locale))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 120)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("scope.this_month_button"))

            Spacer()

            Button {
                scope = scope.shifted(byMonths: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(Text("scope.next_month"))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!scope.canShiftForward())
        }
    }
}
