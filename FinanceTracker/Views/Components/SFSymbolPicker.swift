//
//  SFSymbolPicker.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.02.2026.
//

import SwiftUI

struct SFSymbolPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String

    @State private var query: String = ""

    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 12), count: 6)

    // Минимальный, но хороший набор. Потом расширим/заменим на твой список.
    private let symbols: [String] = [
        "fork.knife", "cart", "bag", "creditcard", "banknote", "dollarsign.circle",
        "car", "fuelpump", "house", "bolt", "airplane", "tram",
        "heart", "cross.case", "pills", "stethoscope",
        "gift", "gamecontroller", "music.note", "film", "book",
        "graduationcap", "briefcase", "hammer", "wrench.and.screwdriver",
        "bus", "bicycle", "figure.walk", "figure.run",
        "cup.and.saucer", "takeoutbag.and.cup.and.straw",
        "wifi", "tv", "phone", "laptopcomputer",
        "leaf", "pawprint", "tshirt", "sparkles", "star", "tag",
        "questionmark.circle", "ellipsis.circle"
    ]

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            selected = name
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.thinMaterial)

                                Image(systemName: name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .padding(10)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selected == name ? Color.accentColor : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(name))
                    }
                }
                .padding(16)
            }
            .navigationTitle("icons.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("icons.clear") {
                        selected = ""
                        dismiss()
                    }
                }
            }
            .searchable(text: $query, prompt: Text("icons.search"))
        }
        .presentationDetents([.medium, .large])
    }
}
