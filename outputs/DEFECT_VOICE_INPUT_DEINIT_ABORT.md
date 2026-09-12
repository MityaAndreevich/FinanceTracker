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

---

## 8. Answering the two questions from the code (2026-09-12)

Asked while 1.0.5 build 10 sits in review: **does `deinit` stop the engine and deactivate the
session before releasing it, or does it rely on dealloc order? And is there a user-reachable path
that releases the service with the engine still running?**

Read at `8c98982` + the post-submission docs commits; `VoiceInputService.swift` is unchanged since
the defect was filed. **Nothing was fixed. No code was touched.**

### 8.1 `deinit` relies on dealloc order, and it cannot do otherwise

Three separate statements, and only the third is a design choice:

1. **It stops the engine, conditionally** — `if audioEngine.isRunning` (`:159`).
2. **It never deactivates the `AVAudioSession`.** `cleanup()` does (`:321`); `deinit` does not, and
   cannot call `cleanup()` — `cleanup()` is main-actor-isolated and `deinit` is not, which `deinit`
   says in its own comment.
3. **It never disposes the engine, and there is no API with which it could.** `audioEngine` is a
   stored `let` (`:48`). ARC releases it in the ivar destroyer *after* the `deinit` body returns.
   `AVAudioEngine` has no `dispose()`; disposal is `-[AVAudioEngine dealloc]`'s business.

The crash stack is that order, printed:

```
VoiceInputService.__deallocating_deinit      ← our deinit body has already run
_objc_rootDealloc → objc_destructInstance
VoiceInputService.__ivar_destroyer           ← ARC now releases `audioEngine`
-[AVAudioEngine dealloc]
AVAudioIOUnit::~AVAudioIOUnit → AudioComponentInstanceDispose
_CheckRPCError → _ReportRPCTimeout → abort
```

So the answer is **dealloc order, unavoidably** — and the abort is not in the part `deinit`
controls. `deinit` runs to completion and *then* the process dies. Anything `deinit` could be made
to do about the engine is therefore the wrong lever; the levers are earlier (never instantiate the
IO unit) or adjacent (do not hand the daemon a live session to tear down at the same moment).

### 8.2 The second question is answerable, but it is not the load-bearing one

**Answer: not on the ordinary dismissal path.** `QuickEntryView` owns the only production instance
(`@StateObject`, `:72`) and calls `voice.stop()` in `.onDisappear` (`:210`), which fires before
the sheet's state storage is released. `handleResignActive` (`:328`, registered `:147`) covers
backgrounding. `toggleVoice` awaits across `requestAuthorizationIfNeeded()` and `start()`, but the
`Task` captures the view struct, which holds the `StateObject` box, so the service cannot be
released mid-suspension. The remaining engine-still-running releases are **process termination**
and **a view-tree teardown with no appearance transition** — narrow, and not the interesting case.

**The interesting case is that a stopped engine does not avoid the abort.** The aborting frame is
`AudioComponentInstanceDispose`, and dispose runs whenever an `AURemoteIO` was ever *instantiated*
— not whenever it was *started*. The crashing test never starts the engine. So the reachability
question that matters is not "can the service be released while running" but:

> **On what user path does an `AURemoteIO` get created at all?**

And the answer is **every open-and-close of Quick Entry, whether or not the user speaks**, because
`cleanup()` reaches `audioEngine.inputNode` unconditionally at `:316` — outside the `isRunning`
guard that protects `audioEngine.stop()` one line above. `AVAudioEngine.inputNode` is lazy; first
access instantiates and configures the input audio unit. `stop()`, documented at `:290` as
*"Safe to call when not listening (no-op)"*, is therefore not a no-op: on a service that never
listened it plausibly **creates** the very unit whose disposal aborts. Construct → `stop()` →
release is the crashing test, exactly.

`start()` also calls `stop()` first (`:239`), so the same access happens at the top of every
dictation, before the session is configured.

### 8.3 One piece of discriminating evidence we may already hold, and one new prediction

**Already held, if the attribution is real.** `LeakTeardownTests` contains two near-identical
tests in one `.serialized` suite: `voiceInputServiceDeallocatesWhenReleased` (construct, release —
**never calls `stop()`**, `:43`) and `voiceInputServiceDeallocatesAfterStop` (`:65`). §1 names the
`stop()` variant as the triggering test. If that name came out of the `.ips` reports, then across
three aborts the no-`stop()` twin sitting beside it never fired — which is direct evidence for
(b), and nobody has drawn it out. **If the name was inferred rather than read, it is worth
nothing.**

> ⚠️ **The three `.ips` files can no longer be checked, and this section caused that.**
> Searched 2026-09-12: nothing named `FinanceTracker*.ips` survives anywhere —
> `~/Library/Logs/DiagnosticReports` holds 9 files, none older than **2026-09-05**, so macOS had
> already rotated the 2026-08-26 reports out of the host directory before today (that directory's
> mtime, 2026-09-11, predates this session). But the per-device copy under
> `~/Library/Logs/CoreSimulator/DB0C60E3-…/CrashReporter/` **was wiped by an
> `xcrun simctl erase all` run in this session**, minutes before the search, and whether it still
> held them cannot now be established. Host rotation is the more likely cause. It is not the only
> one, and the honest statement is: **this may have been destroyed here.**
>
> **Two of this project's own rules are in direct conflict, and nobody had noticed.**
> `run-tests.sh` and `project_simulator_contamination_confirmed` both say **erase before every full
> run** — mandatory, and correct. `§1` of this file rests on `.ips` files that live on the device
> being erased. **The erase rule silently deletes the evidence the defect rule depends on.** The
> fix is not to stop erasing; it is to **copy `.ips` files out of the device and into the repo the
> moment they are cited**, the way the store fixtures are committed rather than left where the next
> capture will overwrite them. Nothing of this file's §1 is committed anywhere — the stack in §1 is
> a transcription, and transcriptions are now all we have.

So the attribution in §1 cannot be confirmed and cannot be refuted. It can only be **re-earned**,
by Test 2 below, which produces the same discrimination from a run we control instead of from a
report we no longer hold.

**New, and it costs nothing to observe.** `cleanup()` also calls
`setActive(false, options: .notifyOthersOnDeactivation)` unconditionally (`:321`). So closing
Quick Entry without ever tapping the mic tells the system Budget Crab has released an audio session
it never took, and invites other apps to resume. On a device with music playing that is a
potentially *audible* side effect of closing the add-expense sheet — and it is also the most
plausible reason the abort correlates with audio contention rather than with platform. It may well
be swallowed: deactivating a session that was never activated can fail, and the error is discarded
by `try?`. **Both outcomes are informative**, which is what makes it worth running first.

### 8.4 What a device test would have to show

The claim to kill is **Claim S** (§4): the abort needs the daemon to miss AudioToolbox's RPC
timeout, and only the simulator's daemon is slow enough.

**Test 1 — the decisive one. Repetition on physical hardware.**
Construct → `stop()` → release, in a loop, on a real device, under CPU and audio contention
(music playing, another app holding the session). **One abort falsifies S outright** and the
defect stops being a test-infrastructure problem and becomes a shipped crash.

What a *null* result may and may not say: this test **cannot prove S**. Zero aborts in N cycles
bounds the per-dispose rate, nothing more — so **the loop must count and log its own denominator**,
or the result is unreportable. Three simulator aborts arrived inside ~4 hours of heavy parallel
load whose dispose count nobody recorded, so there is no rate to compare against yet; the device
run should produce the first one on either platform. State the bound the run achieved
(e.g. "0 in 50,000 cycles ⇒ p < 6×10⁻⁵ at 95%") and treat "simulator-only" as **unproven at that
bound**, never as "fixed".

**Test 2 — separates (b) from everything else, and is nearly free.**
Same loop, one variable changed: an instrumented build that records whether `audioEngine.inputNode`
was ever touched. Compare construct→release against construct→`stop()`→release.
If aborts occur only in the `stop()` arm, (b) is confirmed and the fix surface collapses to one
unguarded line. If both arms abort, (b) is wrong and `inputNode` is not what creates the unit.

**Test 3 — the audible one, no build required.**
Play music, open Quick Entry, close it without touching the mic, on device. If the music's ducking
or level changes, `cleanup()`'s `setActive(false)` is reaching the system on a service that never
listened — (b)'s premise, observed with an ear instead of a profiler. If nothing happens, the
session half of `cleanup()` is inert when unused and only the `inputNode` half remains suspect.

**What none of these tests may conclude.** That fixing (a), (b) or (c) removes the abort. The abort
is AudioToolbox's response to a timeout it owns; the findings change how often we ask it to dispose
a unit, not what it does when the daemon is late. A fix is justified by "stop creating an audio unit
on a screen nobody spoke to", which is true regardless — **and it is deliberately not being chosen
here, because Test 2 is what tells us whether that is one line or the wrong line.**
