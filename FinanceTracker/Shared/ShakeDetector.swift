//
//  ShakeDetector.swift
//  FinanceTracker
//
//  Lightweight shake-to-undo support. A tiny UIView that becomes first responder
//  and forwards `UIEvent.EventSubtype.motionShake` to a SwiftUI callback.
//
//  Swift forbids overriding `UIWindow.motionEnded` in an extension, so the
//  reliable route is an in-hierarchy responder. The host (DashboardView) mounts
//  this view ONLY while an undo window is active, so it never steals focus from
//  the Quick Add text field during normal use.
//

import SwiftUI
import UIKit

private final class ShakeDetectingView: UIView {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Grab first responder when mounted so motion events route here. The host
        // only mounts us right after an auto-save (keyboard already dismissed by
        // the submit), so this doesn't disrupt an active text field.
        if window != nil { becomeFirstResponder() }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { onShake?() }
        super.motionEnded(motion, with: event)
    }
}

private struct ShakeDetectorRepresentable: UIViewRepresentable {
    let onShake: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ShakeDetectingView()
        view.onShake = onShake
        view.isUserInteractionEnabled = false   // never intercept touches
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? ShakeDetectingView)?.onShake = onShake
    }
}

extension View {
    /// Calls `action` when the device is shaken. Apply conditionally (e.g. only
    /// while an undo window is open) so the underlying responder doesn't steal
    /// focus from text fields during normal use.
    func onShake(perform action: @escaping () -> Void) -> some View {
        background(ShakeDetectorRepresentable(onShake: action).frame(width: 0, height: 0))
    }
}
