# BRIEF (Claude Code) — findings from the founder's device log, 1.0.2 QA. Model: Sonnet. Branch `main`. Report before fixing on #2. Commit per item, push.

Context: the hang fix (1dc015f, 8a7f7bf) is on the device and the app is responsive. These are what the log still shows.

## 1. Swift 6 actor-isolation warning — new debt, in the hot path
`ProactiveAlertRefresher`: *"Main actor-isolated static property `defaultCoalesceWindow` can not be referenced from a nonisolated context; this is an error in the Swift 6 language mode."*
This came in with the scheduler you just added. It's a warning today and a **hard error under Swift 6**, and it sits in the exact code that runs on every save — the code we just spent two days fixing for actor/threading reasons. Fix the isolation properly (don't silence it with `nonisolated(unsafe)` unless you can justify why the value is genuinely safe to read from any context — and say so if you do). Confirm the build is warning-clean afterwards.

## 2. `Invalid frame dimension (negative or non-finite)` — now ONCE at launch, and gone from the hot path
**Correcting my own earlier read of this** (I judged it from a single pasted line; the full log says otherwise). Sequence from the founder's device:
```
⏱ cold start → first view: 551ms
Invalid frame dimension (negative or non-finite).   ← exactly once, at launch
… (system keyboard noise) …
QuickAddSave #1..#5: inserted 1 row      ← five rapid saves, the line never returns, no crash
```
Historically this line **spammed before every crash**. It is now a **single launch-time emission and absent from the QuickAdd hot path** — so `ChartGuards.canRenderInBox` + `.guardedChartFrame()` (343b9f7) **did their job**. What's left is a smaller, different thing: something transient during first layout.

### The longer log names the source — it is the VOICE INPUT path, not the charts
An 18-save run (domain guard OFF, no crash) shows the line clustering, ~6 times, in one exact shape:
```
[VoiceInputService] Resolving recognizer for appLanguageCode=en
[VoiceInputService] ✅ en_US: on-device recognition available — using
Invalid frame dimension (negative or non-finite).            ← immediately after
Unable to simultaneously satisfy constraints.
    ButtonWrapper.width == _UIButtonBarButton.width
    'UIView-Encapsulated-Layout-Width' ButtonWrapper.width == 0     ← WIDTH ZERO
```
It never appears near a chart render. It appears **at launch once, and thereafter only in the voice/keyboard-accessory context.** This is exactly what `BRIEF_MAINTHREAD_HANG_NANFRAME.md` **Item 2** predicted and nobody executed:
> "the QuickEntry voice/input bar (ZStack + cross-fade, fixed height), the mic/dictation button, and any ring/donut/progress computing a width from a value that can be 0"

**This is correlation from a log, not proof — verify against the code.** Step 0: was Item 2 ever done beyond the chart guards? Then determine whether the zero-width `ButtonWrapper` / `_UIButtonBarButton` is **ours** (our keyboard-accessory / mic control) or UIKit's own (`TUIKeyplane.right.width == -1.5` in the same log is Apple's keyboard internals = system noise; don't chase that one). If ours: it's being laid out at zero width while the recognizer initialises — give the control a valid intrinsic/min width, clamp computed dimensions `>= 0`, guard `.isFinite`.

**Priority: not a blocker.** No crash, no hot-path spam, cosmetic. But now that we know where to look, close it properly rather than leaving a third orphaned item from that brief.

## 3. Confirm benign or real — do not assume
`Couldn't read values in CFPrefsPlistSource (Domain: group.com.dmitrylogachev.budgetcrab, User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null))` — this is usually benign iOS noise, **but it names OUR App Group**, and the **widget reads that suite**. Confirm with evidence whether anything actually fails to read (widget snapshot, shared defaults) or it's cosmetic. If cosmetic, say so and we ignore it forever. If we're reading the group suite in a way iOS doesn't like, fix it. `fopen failed for data file: errno = 2` — same treatment: confirm ours or system noise.

## 4. Cold-start instrument
The log shows `cold start → first view: 767ms` then `551ms`. Nice instrument — keep it. Tell me: is that measured on the seeded 8k store or a small one, and what's the number at 8k? If cold start scales with row count we have another main-thread read on the launch path (the old brief's item: "defer launch-time reads off the first-frame path").

## 5. Housekeeping — not now, but plan it
The `#if DEBUG` chart-bisection panel exists solely to bisect crash #22. **When #22 closes, delete the panel and its plumbing** (`ChartBisection`, the Settings section, the toggles). Don't remove it before then — it's the only instrument we have for that crash. Note it wherever we track leftover scaffolding so it doesn't rot in the codebase.

## Report
Item 1: the isolation fix + warning-clean build. Item 2: Step 0 answer, then **what actually emits the line**, with evidence — this is the headline. Item 3: benign or real, with the evidence. Item 4: the 8k cold-start number.
