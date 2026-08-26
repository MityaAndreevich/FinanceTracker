//
//  PDFExportLayoutTests.swift
//  FinanceTrackerTests
//
//  COMMISSIONED RED against unmodified HEAD before the fix was written
//  (observed: 8 of 11 rows red, control green, mirror green).
//  The invariant is not "the ru_RU row says 4 000" — that is the symptom Elena
//  reported. The invariant is the cause: a formatted amount MUST fit inside the
//  amount column's rect, because `String.draw(in:withAttributes:)` word-wraps and
//  then clips to the rect, and a clipped second line is SILENT. The user sees a
//  shorter number, not a broken one.
//
//  ── THIS FILE MEASURES A MODEL, AND THE MODEL IS KNOWN TO BE OPTIMISTIC ──────
//  Everything below is `boundingRect(with:options:)` + `CTTypesetterSuggestLine`
//  `Break` — CoreText's answer about where a line COULD break. The shipping code
//  calls `String.draw(in:withAttributes:)`, the legacy NSStringDrawing path, and
//  the two DO NOT AGREE. Measured against real rendered PDFs by
//  PDFExportRenderTests (2026-08-26):
//
//    • ru_RU "−4 000,00 ₽" — the grouping separator is U+00A0 NO-BREAK SPACE, so
//      CoreText reports no break opportunity and this file predicts a mid-number
//      char-wrap at index 8, i.e. "−4 000,0". THE REAL PDF SHOWED "−4". The legacy
//      drawing path broke at the NBSP; CoreText says it cannot. Elena's report was
//      right and this model was wrong.
//    • ru_RU "−12 345,67 ₽" — same NBSP, and here the render AGREED with this
//      file: "−12 345,". So "it breaks at the NBSP" is not a rule either.
//    • en_US "−RUB 89.90" — NBSP again, and again a mid-number char-wrap:
//      "−RUB 89". Eighty-nine roubles, unreadable, on an English interface.
//    • de_DE "−1.234,56 €" — no space anywhere in the number, model and render
//      agree: char-wraps mid-number at index 8, "−1.234,5" is what is drawn.
//    • en_US "−$1,234.56" — breaks after the U+2212 minus, model and render
//      agree: the cell contains the lone character "−" and nothing else.
//
//  So this file is sometimes right and sometimes badly wrong, in the same locale,
//  on strings that differ only in magnitude — and nothing in it can tell you which
//  case you are looking at.
//
//  BINDING, 2026-08-26: of three NBSP-bearing strings measured against real PDFs,
//  ONE broke at the NBSP and TWO char-wrapped. There is no rule. THIS FILE IS AN
//  UNRELIABLE PREDICTOR IN BOTH DIRECTIONS AND MUST NEVER BE CITED AS EVIDENCE
//  ABOUT WHAT RENDERS. It stays as a cheap "the amount got wider" alarm, nothing
//  more. The guard that decides whether the PDF is correct is
//  PDFExportRenderTests, which renders the document and reads the pixels back.
//
//  ── WHAT CHANGED WHEN THE FIX LANDED, AND WHAT IT COST THIS FILE ────────────
//  The RED run above measured a hard-coded 56pt column. The fix removed that
//  literal: columns are now allocated from the content being exported. So this
//  file no longer transcribes a width — it asks `PDFExportService.tableLayout`
//  what the column would be, which is the same invariant ("the amount fits its
//  column") measured against the geometry that actually ships.
//
//  Be honest about the consequence: for ordinary amounts the allocator sizes the
//  column FROM the amount, so those rows now pass close to by construction. What
//  this file still earns is the clamp and the font-shrink path — an amount wide
//  enough to hit `maxAmountWidth` must still fit after shrinking — and a loud
//  failure if anyone reintroduces a fixed width. The real acceptance test is
//  PDFExportRenderTests.
//
//  ── WHY THIS FILE MIRRORS THE FORMATTER INSTEAD OF CALLING IT ────────────────
//  `MoneyFormatterCache.formatter(for:)` sets `f.locale = .autoupdatingCurrent`
//  and caches one formatter PER CURRENCY CODE. The locale is NOT derived from
//  the currency code. So `Money.formatSigned(cents:isPositive:currencyCode:)`
//  cannot be asked "what does this look like in ru_RU?" from a test — it answers
//  only for whatever locale the host process happens to be running.
//
//  That is not a testing inconvenience, it is a product fact worth stating: a
//  Russian user whose phone is set to English does not see "−4 000,00 ₽". They
//  see the en_US rendering of RUB. Both are measured below; they have different
//  width profiles and they fail differently.
//
//  So the corpus is measured through `mirroredFormatSigned`, a byte-for-byte
//  mirror of `Money.formatSigned` + `MoneyFormatterCache` with the locale made
//  explicit. `testMirrorMatchesProductionFormatter` pins the mirror to the real
//  thing at the host locale, so the mirror cannot drift into measuring a string
//  the app never produces.
//

import XCTest
import UIKit
import CoreText
@testable import FinanceTracker

final class PDFExportLayoutTests: XCTestCase {

    // MARK: - Geometry under test
    //
    // These were literals transcribed from PDFExportService.drawTransactionRow —
    // 56 / 120 / 260 — because at the time the service had two independent sets of
    // them and the RED run had to measure what SHIPPED. The service now derives
    // every column from the content being exported, through ONE allocator, so
    // there is nothing left to transcribe: this file asks that allocator what the
    // column would be. Re-introducing a width literal here would recreate the
    // second source that caused the defect.

    private static let rowHeightRect: CGFloat = PDFExportService.rowCellHeight

    /// The allocation the exporter would make for a one-row report containing
    /// exactly these strings.
    private static func allocation(amount: String = "", category: String = "",
                                   title: String = "", date: String = "")
        -> PDFExportService.TableLayout {
        PDFExportService.tableLayout(
            rows: [PDFExportService.RowContent(date: date, title: title,
                                               category: category, amount: amount)],
            headers: .localized()
        )
    }

    private static var rowFont: UIFont { PDFExportService.bodyFont }

    /// Longest merchant the UI will accept — AddTransactionView.swift:512
    /// (`guard merchant.count <= 200`).
    private static let merchantMaxLength = 200

    // MARK: - Corpus

    private struct Case {
        let localeID: String
        let currencyCode: String
        let cents: Int
        let isPositive: Bool
        /// The discriminating control: must fit BEFORE and AFTER the fix. If every
        /// row fails, the test cannot tell a real fix from "widen everything".
        let isControl: Bool

        init(_ localeID: String, _ currencyCode: String, _ cents: Int,
             isPositive: Bool = false, isControl: Bool = false) {
            self.localeID = localeID
            self.currencyCode = currencyCode
            self.cents = cents
            self.isPositive = isPositive
            self.isControl = isControl
        }
    }

    /// Expenses (isPositive: false) unless stated — that is Elena's case and the
    /// wider one, since the "−" prefix is added by `Money.formatSigned`.
    private static let corpus: [Case] = [
        Case("ru_RU", "RUB", 25_000),      // 250,00 ₽
        Case("ru_RU", "RUB", 40_000),      // 400,00 ₽
        Case("ru_RU", "RUB", 400_000),     // 4 000,00 ₽  ← Elena's row
        Case("ru_RU", "RUB", 1_234_567),   // 12 345,67 ₽

        Case("en_US", "USD", 25_000),      // $250.00
        Case("en_US", "USD", 123_456),     // $1,234.56
        Case("en_US", "USD", 99_999_999),  // $999,999.99

        Case("de_DE", "EUR", 123_456),     // 1.234,56 €
        Case("ja_JP", "JPY", 1_234_567),   // −¥12,346 — cents are divided by 100
                                           // for every currency, then JPY rounds away
                                           // the fraction digits

        // CONTROL — a sub-1000 USD amount. Renders correctly today.
        Case("en_US", "USD", 8_990, isControl: true),

        // The same Russian amount as seen by a Russian user on an ENGLISH phone.
        // Same data, different formatter locale, different failure.
        Case("en_US", "RUB", 40_000),
    ]

    // MARK: - The mirror

    /// Byte-for-byte mirror of `Money.formatSigned` + `MoneyFormatterCache`, with
    /// the locale lifted into a parameter. Pinned to production by
    /// `testMirrorMatchesProductionFormatter`.
    private func mirroredFormatSigned(cents: Int, isPositive: Bool,
                                      currencyCode: String, locale: Locale) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.locale = locale
        let amount = Decimal(cents) / 100
        let body = f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
        if body.hasPrefix("-") || body.hasPrefix("+") { return body }
        return (isPositive ? "+" : "−") + body
    }

    /// The mirror must produce exactly what the app produces, or every measurement
    /// below is about a string the user never sees.
    func testMirrorMatchesProductionFormatter() {
        for c in Self.corpus {
            let production = Money.formatSigned(cents: c.cents, isPositive: c.isPositive,
                                                currencyCode: c.currencyCode)
            let mirrored = mirroredFormatSigned(cents: c.cents, isPositive: c.isPositive,
                                                currencyCode: c.currencyCode,
                                                locale: .autoupdatingCurrent)
            XCTAssertEqual(mirrored, production,
                "Mirror drifted from Money.formatSigned for \(c.currencyCode) \(c.cents)")
        }
    }

    // MARK: - Measurement primitives

    private func width(_ s: String, font: UIFont) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: font]).width
    }

    /// How `String.draw(in:withAttributes:)` will actually lay this string out in a
    /// column of `width`. Answers the question the bug turns on: does the string
    /// WRAP (second line drawn below the rect, clipped away — user sees a short
    /// number) or does it have no break opportunity at all (clipped mid-glyph on a
    /// single line)?
    private struct Layout {
        let measuredWidth: CGFloat
        let fits: Bool
        let lineCount: Int
        /// Character index where CoreText would break the first line.
        let lineBreakIndex: Int
        /// Where it would break if forced to break mid-word.
        let clusterBreakIndex: Int
        /// True when the only available break is a forced mid-cluster one.
        let hasWordBreakOpportunity: Bool
        let firstLine: String
        let describeBreak: String
    }

    private func layout(_ s: String, in columnWidth: CGFloat, font: UIFont) -> Layout {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let measured = width(s, font: font)
        let fits = measured <= columnWidth

        // Line count as NSStringDrawing (and therefore .draw(in:)) would compute it.
        let bounds = (s as NSString).boundingRect(
            with: CGSize(width: columnWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        let lineCount = max(1, Int((bounds.height / font.lineHeight).rounded()))

        let attributed = NSAttributedString(string: s, attributes: attrs)
        let ts = CTTypesetterCreateWithAttributedString(attributed)
        let lineBreak = CTTypesetterSuggestLineBreak(ts, 0, Double(columnWidth))
        let clusterBreak = CTTypesetterSuggestClusterBreak(ts, 0, Double(columnWidth))

        // If the suggested LINE break is no earlier than the forced CLUSTER break,
        // CoreText found no word-break opportunity inside the width — the break it
        // returns is a forced one, mid-word.
        let hasWordBreak = fits ? false : (lineBreak < clusterBreak)

        let cut = min(max(lineBreak, 0), s.count)
        let firstLine = String(s.prefix(cut))

        // Three distinct overflow behaviours, and they are NOT interchangeable:
        //   • a real word-break opportunity  → wraps there (can strand a lone "−")
        //   • no word break, but >1 line     → NSStringDrawing char-wraps MID-NUMBER
        //   • no word break, exactly 1 line  → truly clipped mid-glyph
        // In all three the overflow is drawn outside the 16pt rect and clipped away.
        let describe: String
        if fits {
            describe = "— (fits)"
        } else if hasWordBreak {
            describe = "word break @\(lineBreak) → line 1 = \"\(firstLine)\""
        } else if lineCount > 1 {
            describe = "no word break → char-wraps mid-number @\(lineBreak)"
        } else {
            describe = "no break at all → clipped mid-glyph"
        }

        return Layout(measuredWidth: measured, fits: fits, lineCount: lineCount,
                      lineBreakIndex: lineBreak, clusterBreakIndex: clusterBreak,
                      hasWordBreakOpportunity: hasWordBreak, firstLine: firstLine,
                      describeBreak: describe)
    }

    // MARK: - THE GUARD

    /// A formatted monetary amount must fit inside the amount column.
    ///
    /// This is the cause, not the symptom. It fails today for every locale whose
    /// amounts carry a grouping separator, and it keeps failing for any future
    /// change that makes an amount wider than its column — including a currency
    /// or locale nobody has thought about yet.
    func testFormattedAmountFitsAmountColumn() {
        var table: [String] = []
        var failures: [String] = []

        table.append("")
        table.append("AMOUNT COLUMN — width allocated per row by PDFExportService.tableLayout, rect height \(Self.rowHeightRect)pt")
        table.append(String(repeating: "─", count: 118))
        table.append(String(format: "%-8@ %-5@ %11@  %-20@ %8@  %-5@ %6@  %@",
                            "locale" as NSString, "cur" as NSString, "cents" as NSString,
                            "formatted" as NSString, "width" as NSString,
                            "fits?" as NSString, "lines" as NSString,
                            "break opportunity" as NSString))
        table.append(String(repeating: "─", count: 118))

        for c in Self.corpus {
            let locale = Locale(identifier: c.localeID)
            let s = mirroredFormatSigned(cents: c.cents, isPositive: c.isPositive,
                                         currencyCode: c.currencyCode, locale: locale)
            // The column this amount would actually get, from the shipping allocator.
            let allocated = Self.allocation(amount: s)
            let columnWidth = allocated.amountWidth
            let font = allocated.amountFont
            let l = layout(s, in: columnWidth, font: font)

            table.append(String(format: "%-8@ %-5@ %11@  %-20@ %8@  %-5@ %6@  %@",
                                c.localeID as NSString,
                                c.currencyCode as NSString,
                                "\(c.cents)@\(Int(columnWidth))pt" as NSString,
                                (s + (c.isControl ? " ◂CTRL" : "")) as NSString,
                                String(format: "%.2f", l.measuredWidth) as NSString,
                                (l.fits ? "YES" : "NO") as NSString,
                                "\(l.lineCount)" as NSString,
                                l.describeBreak as NSString))

            if !l.fits {
                let visible = l.lineCount > 1
                    ? "user sees \"\(l.firstLine)\" — remaining line(s) clipped away"
                    : "user sees the string clipped mid-glyph at \(columnWidth)pt"
                failures.append("  \(c.localeID)/\(c.currencyCode) \(c.cents) → \"\(s)\" is \(String(format: "%.2f", l.measuredWidth))pt > \(columnWidth)pt; \(visible)")
            }
        }

        table.append(String(repeating: "─", count: 118))
        print(table.joined(separator: "\n"))

        XCTAssertTrue(failures.isEmpty,
            "\(failures.count) of \(Self.corpus.count) formatted amounts do not fit the "
            + "amount column the exporter allocates for them. String.draw(in:) word-wraps and clips to the "
            + "rect, so each of these renders as a SHORTER, PLAUSIBLE, WRONG number with no "
            + "visual cue:\n" + failures.joined(separator: "\n"))
    }

    /// The discriminating control, asserted on its own so it is visible in the
    /// result bundle as a separate PASS. If this ever goes red alongside the guard,
    /// the guard has stopped discriminating and is merely measuring "everything is
    /// too narrow".
    func testControlSmallAmountFitsAndMustKeepFitting() {
        let c = Self.corpus.first { $0.isControl }!
        let s = mirroredFormatSigned(cents: c.cents, isPositive: c.isPositive,
                                     currencyCode: c.currencyCode,
                                     locale: Locale(identifier: c.localeID))
        let allocated = Self.allocation(amount: s)
        let l = layout(s, in: allocated.amountWidth, font: allocated.amountFont)
        XCTAssertTrue(l.fits,
            "CONTROL BROKEN: \"\(s)\" measures \(l.measuredWidth)pt and no longer fits "
            + "the \(allocated.amountWidth)pt allocated to it. This row is supposed to render correctly both "
            + "before and after the fix; if it fails, the corpus can no longer distinguish "
            + "a real fix from widening every column.")
    }

    // MARK: - Text columns (Step 1 measurement — REPORTER, see note)
    //
    // NOT a guard, and deliberately not asserted as one. Per the fix's design
    // constraints, text columns are ALLOWED to truncate (visibly, with an
    // ellipsis); only the money column may not. So there is no true/false
    // invariant here to pin — what matters is that overflow becomes VISIBLE.
    // This test prints the measurements that decide whether that is happening and
    // asserts only that the measurement itself ran.

    func testReportTextColumnMeasurements() throws {
        let font = Self.rowFont
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FinanceTrackerTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("FinanceTracker")

        // The 13 seeded categories (SeedService.defaultCategorySpecs) plus the nil
        // fallback, which also renders into this column via displayNameOrFallback().
        let categoryKeys = [
            "category.food_drink", "category.transport", "category.housing",
            "category.shopping", "category.entertainment", "category.other",
            "category.income", "category.health", "category.subscriptions",
            "category.coffee", "category.travel", "category.personal_care",
            "category.utilities", "category.uncategorized"
        ]
        let lprojs = ["en", "ru", "es", "pt-BR", "uk"]

        var out: [String] = []
        out.append("")
        out.append("CATEGORY COLUMN — width allocated per name by PDFExportService.tableLayout")
        out.append(String(repeating: "─", count: 100))
        out.append(String(format: "%-7@ %-26@ %-24@ %8@  %-5@  %@",
                          "lproj" as NSString, "widest seeded key" as NSString,
                          "value" as NSString, "width" as NSString,
                          "fits?" as NSString, "break opportunity" as NSString))
        out.append(String(repeating: "─", count: 100))

        var measuredAnything = false

        for lproj in lprojs {
            let url = repoRoot.appendingPathComponent("\(lproj).lproj/Localizable.strings")
            let content = try String(contentsOf: url, encoding: .utf8)
            let table = Self.parseStrings(content)

            var widest: (key: String, value: String, w: CGFloat)?
            for key in categoryKeys {
                guard let value = table[key] else { continue }
                let w = width(value, font: font)
                if widest == nil || w > widest!.w { widest = (key, value, w) }
            }
            guard let win = widest else { continue }
            measuredAnything = true

            let allocated = Self.allocation(category: win.value)
            let l = layout(win.value, in: allocated.categoryWidth, font: font)
            out.append(String(format: "%-7@ %-26@ %-24@ %8@  %-5@  %@",
                              lproj as NSString, win.key as NSString, win.value as NSString,
                              String(format: "%.2f/%.0f", win.w, allocated.categoryWidth) as NSString,
                              (l.fits ? "YES" : "NO") as NSString,
                              l.describeBreak as NSString))
        }

        // Longest merchant a user can actually enter (AddTransactionView caps at 200).
        out.append("")
        out.append("TITLE COLUMN — width allocated by PDFExportService.tableLayout (the remainder)")
        out.append(String(repeating: "─", count: 100))
        let worstMerchant = String(repeating: "W", count: Self.merchantMaxLength)
        let realisticMerchant = String(repeating: "Trader Joe's Market ", count: 10)
            .trimmingCharacters(in: .whitespaces)
        for (label, s) in [("200×\"W\" (max width)", worstMerchant),
                           ("200-char realistic", realisticMerchant)] {
            let allocated = Self.allocation(title: s)
            let l = layout(s, in: allocated.titleWidth, font: font)
            out.append(String(format: "%-22@ len=%3@  %9@  fits=%-4@  lines=%2@  %@",
                              label as NSString, "\(s.count)" as NSString,
                              String(format: "%.2f", l.measuredWidth) as NSString,
                              (l.fits ? "YES" : "NO") as NSString,
                              "\(l.lineCount)" as NSString,
                              (l.fits ? "" : "visible: \"\(l.firstLine)\"") as NSString))
        }
        out.append(String(repeating: "─", count: 100))
        print(out.joined(separator: "\n"))

        XCTAssertTrue(measuredAnything,
            "Measured zero category names — the .lproj path is wrong, so this reporter "
            + "reported nothing while looking like it worked.")
    }

    /// Minimal `.strings` parser — key/value pairs on one line.
    private static func parseStrings(_ content: String) -> [String: String] {
        var out: [String: String] = [:]
        let pattern = #"^\s*"([^"]+)"\s*=\s*"(.*)"\s*;\s*$"#
        let re = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let ns = content as NSString
        re.enumerateMatches(in: content, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m, m.numberOfRanges == 3 else { return }
            out[ns.substring(with: m.range(at: 1))] = ns.substring(with: m.range(at: 2))
        }
        return out
    }
}
