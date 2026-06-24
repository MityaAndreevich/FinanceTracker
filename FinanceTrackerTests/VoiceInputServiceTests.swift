import Foundation
import Testing
@testable import FinanceTracker

// Speech recognition is hard to exercise end-to-end in CI (it needs real audio +
// granted permissions). These tests cover the deterministic state-transition
// surface only: initial state, locale-based availability, and stop() idempotency.

@Suite("VoiceInputService")
@MainActor
struct VoiceInputServiceTests {

    @Test("Fresh service reports undetermined auth state")
    func initialAuthState_isUndetermined() {
        let service = VoiceInputService(locale: Locale(identifier: "en-US"))
        #expect(service.authState == .undetermined)
        #expect(service.isListening == false)
        #expect(service.transcript.isEmpty)
    }

    @Test("isAvailable is false when the locale is unsupported")
    func isAvailable_falseWhenLocaleNotSupported() {
        // "xx" is not a real recognizer locale → SFSpeechRecognizer(locale:) is nil.
        let service = VoiceInputService(locale: Locale(identifier: "xx"))
        #expect(service.isAvailable == false)
    }

    @Test("stop() before start() is a safe no-op")
    func stop_whenNotListening_isNoOp() {
        let service = VoiceInputService(locale: Locale(identifier: "en-US"))
        service.stop()   // must not crash
        #expect(service.isListening == false)
    }

    @Test("requestAuthorizationIfNeeded returns deviceUnavailable for unsupported locale")
    func requestAuthorization_deviceUnavailableForUnsupportedLocale() async {
        let service = VoiceInputService(locale: Locale(identifier: "xx"))
        let state = await service.requestAuthorizationIfNeeded()
        #expect(state == .deviceUnavailable)
        #expect(service.authState == .deviceUnavailable)
    }
}
