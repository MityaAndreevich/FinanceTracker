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

@Suite("VoiceInputService locale resolution")
@MainActor
struct VoiceLocaleResolutionTests {

    private let key = "appLanguageCode"

    private func set(_ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("system value falls back to current locale (no crash)")
    func system_resolves_without_crash() {
        set("system")
        defer { clear() }
        let service = VoiceInputService()
        #expect(service.authState == .undetermined || service.authState == .deviceUnavailable)
    }

    @Test("ru code creates a Russian recognizer (no crash)")
    func russian_locale_no_crash() {
        set("ru")
        defer { clear() }
        let service = VoiceInputService()
        #expect(service.isListening == false)
    }

    @Test("en code creates an English recognizer (no crash)")
    func english_locale_no_crash() {
        set("en")
        defer { clear() }
        let service = VoiceInputService()
        #expect(service.isListening == false)
    }

    @Test("uk code creates a Ukrainian recognizer (no crash)")
    func ukrainian_locale_no_crash() {
        set("uk")
        defer { clear() }
        let service = VoiceInputService()
        #expect(service.isListening == false)
    }

    @Test("unknown language code falls back without crash")
    func unknown_code_fallback() {
        set("klingon")
        defer { clear() }
        let service = VoiceInputService()
        #expect(service.isListening == false)
    }

    @Test("empty string falls back without crash")
    func empty_string_fallback() {
        set("")
        defer { clear() }
        let service = VoiceInputService()
        #expect(service.isListening == false)
    }
}
