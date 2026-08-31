# DEFECT: VoiceInputService teardown aborts the process (AVAudioEngine dispose, RPC timeout)

**Status:** open, release hold. Not fixed, not touched.
**Found:** 2026-08-26, while establishing why a full test run executed 563 of 1084 tests.
**Severity input:** this is a process `abort()`, not an exception. On device that is a crash
with no user-visible cause and no recovery. Budget Crab ships voice input.

---

## 1. The stack, and the three occurrences

Signal `SIGABRT`, `EXC_CRASH`, termination `Abort trap: 6`. Triggered thread, top frames verbatim
from `DiagnosticReports/*.ips`:

```
libsystem_kernel.dylib        __pthread_kill
libsystem_pthread.dylib       pthread_kill
libsystem_c.dylib             abort
AudioToolboxCore              _ReportRPCTimeout(char const*, int)
AudioToolboxCore              _CheckRPCError(char const*, int, int)
libEmbeddedSystemAUs.dylib    AURemoteIO::~AURemoteIO()
libEmbeddedSystemAUs.dylib    ausdk::ComponentBase::AP_Close(void*)
AudioToolboxCore              AudioComponentInstanceDispose
AVFAudio                      AUInterfaceBaseV3::~AUInterfaceBaseV3()
AVFAudio                      AUInterfaceIOV3::~AUInterfaceIOV3()
AVFAudio                      AVAudioIOUnit::~AVAudioIOUnit()
AVFAudio                      AVAudioIOUnit::~AVAudioIOUnit()
AVFAudio                      -[AVAudioEngine dealloc]
FinanceTracker.debug.dylib    @objc VoiceInputService.__ivar_destroyer
libobjc.A.dylib               object_cxxDestructFromClass
libobjc.A.dylib               objc_destructInstance_nonnull_realized
libobjc.A.dylib               _objc_rootDealloc
FinanceTracker.debug.dylib    VoiceInputService.__deallocating_deinit
```

Read it plainly: **releasing a `VoiceInputService` disposes an `AURemoteIO` audio unit, that
disposal is an RPC to the audio daemon, the daemon did not answer inside AudioToolbox's timeout,
and AudioToolbox responded by aborting the process.**

Three occurrences on the simulator device `DB0C60E3-A74A-4456-95FE-CDA13BD43CE8`, all with the
identical stack:

| timestamp (local) | file |
|---|---|
| 2026-08-26 03:28:08 | `FinanceTracker-2026-08-26-032808.ips` |
| 2026-08-26 04:51:31 | `FinanceTracker-2026-08-26-045131.ips` |
| 2026-08-26 07:39:36 | `FinanceTracker-2026-08-26-073936.ips` |

The 07:39 one is the abort that killed the swift-testing phase mid-run and silently dropped 415
tests. It is **intermittent**: the HEAD full-suite control run (1084 executed) did not hit it.

The triggering test does not use voice at all:

```swift
@Test func voiceInputServiceDeallocatesAfterStop() {
    weak var weakService: VoiceInputService?
    autoreleasepool {
        let service = VoiceInputService(locale: Locale(identifier: "en_US"))
        weakService = service
        service.stop()   // safe when not listening; exercises cleanup()
    }
    #expect(weakService == nil, ...)
}
```

Create, `stop()`, release. The engine is **never started**.

---

## 2. Does `deinit` stop the engine and deactivate the session, or rely on dealloc order?

Quoted in full, `FinanceTracker/Services/VoiceInputService.swift:155`:

```swift
deinit {
    NotificationCenter.default.removeObserver(self)
    // Tear down audio synchronously; we cannot hop to the main actor from deinit.
    recognitionTask?.cancel()
    if audioEngine.isRunning {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    request?.endAudio()
}
```

Against `cleanup()`, which `stop()` calls (`:306`):

```swift
private func cleanup() {
    silenceTimer?.invalidate()
    silenceTimer = nil
    recognitionTask?.cancel()
    recognitionTask = nil
    if audioEngine.isRunning {
        audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)      // ← NOT guarded by isRunning
    request?.endAudio()
    request = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    isListening = false
}
```

Three findings, in order of importance:

**(a) `deinit` never deactivates the `AVAudioSession`.** `cleanup()` does; `deinit` does not, and
`deinit` does not call `cleanup()` (it cannot — `cleanup()` is main-actor-isolated and `deinit`
says so in its own comment). A service released without a preceding `stop()` therefore leaves the
session active and hands the engine to `dealloc` for disposal. Disposal is the frame that aborts.

**(b) `cleanup()` touches `audioEngine.inputNode` unconditionally.** `AVAudioEngine.inputNode` is
lazy: first access instantiates and configures the input audio unit. So `stop()` on a service that
never listened — advertised one line above as *"Safe to call when not listening (no-op)"* — is not
a no-op. It plausibly **creates** the very `AURemoteIO` that the crash then dies disposing. That is
the shape of the crashing test exactly: construct, `stop()`, release, abort in dispose.

**(c) A failed `start()` leaks the tap.** `installTap` happens at `:257`, `audioEngine.start()` at
`:263`. If `start()` throws, the tap is installed and `isRunning` is false, so `deinit`'s
`removeTap` — inside `if audioEngine.isRunning` — never runs.

---

## 3. Can a user-reachable path release the service with the engine still running?

Ownership is a single `@StateObject` in `QuickEntryView.swift:72`, and the view calls
`voice.stop()` in `.onDisappear` (`:210`). So the ordinary dismissal path does stop first.

But that is the wrong question to stop at, because of (b):

- **Every open-and-close of Quick Entry calls `stop()`**, whether or not the user used voice, and
  `stop()` reaches `audioEngine.inputNode`. If (b) holds, the app instantiates and then disposes a
  remote-IO audio unit on a screen the user may never have spoken to. That is the crashing path,
  and it is reachable by opening Quick Entry and closing it.
- `deinit` can still run with a live engine when `onDisappear` does not: app termination, or a
  teardown that destroys the view without an appearance transition. There `deinit` stops the
  engine but leaves the session active, then disposes at dealloc — (a).
- `handleResignActive` (registered at `:146`) is the other asynchronous entry into teardown, so
  backgrounding during dictation is a second path into the same dispose.

None of this is proven on device. It is what the code says, and what the stack says.

---

## 4. What would have to be true for this to be simulator-only

Stated so it can be killed, not defended:

> **Claim S:** the abort requires the audio server's reply to `AudioComponentInstanceDispose` to
> exceed AudioToolbox's RPC timeout, and only the simulator's audio daemon is slow enough to do
> that — on device, `coreaudiod` with a real hardware IO thread always answers in time.

What makes Claim S *falsifiable*, and what to run:

1. **Device repetition.** Run construct → `stop()` → release, several thousand times, on a
   physical device, under CPU and audio contention (music playing, another app holding the session).
   **One abort on device falsifies S outright.**
2. **Timeout symmetry.** `_ReportRPCTimeout` lives in AudioToolboxCore, which ships in both builds.
   Nothing in the stack is simulator-specific code. If the timeout constant and the abort-on-timeout
   policy are identical on device — they appear to be — then S is a claim about *daemon latency
   only*, and latency is a distribution, not a guarantee. A distribution with a long tail produces
   rare device crashes, which is precisely what would never be reproduced in QA and would arrive
   as unexplained field crash reports.
3. **Load correlation.** Here it fired 3 times in ~4 hours of heavy parallel test load and never in
   the unloaded control run. If S is true, device aborts should be *rarer* under load rather than
   absent; if the correlation is with load rather than with platform, S is the wrong axis.

Until (1) has been run, "simulator-only" is an assumption, and the honest statement is: **the abort
mechanism is platform-independent code reacting to a platform-dependent latency.**

---

## 5. What is NOT claimed

- Not claimed that this has ever crashed a user's device. There is no field evidence either way;
  the mailbox has no reports and the install base is small.
- Not claimed that (b) is proven. It is the leading hypothesis and it matches the crashing test,
  which never starts the engine. Falsify it by instrumenting whether `inputNode` access alone
  creates the unit, or by making `cleanup()`'s `removeTap` conditional and re-running the
  create/stop/release loop.
- Not claimed that fixing (a), (b) or (c) removes the abort. The abort is AudioToolbox's response
  to a timeout; the fixes reduce how often the app asks it to dispose a unit at all.

## 6. Not fixed in build 10

Build 10 carries the PDF export fix and the amount-overflow work
(`DEFECT_IMPORT_AMOUNT_CAP_ASYMMETRY.md`). This abort is untouched: it is a crash on a
teardown path, not a data defect, and the store-open path was ruled out of scope
deliberately. It remains a release hold in its own right.

## 7. Consequence for the test suite, already handled elsewhere

While this is open, the crashing test makes any unfiltered run a coin flip: when it aborts it takes
the whole swift-testing phase with it (44 suites, 415 `@Test` functions) and the run reports a
plausible number with no indication anything is missing. `scripts/run-tests.sh` now exits 4 on a
truncated run. The clean rerun excludes this single test by name and runs it separately, and that
exclusion is logged in the run report rather than left silent.
