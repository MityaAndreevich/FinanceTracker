import SwiftUI

struct SearchablePickerSheet<Item: Identifiable & Hashable>: View {
    let titleKey: LocalizedStringKey
    let items: [Item]
    let labelProvider: (Item) -> String
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
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
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
}
