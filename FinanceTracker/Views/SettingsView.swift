//
//  SettingsView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 15.01.2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Source.name, order: .forward) private var sources: [Source]

    @State private var newSourceName: String = ""
    @State private var newSourceNote: String = ""

    var body: some View {
        Form {
            Section("Add source") {
                TextField("Name (e.g., Amazon Flex)", text: $newSourceName)
                TextField("Note (optional)", text: $newSourceNote)

                Button("Add") {
                    addSource()
                }
                .disabled(newSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Sources") {
                if sources.isEmpty {
                    Text("No sources yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.headline)

                            if let note = source.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSources)
                }
            }
        }
        .navigationTitle("title.settings")
    }

    private func addSource() {
        let name = newSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let note = newSourceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(name: name, note: note.isEmpty ? nil : note)

        modelContext.insert(source)

        do {
            try modelContext.save()
            newSourceName = ""
            newSourceNote = ""
            hideKeyboard()
        } catch {
            // MVP: print. Позже сделаем alert.
            print("Failed to save source: \(error)")
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sources[index])
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete sources: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Source.self], inMemory: true)
}
