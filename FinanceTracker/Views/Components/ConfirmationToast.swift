//
//  ConfirmationToast.swift
//  FinanceTracker
//
//  Lightweight, self-contained confirmation toast for "added" feedback (Bug 9).
//  Categories/Sources already refresh immediately via @Query — the toast just makes
//  the otherwise-silent add visible, removing the "did it work? do I restart?" doubt.
//
//  Deliberately standalone (no DesignSystem coupling): a tinted capsule that slides
//  in from the bottom, fires a light haptic, and auto-dismisses after a short delay.
//

import SwiftUI

/// Visual severity of a confirmation toast. The Dashboard reuses this one toast for
/// both the "Saved — tap to edit" success and the "Couldn't save" failure; the style
/// must follow the actual result, not be hardcoded to success (the toast previously
/// rendered a save FAILURE as a green checkmark). `.error` matches the coral/warning
/// look the "+" (Quick Entry) sheet's error banner uses, so both paths agree.
enum ToastStyle {
    case success
    case error

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    var background: Color {
        switch self {
        case .success: return .accentColor
        case .error:   return .bcDanger
        }
    }

    var haptic: SensoryFeedback {
        switch self {
        case .success: return .success
        case .error:   return .warning
        }
    }
}

/// Drives a single transient toast message. Assigning a non-nil `message` shows the
/// toast (and triggers a haptic matching `style` via `.sensoryFeedback`); it clears
/// itself after `duration`.
struct ConfirmationToastModifier: ViewModifier {
    @Binding var message: LocalizedStringKey?
    var duration: TimeInterval = 2.0
    /// Severity styling. Defaults to `.success` so existing success-only callers are
    /// unchanged; the Dashboard passes `.error` on the save-failure path.
    var style: ToastStyle = .success
    /// Optional tap handler. When set, the toast becomes a button (e.g. "Saved —
    /// tap to edit", Bug 12 Q1-C) and dismisses itself after the action runs.
    var onTap: (() -> Void)? = nil

    @State private var dismissTask: Task<Void, Never>? = nil

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    toastContainer(message)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message != nil)
            .sensoryFeedback(style.haptic, trigger: message != nil) { _, new in new }
            .onChange(of: message != nil) { _, isShowing in
                dismissTask?.cancel()
                guard isShowing else { return }
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    message = nil
                }
            }
    }

    @ViewBuilder
    private func toastContainer(_ message: LocalizedStringKey) -> some View {
        if let onTap {
            Button {
                onTap()
                self.message = nil
            } label: {
                toast(message)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        } else {
            toast(message)
        }
    }

    private func toast(_ message: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: style.iconName)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(style.background, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Shows a transient confirmation toast at the bottom of the view while `message`
    /// is non-nil. The toast auto-dismisses and fires a light success haptic. When
    /// `onTap` is provided the toast is tappable (and runs the action on tap).
    func confirmationToast(
        _ message: Binding<LocalizedStringKey?>,
        duration: TimeInterval = 2.0,
        style: ToastStyle = .success,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(ConfirmationToastModifier(message: message, duration: duration, style: style, onTap: onTap))
    }
}
