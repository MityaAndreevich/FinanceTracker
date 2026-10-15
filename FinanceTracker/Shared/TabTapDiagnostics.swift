//
//  TabTapDiagnostics.swift
//  FinanceTracker
//
//  DEBUG-only, and inert unless launched with `--d33-tap-diagnostics`.
//
//  D33 (2026-10-14): in every residual UI red a tab-bar tap was not acted on.
//  The app sat on a populated Dashboard, `Dashboard` still Selected, nothing
//  covering it. This logs enough to say WHERE the tap stopped:
//
//    (a) every touch-began that reaches ANY window of this app: timestamp,
//        location, the window, and the class of `window.hitTest(location)`
//        with its first two superviews. No log line at the test's tap time
//        means the touch never reached the app.
//    (b) every write to ContentView's tab selection: timestamp, old → new, and
//        the call site, including writes that put the selection back.
//
//  The test logs its side (tap time, frame, isHittable, match count) under the
//  subsystem `com.dmitrylogachev.budgetcrab.uitests`, category D33TabTap. Read
//  both in one timeline:
//
//      xcrun simctl spawn <udid> log show --style compact \
//        --predicate 'category == "D33TabTap"' --last 2h
//
//  PRIVACY: on-device os_log only, no network. Nothing logged here is user
//  data: view class names, coordinates, tab indices and source locations. No
//  amounts, names or labels.
//

#if DEBUG
import UIKit
import os

enum TabTapDiagnostics {
    static let launchArgument = "--d33-tap-diagnostics"
    static let isEnabled = CommandLine.arguments.contains(launchArgument)
    static let log = Logger(subsystem: "com.dmitrylogachev.budgetcrab", category: "D33TabTap")

    private static var installed = false

    /// Exchanges `UIWindow.sendEvent(_:)` with a logging pass-through. Every
    /// window of the app routes its events through that method, so one hook
    /// covers the main window, sheets and alerts alike.
    static func installIfRequested() {
        guard isEnabled, !installed else { return }
        installed = true
        guard let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let logging = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.d33_sendEvent(_:))) else {
            log.error("install FAILED: UIWindow.sendEvent not found; touch logging is OFF")
            return
        }
        method_exchangeImplementations(original, logging)
        log.notice("installed pid=\(getpid(), privacy: .public) t=\(stamp(), privacy: .public)")
    }

    static func observe(_ event: UIEvent, in window: UIWindow) {
        guard event.type == .touches, let touches = event.allTouches else { return }
        for touch in touches where touch.phase == .began {
            let p = touch.location(in: window)
            let hit = window.hitTest(p, with: event)
            log.notice("""
                touch-began t=\(stamp(), privacy: .public) \
                loc=(\(Int(p.x), privacy: .public),\(Int(p.y), privacy: .public)) \
                window=\(String(describing: type(of: window)), privacy: .public) \
                key=\(window.isKeyWindow, privacy: .public) \
                level=\(Int(window.windowLevel.rawValue), privacy: .public) \
                hitTest=\(chain(hit), privacy: .public) \
                touch.view=\(chain(touch.view), privacy: .public)
                """)
        }
    }

    static func selectionWrite(old: Int, new: Int, site: String) {
        guard isEnabled else { return }
        log.notice("selection-write t=\(stamp(), privacy: .public) \(old, privacy: .public)→\(new, privacy: .public) at \(site, privacy: .public)")
    }

    static func selectionChanged(old: Int, new: Int) {
        guard isEnabled else { return }
        log.notice("selection-onChange t=\(stamp(), privacy: .public) \(old, privacy: .public)→\(new, privacy: .public)")
    }

    /// Wall clock, so the app's lines line up with the test runner's.
    private static func stamp() -> String {
        String(format: "%.3f", Date().timeIntervalSince1970)
    }

    /// "Class < Superclass-view < Superclass-view": the hit view and two parents.
    private static func chain(_ view: UIView?) -> String {
        guard let view else { return "nil" }
        var names = [String(describing: type(of: view))]
        var parent = view.superview
        while let p = parent, names.count < 3 {
            names.append(String(describing: type(of: p)))
            parent = p.superview
        }
        return names.joined(separator: " < ")
    }
}

extension UIWindow {
    /// After the exchange this name points at UIKit's original implementation,
    /// so the inner call forwards the event unchanged.
    @objc func d33_sendEvent(_ event: UIEvent) {
        TabTapDiagnostics.observe(event, in: self)
        d33_sendEvent(event)
    }
}
#endif
