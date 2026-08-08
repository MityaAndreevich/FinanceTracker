//
//  AuthGateView.swift
//  FinanceTracker
//
//  Security: T-1, T-15 — biometric/passcode lock on app open.
//  Uses LAPolicy.deviceOwnerAuthentication so Face ID / Touch ID failures
//  automatically fall back to the device passcode (Apple default).
//

import SwiftUI
import LocalAuthentication

// MARK: - Require-auth mode

enum RequireAuthMode: String, CaseIterable {
    case always   = "always"
    case after5min = "after_5min"
    case never    = "never"
}

// MARK: - AuthGateView

struct AuthGateView: View {
    @AppStorage("requireAuthMode") private var requireAuthMode: RequireAuthMode = .never
    @Environment(\.scenePhase) private var scenePhase

    @State private var isAuthenticated: Bool
    @State private var lastAuthTime: Date? = nil
    @State private var lastBackground: Date? = nil

    init() {
        // Read mode synchronously so we can set the correct initial state without a visible flash.
        // Default is .never — users must explicitly enable App Lock in Settings.
        let raw = UserDefaults.standard.string(forKey: "requireAuthMode") ?? "never"
        let mode = RequireAuthMode(rawValue: raw) ?? .never
        #if DEBUG
        // Screenshot frame #6 captures the locked state — start locked and skip
        // the system biometric prompt (which the simulator can't satisfy headlessly).
        if ScreenshotMode.requestedScreen == .lock {
            _isAuthenticated = State(initialValue: false)
            return
        }
        #endif
        _isAuthenticated = State(initialValue: mode == .never)
    }

    var body: some View {
        ZStack {
            ContentView()
                .opacity(isAuthenticated ? 1 : 0)

            if !isAuthenticated {
                lockedView
                    .transition(.opacity)
            }
        }
        .task {
            #if DEBUG
            // Lock-screen screenshot: stay locked, don't raise the system prompt.
            if ScreenshotMode.requestedScreen == .lock { return }
            #endif
            // Trigger initial auth if not already unlocked.
            if !isAuthenticated {
                await authenticate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                #if DEBUG
                // Lock-screen screenshot: keep locked, never raise the system prompt.
                if ScreenshotMode.requestedScreen == .lock { isAuthenticated = false; break }
                #endif
                applyLockPolicy()
                if !isAuthenticated {
                    Task { await authenticate() }
                }
            case .background:
                lastBackground = Date()
            default:
                break
            }
        }
    }

    // MARK: - Locked screen

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("auth.required.title")
                .font(.title2)
                .fontWeight(.semibold)

            Text("auth.required.message")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await authenticate() }
            } label: {
                Text("auth.retry")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Auth logic

    /// Lock the app if the current auth mode requires it.
    private func applyLockPolicy() {
        switch requireAuthMode {
        case .never:
            isAuthenticated = true
        case .always:
            isAuthenticated = false
        case .after5min:
            guard let last = lastAuthTime, Date().timeIntervalSince(last) < 300 else {
                isAuthenticated = false
                return
            }
            // Still within 5-minute window — keep unlocked.
        }
    }

    /// Show the system biometric / passcode sheet and update state on success.
    @MainActor
    private func authenticate() async {
        let ctx = LAContext()
        var policyError: NSError?

        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            // Device has no passcode configured — unlock automatically.
            isAuthenticated = true
            lastAuthTime = Date()
            return
        }

        let reason = String(localized: "auth.required.message", bundle: LocalizedBundle.shared.bundle)
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok {
                isAuthenticated = true
                lastAuthTime = Date()
            }
        } catch {
            // User cancelled or failed — stay locked; retry button visible.
        }
    }
}
