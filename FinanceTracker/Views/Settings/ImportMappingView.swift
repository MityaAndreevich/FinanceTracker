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
    var decimal: CSVDecimalStyle = .period
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
                        if let mapping = draft.build() { onImport(mapping) }
                    }
                    .disabled(draft.build() == nil)
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

    private var dateSection: some View {
        Section("import.map.section.date") {
            columnPicker("import.map.field.date", selection: $draft.dateCol, includeNone: false)
            Picker("import.map.date_format", selection: $draft.dateOrder) {
                Text("import.map.date_format.auto").tag(DateOrder.auto)
                Text("import.map.date_format.mdy").tag(DateOrder.mdy)
                Text("import.map.date_format.dmy").tag(DateOrder.dmy)
                Text("import.map.date_format.iso").tag(DateOrder.iso)
            }
        }
    }

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
                Text("import.map.decimal.period").tag(CSVDecimalStyle.period)
                Text("import.map.decimal.comma").tag(CSVDecimalStyle.comma)
            }
        } header: {
            Text("import.map.section.amount")
        } footer: {
            Text("import.map.section.amount.footer")
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
