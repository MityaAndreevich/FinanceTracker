//
//  ReceiptScanDebugSeam.swift
//  FinanceTracker
//
//  DEBUG-ONLY. The photo picker and the document camera cannot be driven by
//  XCUITest, so the scan journey needs a way to hand the app an image. This
//  seam renders one IN-PROCESS from launch-argument text — real pixels, then
//  the REAL Vision recogniser and the REAL parser; nothing downstream is
//  stubbed. The whole file is inside `#if DEBUG`, every call site is inside
//  `#if DEBUG`, `ReleaseDebugAffordanceTests.debugOnlySymbols` lists the type,
//  and the commit that added it records a `strings` check of a Release build
//  for both the symbol and the argument — the 1.0.5 `--poison-amounts` lesson.
//
//    --scan-fixture-text "Corner Shop|Milk 2.49|Subtotal 2.49|Tax 0.20|Total 2.69"
//
//  `|` separates lines. Rendered in a monospaced font on white, receipt-width.
//

#if DEBUG
import UIKit

enum ReceiptScanDebugSeam {

    static let argument = "--scan-fixture-text"
    /// `--scan-quota-count N`: wipe every `receiptScan.count.*` key and set THIS
    /// month's count to N, persistently. UI tests must not use a `-key value`
    /// launch pair for this: the argument domain masks reads but the app's
    /// writes still persist into the shared container, and the NEXT test in the
    /// same simulator inherits them (the launch-seam residue class).
    static let quotaArgument = "--scan-quota-count"

    static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    /// Applied once at launch (from FinanceTrackerApp, inside #if DEBUG).
    static func applyQuotaOverrideIfRequested(defaults: UserDefaults = .standard) {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: quotaArgument), i + 1 < args.count, let n = Int(args[i + 1]) else { return }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(ReceiptScanQuota.keyPrefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.set(n, forKey: ReceiptScanQuota.monthKey(now: Date(), calendar: .current))
    }

    /// The lines the argument carries, or nil when the seam is not active.
    static var fixtureLines: [String]? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: argument), i + 1 < args.count else { return nil }
        return args[i + 1].components(separatedBy: "|")
    }

    /// A receipt-shaped image: 800 px wide, one line per row, 34 pt monospaced
    /// digits on white. Vision reads this at ~0.9+ confidence, so the journey
    /// measures the pipeline, not the fixture.
    static func renderFixture() -> UIImage? {
        guard let lines = fixtureLines else { return nil }
        return render(lines: lines)
    }

    static func render(lines: [String]) -> UIImage? {
        let width: CGFloat = 800
        let font = UIFont.monospacedSystemFont(ofSize: 34, weight: .regular)
        let lineHeight: CGFloat = 52
        let height = CGFloat(lines.count) * lineHeight + 120
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            var y: CGFloat = 60
            for line in lines {
                (line as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: attrs)
                y += lineHeight
            }
        }
    }
}
#endif
