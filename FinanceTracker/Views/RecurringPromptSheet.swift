//
//  RecurringPromptSheet.swift
//  FinanceTracker
//
//  Surfaced on launch when one or more recurring charges are due. Walks the
//  user through each due charge with Add / Skip / Edit.
//

import SwiftUI

struct RecurringPromptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [RecurrencePrompt]

    /// A failed confirm is otherwise indistinguishable from a successful one:
    /// the sheet advances, the prompt is gone for this sitting, and no charge
    /// was written. Now that `confirm` leaves the boundary untouched on failure
    /// the prompt does come back next launch — but the user has to be told, or
    /// they will believe this period was already logged.
    @State private var showAddFailed = false

    let onEdit: (RecurrencePrompt) -> Void

    init(prompts: [RecurrencePrompt], onEdit: @escaping (RecurrencePrompt) -> Void) {
        _queue = State(initialValue: prompts)
        self.onEdit = onEdit
    }

    private var current: RecurrencePrompt? { queue.first }

    var body: some View {
        VStack(spacing: 24) {
            if let prompt = current {
                Spacer(minLength: 8)

                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)

                Text("recurring.prompt.title")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(promptMessage(prompt))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .privacySensitive(true)

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Button {
                        // Advance only on success — an unadvanced queue is what
                        // lets the user retry the same period straight away.
                        if RecurrenceService.confirm(prompt, modelContext: modelContext) {
                            advance()
                        } else {
                            showAddFailed = true
                        }
                    } label: {
                        Text("recurring.prompt.add_button")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)

                    Button {
                        onEdit(prompt)
                        dismiss()
                    } label: {
                        Text("recurring.prompt.edit_button")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        RecurrenceService.skip(prompt, modelContext: modelContext)
                        advance()
                    } label: {
                        Text("recurring.prompt.skip_button")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .padding(.top, 24)
        .presentationDetents([.medium])
        .alert("common.error", isPresented: $showAddFailed) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("add.error.save_failed")
        }
    }

    private func advance() {
        queue.removeFirst()
        if queue.isEmpty { dismiss() }
    }

    private func promptMessage(_ prompt: RecurrencePrompt) -> String {
        let merchant = prompt.merchant.isEmpty
            ? String(localized: "recurring.notif.fallback_merchant")
            : prompt.merchant
        let amount = Money.format(cents: prompt.amountCents, currencyCode: prompt.currency)
        return String(format: String(localized: "recurring.prompt.add"), merchant, amount)
    }
}
