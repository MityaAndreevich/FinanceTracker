//
//  ReceiptReviewSheet.swift
//  FinanceTracker
//
//  What was recognised, before the form. Two shapes, one per confidence state
//  (DESIGN_RECEIPT_SCAN.md §4.5): `high` shows the amount filled with the line
//  it came from; `low` shows an EMPTY amount and says we couldn't find a total —
//  never "Total found". Every copy line here is a claim about what happened.
//
//  This sheet has no Save. "Use these" hands a prefill to AddTransactionView,
//  whose own Save is the only save.
//

import SwiftData
import SwiftUI

struct ReceiptReviewSheet: View {
    @ObservedObject var coordinator: ReceiptScanCoordinator
    let onUse: (AddTransactionPrefill) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @AppStorage("defaultCurrencyCode") private var currencyCode: String = "USD"

    /// The candidate the user picked from "other amounts", if any.
    @State private var chosen: ReceiptParser.AmountCandidate?
    @State private var showRawText = false

    private var parse: ReceiptParser.Parse? { coordinator.parse }
    private var effectiveTotal: ReceiptParser.AmountCandidate? {
        chosen ?? (parse?.confidence == .high ? parse?.total : nil)
    }

    var body: some View {
        NavigationStack {
            List {
                if let image = coordinator.image {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                    }
                }

                Section("scan.review.amount") {
                    if let total = effectiveTotal {
                        HStack {
                            Text(Money.format(cents: total.cents, currencyCode: currencyCode))
                                .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                                .privacySensitive(true)
                                .accessibilityIdentifier("scan_review_amount")
                            Spacer()
                            if let line = parse?.rawText.components(separatedBy: "\n")[safe: total.line] {
                                Text(line).font(.caption).foregroundStyle(Color.bcTextSecondary).lineLimit(1)
                            }
                        }
                        if let hint = parse?.currencyHint, !currencyCode.hasPrefix(hint), !hint.contains(currencyCode) {
                            Label(String(format: NSLocalizedString("scan.review.currency_mismatch.format", comment: ""), hint, currencyCode),
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(Color.bcWarningInk)
                        }
                    } else {
                        Text("scan.review.no_total")
                            .font(.subheadline)
                            .foregroundStyle(Color.bcTextSecondary)
                            .accessibilityIdentifier("scan_review_no_total")
                    }
                    if let candidates = parse?.candidates, candidates.count > 1 || effectiveTotal == nil, !(candidates.isEmpty) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(uniqueCandidates(candidates).enumerated()), id: \.offset) { _, c in
                                    Button {
                                        chosen = c
                                    } label: {
                                        Text(Money.format(cents: c.cents, currencyCode: currencyCode))
                                            .font(.footnote.monospacedDigit())
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Capsule().fill(c == effectiveTotal ? Color.bcAccent.opacity(0.25) : Color.bcSurface2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .accessibilityLabel(Text("scan.review.other_amounts"))
                    }
                }

                Section("scan.review.details") {
                    LabeledContent("scan.review.merchant", value: parse?.merchant ?? "—")
                    LabeledContent("scan.review.date", value: parse?.date.map { $0.formatted(date: .abbreviated, time: .omitted) }
                                   ?? NSLocalizedString("scan.review.today", comment: ""))
                }

                Section {
                    DisclosureGroup("scan.review.raw_text", isExpanded: $showRawText) {
                        Text(parse?.rawText ?? "")
                            .font(.footnote.monospaced())
                            .foregroundStyle(Color.bcTextSecondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("scan.review.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("scan.review.use") { use() }
                        .accessibilityIdentifier("scan_review_use")
                }
            }
        }
        .languageReactive()
    }

    private func uniqueCandidates(_ all: [ReceiptParser.AmountCandidate]) -> [ReceiptParser.AmountCandidate] {
        var seen = Set<Int>(); var out: [ReceiptParser.AmountCandidate] = []
        for c in all where seen.insert(c.cents).inserted { out.append(c) }
        return out.sorted { $0.cents > $1.cents }
    }

    private func use() {
        let merchant = parse?.merchant ?? ""
        let categoryName = MerchantLearningService.suggestedCategoryName(for: merchant, in: modelContext)
        let categoryUUID = categoryName.flatMap { name in
            (try? modelContext.fetch(FetchDescriptor<Category>()))?.first { $0.name == name || $0.displayName() == name }?.uuid
        }
        let prefill = AddTransactionPrefill(
            typeRaw: "expense",
            amountText: effectiveTotal.map { Money.plainDecimalString(cents: $0.cents) } ?? "",
            merchant: merchant,
            categoryUUID: categoryUUID,
            sourceUUID: nil,
            recurrence: nil,
            date: parse?.date,
            note: nil,
            origin: .receiptScan
        )
        onUse(prefill)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
