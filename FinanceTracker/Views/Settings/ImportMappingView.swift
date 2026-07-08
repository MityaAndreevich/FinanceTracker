//
//  ImportMappingView.swift
//  FinanceTracker
//
//  Tier-2 flexible-import mapping sheet. The user picks a source preset (or maps
//  manually) and confirms which of their columns feed our date / amount / sign /
//  category / merchant / note / account / currency fields — against a live
//  preview of real values, so a wrong mapping is obvious before it corrupts data.
//
//  Deliberately native (insetGrouped Form) to sit inside Settings ▸ Data. The one
//  signature element is the horizontally-scrolling preview table whose mapped
//  columns tint to the accent, tying the abstract field pickers to real cells.
//

import SwiftUI

// MARK: - Draft (editable, view-local) mapping

private enum AmountShapeKind: String, CaseIterable, Identifiable {
    case signed, amountAndType, debitCredit
    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .signed:        return "import.map.amount.shape.signed"
        case .amountAndType: return "import.map.amount.shape.amount_type"
        case .debitCredit:   return "import.map.amount.shape.debit_credit"
        }
    }
}

/// Mutable working copy the sheet edits, resolved into a `ColumnMapping` on import.
private struct ImportMappingDraft {
    var dateCol: Int?
    var dateOrder: DateOrder = .auto
    var decimal: CSVDecimalStyle = .auto
    var amountShape: AmountShapeKind = .signed
    var amountCol: Int?
    var typeCol: Int?
    var debitCol: Int?
    var creditCol: Int?
    var categoryCol: Int?
    var merchantCol: Int?
    var noteCol: Int?
    var accountCol: Int?
    var currencyCol: Int?

    /// Resolve into a `ColumnMapping`, or nil while required fields are unmapped.
    func build() -> ColumnMapping? {
        guard let date = dateCol else { return nil }
        let amount: AmountMapping
        switch amountShape {
        case .signed:
            guard let a = amountCol else { return nil }
            amount = .signed(a)
        case .amountAndType:
            guard let a = amountCol, let t = typeCol else { return nil }
            amount = .unsignedWithType(amount: a, type: t)
        case .debitCredit:
            guard let d = debitCol, let c = creditCol else { return nil }
            amount = .debitCredit(debit: d, credit: c)
        }
        return ColumnMapping(
            date: date, dateOrder: dateOrder, decimal: decimal, amount: amount,
            category: categoryCol, merchant: merchantCol, note: noteCol,
            account: accountCol, currency: currencyCol)
    }

    /// Every column index currently in use — drives the preview highlight.
    var mappedColumns: Set<Int> {
        var s = Set<Int>()
        [dateCol, amountCol, typeCol, debitCol, creditCol,
         categoryCol, merchantCol, noteCol, accountCol, currencyCol]
            .compactMap { $0 }.forEach { s.insert($0) }
        return s
    }

    static func from(_ m: ColumnMapping) -> ImportMappingDraft {
        var d = ImportMappingDraft()
        d.dateCol = m.date
        d.dateOrder = m.dateOrder
        d.decimal = m.decimal
        switch m.amount {
        case .signed(let a):
            d.amountShape = .signed; d.amountCol = a
        case .unsignedWithType(let a, let t):
            d.amountShape = .amountAndType; d.amountCol = a; d.typeCol = t
        case .debitCredit(let de, let cr):
            d.amountShape = .debitCredit; d.debitCol = de; d.creditCol = cr
        }
        d.categoryCol = m.category
        d.merchantCol = m.merchant
        d.noteCol = m.note
        d.accountCol = m.account
        d.currencyCol = m.currency
        return d
    }
}

// MARK: - Sheet

struct ImportMappingView: View {
    let preview: CSVImportService.CSVPreview
    let onCancel: () -> Void
    let onImport: (ColumnMapping) -> Void

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"
    @State private var preset: SourcePreset
    @State private var draft: ImportMappingDraft

    init(preview: CSVImportService.CSVPreview,
         initialPreset: SourcePreset,
         onCancel: @escaping () -> Void,
         onImport: @escaping (ColumnMapping) -> Void) {
        self.preview = preview
        self.onCancel = onCancel
        self.onImport = onImport
        _preset = State(initialValue: initialPreset)
        if let m = initialPreset.defaultMapping(header: preview.header) {
            _draft = State(initialValue: .from(m))
        } else {
            _draft = State(initialValue: ImportMappingDraft())
        }
    }

    private var columnCount: Int { preview.header.count }

    /// Human label for a column: its header, or "Column N" when the header is blank.
    private func columnLabel(_ index: Int) -> String {
        let raw = index < preview.header.count
            ? preview.header[index].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        if !raw.isEmpty { return raw }
        return String(format: NSLocalizedString("import.map.column.format", comment: ""), index + 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                presetSection
                previewSection
                dateSection
                amountSection
                optionalSection
            }
            .navigationTitle("import.map.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("import.map.action.import") {
                        if let mapping = draft.build(), !dateOrderUnresolved, !decimalUnresolved { onImport(mapping) }
                    }
                    .disabled(draft.build() == nil || dateOrderUnresolved || decimalUnresolved)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Preset

    private var presetSection: some View {
        Section {
            Picker("import.map.preset", selection: $preset) {
                Text("import.map.preset.mint").tag(SourcePreset.mint)
                Text("import.map.preset.ynab").tag(SourcePreset.ynab)
                Text("import.map.preset.monarch").tag(SourcePreset.monarch)
                Text("import.map.preset.generic").tag(SourcePreset.genericBank)
                Text("import.map.preset.custom").tag(SourcePreset.custom)
            }
            .onChange(of: preset) { _, newValue in
                if let m = newValue.defaultMapping(header: preview.header) {
                    draft = .from(m)
                }
                // Custom: keep the user's current mapping to tweak by hand.
            }
        } footer: {
            Text("import.map.preset.footer")
        }
    }

    // MARK: Preview table (signature element)

    private var previewSection: some View {
        Section("import.map.preview") {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    previewRow(cells: (0..<columnCount).map { columnLabel($0) }, isHeader: true)
                    ForEach(Array(preview.rows.prefix(6).enumerated()), id: \.offset) { _, row in
                        previewRow(cells: (0..<columnCount).map { c in
                            c < row.count ? row[c] : ""
                        }, isHeader: false)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private func previewRow(cells: [String], isHeader: Bool) -> some View {
        let mapped = draft.mappedColumns
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, value in
                Text(value.isEmpty ? "—" : value)
                    .font(isHeader ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(isHeader ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 92, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(mapped.contains(index) ? Color.accentColor.opacity(isHeader ? 0.20 : 0.08) : .clear)
            }
        }
        .overlay(alignment: .bottom) {
            if isHeader { Divider() }
        }
    }

    // MARK: Date

    /// Values of the currently-mapped date column across the preview rows.
    private var dateSamples: [String] {
        guard let col = draft.dateCol else { return [] }
        return preview.rows.compactMap { col < $0.count ? $0[col] : nil }
    }

    private var detectedDateOrder: DetectedDateOrder {
        ImportDate.classifyColumn(samples: dateSamples)
    }

    /// The order is unconfirmed: the column is genuinely ambiguous and the user has
    /// left it on Auto. Import is blocked here — we never guess day/month silently.
    private var dateOrderUnresolved: Bool {
        draft.dateOrder == .auto && detectedDateOrder == .ambiguous
    }

    /// Auto-apply a concrete order when the column disambiguates itself, but only
    /// while the user hasn't declared one (a preset order like Mint's MDY wins).
    private func syncDetectedDateOrder() {
        guard draft.dateOrder == .auto else { return }
        switch detectedDateOrder {
        case .iso: draft.dateOrder = .iso
        case .resolved(let o): draft.dateOrder = o
        case .ambiguous: break  // leave on Auto → blocks import until the user picks
        }
    }

    private var dateSection: some View {
        Section {
            columnPicker("import.map.field.date", selection: $draft.dateCol, includeNone: false)
                .onChange(of: draft.dateCol) { _, _ in syncDetectedDateOrder() }

            Picker("import.map.date_format", selection: $draft.dateOrder) {
                Text("import.map.date_format.auto").tag(DateOrder.auto)
                Text("import.map.date_format.mdy").tag(DateOrder.mdy)
                Text("import.map.date_format.dmy").tag(DateOrder.dmy)
                Text("import.map.date_format.iso").tag(DateOrder.iso)
            }

            dateInterpretationRow
        } header: {
            Text("import.map.section.date")
        }
        .onAppear { syncDetectedDateOrder() }
    }

    /// Surfaces how the chosen format actually reads the file's first date — or a
    /// prominent warning when the order is still ambiguous — so a wrong mapping is
    /// visible before it can transpose day and month.
    @ViewBuilder
    private var dateInterpretationRow: some View {
        if dateOrderUnresolved {
            Label("import.map.date.ambiguous", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        } else if let raw = dateSamples.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let date = ImportDate.parse(trimmed, order: draft.dateOrder) {
                Text(String(format: NSLocalizedString("import.map.date.reads.format", comment: ""),
                            trimmed, Self.previewDateFormatter.string(from: date)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(format: NSLocalizedString("import.map.date.unreadable.format", comment: ""), trimmed))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private static let previewDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: Amount + sign

    private var amountSection: some View {
        Section {
            Picker("import.map.amount.shape", selection: $draft.amountShape) {
                ForEach(AmountShapeKind.allCases) { shape in
                    Text(shape.titleKey).tag(shape)
                }
            }

            switch draft.amountShape {
            case .signed:
                columnPicker("import.map.field.amount", selection: $draft.amountCol, includeNone: false)
            case .amountAndType:
                columnPicker("import.map.field.amount", selection: $draft.amountCol, includeNone: false)
                columnPicker("import.map.field.type", selection: $draft.typeCol, includeNone: false)
            case .debitCredit:
                columnPicker("import.map.field.debit", selection: $draft.debitCol, includeNone: false)
                columnPicker("import.map.field.credit", selection: $draft.creditCol, includeNone: false)
            }

            Picker("import.map.decimal", selection: $draft.decimal) {
                Text("import.map.decimal.auto").tag(CSVDecimalStyle.auto)
                Text("import.map.decimal.period").tag(CSVDecimalStyle.period)
                Text("import.map.decimal.comma").tag(CSVDecimalStyle.comma)
            }

            amountInterpretationRow
        } header: {
            Text("import.map.section.amount")
        } footer: {
            Text("import.map.section.amount.footer")
        }
        .onAppear { syncDetectedDecimal() }
        .onChange(of: amountDetectionColumns) { _, _ in syncDetectedDecimal() }
    }

    // The amount magnitude column(s) feeding decimal detection.
    private var amountDetectionColumns: [Int] {
        switch draft.amountShape {
        case .signed, .amountAndType: return [draft.amountCol].compactMap { $0 }
        case .debitCredit:            return [draft.debitCol, draft.creditCol].compactMap { $0 }
        }
    }

    private var amountSamples: [String] {
        preview.rows.flatMap { row in amountDetectionColumns.compactMap { c in c < row.count ? row[c] : nil } }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var detectedDecimal: DetectedDecimalStyle {
        ImportDecimal.classifyColumn(samples: amountSamples)
    }

    /// The convention is unconfirmed: the sample can't resolve period vs comma and
    /// the user left it on Auto → block import (mirrors `dateOrderUnresolved`).
    private var decimalUnresolved: Bool {
        draft.decimal == .auto && detectedDecimal == .ambiguous
    }

    /// Auto-apply the detected convention when the sample resolves it, but only
    /// while the user hasn't declared one (a preset convention wins).
    private func syncDetectedDecimal() {
        guard draft.decimal == .auto, case .resolved(let style) = detectedDecimal else { return }
        draft.decimal = style
    }

    /// The concrete style used to render the amount preview (resolving Auto).
    private var effectiveDecimalStyle: CSVDecimalStyle {
        if draft.decimal != .auto { return draft.decimal }
        if case .resolved(let s) = detectedDecimal { return s }
        return .period
    }

    /// Shows how the chosen convention reads the file's first amount — or a warning
    /// while it is still ambiguous — so a wrong convention is visible before it can
    /// misread every value (e.g. "1,23 → 1.23").
    @ViewBuilder
    private var amountInterpretationRow: some View {
        if decimalUnresolved {
            Label("import.map.decimal.ambiguous", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        } else if let raw = amountSamples.first {
            if let parsed = ImportAmount.parse(raw, decimal: effectiveDecimalStyle) {
                let cents = parsed.isNegative ? -parsed.cents : parsed.cents
                Text(String(format: NSLocalizedString("import.map.amount.reads.format", comment: ""),
                            raw, Money.format(cents: cents, currencyCode: defaultCurrencyCode)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(format: NSLocalizedString("import.map.amount.unreadable.format", comment: ""), raw))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Optional fields

    private var optionalSection: some View {
        Section {
            columnPicker("import.map.field.category", selection: $draft.categoryCol, includeNone: true)
            columnPicker("import.map.field.merchant", selection: $draft.merchantCol, includeNone: true)
            columnPicker("import.map.field.note", selection: $draft.noteCol, includeNone: true)
            columnPicker("import.map.field.account", selection: $draft.accountCol, includeNone: true)
            columnPicker("import.map.field.currency", selection: $draft.currencyCol, includeNone: true)
        } header: {
            Text("import.map.section.optional")
        } footer: {
            Text("import.map.section.optional.footer")
        }
    }

    // MARK: Reusable column picker

    private func columnPicker(_ titleKey: LocalizedStringKey, selection: Binding<Int?>, includeNone: Bool) -> some View {
        Picker(titleKey, selection: selection) {
            if includeNone {
                Text("import.map.column.none").tag(Int?.none)
            }
            ForEach(0..<columnCount, id: \.self) { index in
                Text(columnLabel(index)).tag(Int?.some(index))
            }
        }
    }
}
