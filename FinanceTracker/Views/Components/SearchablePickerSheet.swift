import SwiftUI

struct SearchablePickerSheet<Item: Identifiable & Hashable>: View {
    let titleKey: LocalizedStringKey
    let items: [Item]
    let labelProvider: (Item) -> String
    /// When set, each row gets the accessibility identifier "<prefix>.<item.id>"
    /// and the list gets "<prefix>.sheet", so UI tests can drive the picker in a
    /// language-independent way. nil (default) = no identifiers (production no-op).
    var identifierPrefix: String? = nil
    @Binding var selection: Item.ID
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Item] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { labelProvider($0).lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { item in
                Button {
                    selection = item.id
                    dismiss()
                } label: {
                    HStack {
                        Text(labelProvider(item))
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == item.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                        }
                    }
                }
                .accessibilityIdentifier(rowIdentifier(for: item))
            }
            .accessibilityIdentifier(sheetIdentifier)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .plainTextEntry()
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// "<prefix>.<item.id>" when a prefix is set, else "" (no-op identifier).
    private func rowIdentifier(for item: Item) -> String {
        guard let identifierPrefix else { return "" }
        return "\(identifierPrefix).\(item.id)"
    }

    /// "<prefix>.sheet" when a prefix is set, else "" (no-op identifier).
    private var sheetIdentifier: String {
        guard let identifierPrefix else { return "" }
        return "\(identifierPrefix).sheet"
    }
}
