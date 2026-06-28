//
//  ElevatedSelectionList.swift
//  FinanceTracker
//
//  Premium "Elevated Selection List" replacing native .pickerStyle(.wheel) in
//  onboarding. Research-validated pattern (Brief 28H addendum, NotebookLM UX):
//  a scrollable list with card-elevated rows, Material/secondary backgrounds for
//  depth, accent fill + haptic + symbol animation on selection, and an optional
//  search field for long lists. The native wheel read as cheap/utilitarian; this
//  matches the "Quiet Premium" archetype (Calm, Headspace, Things 3, Bear, N26).
//

import SwiftUI

struct ElevatedSelectionList<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let labelProvider: (Item) -> (flag: String, title: String)
    let searchable: Bool

    @State private var searchText = ""

    private var filtered: [Item] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter { item in
            let label = labelProvider(item)
            return label.title.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if searchable && items.count > 6 {
                searchField
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { item in
                        SelectionRow(
                            label: labelProvider(item),
                            isSelected: selection == item
                        ) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                selection = item
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.visible)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("common.search", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }
}

private struct SelectionRow: View {
    let label: (flag: String, title: String)
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(label.flag)
                    .font(.system(size: 32))

                Text(label.title)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: isSelected)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.04),
                radius: isSelected ? 10 : 4,
                y: isSelected ? 4 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
