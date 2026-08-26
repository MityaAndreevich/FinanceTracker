#!/bin/bash
#
# run-tests.sh — xcodebuild test, but a filter that matches nothing FAILS.
#
# WHY THIS EXISTS
#   `xcodebuild -only-testing:Foo` prints ** TEST SUCCEEDED ** when the filter
#   matches zero tests. A green run that ran nothing is byte-identical to a
#   green run that ran everything. That defect has already produced two wrong
#   headline findings in this project (AUDIT_TEST_DISCRIMINATION_2026-08-08 §4:
#   G5/G7 reported GREEN because the -only-testing list omitted the suite that
#   would have failed).
#
#   ARCHITECTURE.md documents the hazard and tells you to verify by hand with
#   `xcresulttool`. A documented manual step is not a guard — it is a comment,
#   and a comment guards nothing. This script makes the check unskippable.
#
# CONTRACT
#   exit 0  — tests ran AND all passed
#   exit 1  — tests ran AND at least one failed   (a real RED)
#   exit 2  — ZERO tests executed                 (the silent no-op; never a pass)
#   exit 3  — the build failed, OR its status could not be read
#                                                 (NOT a caught mutation)
#   exit 4  — FEWER tests executed than this suite declares
#                                                 (the run was truncated, or tests
#                                                  were deleted; either way its
#                                                  pass/fail list is not a verdict)
#   exit 5  — MORE tests executed than this suite declares
#                                                 (the suite grew and the constant
#                                                  below is stale — the gate is
#                                                  degrading, fix the constant)
#
#   Exit 2 and exit 3 exist so a mutation-testing driver can never again
#   classify a compile error or an empty filter as "the test caught it".
#
#   Exit 4 exists because exit 2 guards ZERO and nothing guarded FEWER. Observed
#   2026-08-26: a full-suite run reported `executed=563 passed=550 failed=13`
#   and exited 1, looking for all the world like an ordinary red. HEAD executes
#   1084. A test had aborted the process — VoiceInputService's AVAudioEngine
#   teardown, SIGABRT — and taken the whole swift-testing phase with it: 44
#   suites, 415 @Test functions, never run and never reported as missing. The
#   number looked plausible, so nobody compared it against anything. This gate
#   has been blind to that the entire time it has been gating releases, build 9
#   included.
#
#   That is this script's own defect class, one level up: a plausible-looking
#   number that no one compared against the expected one.
#
#   Exit 3 also absorbs "we could not tell". An unreadable build status is
#   indistinguishable from a failed build, and the one thing it is definitely
#   not is a statement about the tests.
#
# COMMISSIONED
#   All four codes were provoked deliberately and observed, 2026-08-13 — not
#   reasoned about. See COMMISSIONING below. Exit 3 in particular had never
#   fired: it was added after a compile error was scored as a catch, and when
#   that exact case recurred it reported exit 2 instead.
#
# USAGE
#   scripts/run-tests.sh                                   # whole suite
#   scripts/run-tests.sh -only-testing:FinanceTrackerTests/CapabilityMatrixTests
#   scripts/run-tests.sh "-only-testing:FinanceTrackerTests/Suite/testName()"
#
# ⚠️ HOW YOU CALL IT — DO NOT PIPE THIS SCRIPT
#
#   scripts/run-tests.sh | tail -60          # ✗ $? is TAIL's status, not ours
#   scripts/run-tests.sh > out.txt 2>&1      # ✓ $? is ours
#   scripts/run-tests.sh 2>&1 | tee out.txt  # ✗ unless the CALLER sets pipefail
#
#   Every exit code above is worthless if the caller throws it away, and a pipe
#   throws it away by default: in a pipeline the shell reports only the LAST
#   command's status. `tail` succeeds at tailing a failed run, so a red suite
#   reports 0.
#
#   OBSERVED 2026-08-13, not hypothesised. A full-suite run with 2 failing UI
#   tests was invoked as `run-tests.sh 2>&1 | tail -60` and came back "exit 0"
#   while the very output being read said `✗ 2 test(s) failed`. The status and
#   the text disagreed, and the status is the half that automation reads.
#
#   `set -o pipefail` INSIDE this script cannot help: it governs pipelines this
#   script runs, never the pipeline this script is placed in. The fix has to
#   live in the caller, which is why it lives in this comment. The wrapper
#   cannot defend against how it is called — so the documentation has to.
#
#   This is the same composition blind spot the exit-2/exit-3 pair was built
#   for: each part is correct in isolation and the COMPOSITION drops the signal.
#   Guarding the script and then reading it through a pipe rebuilds the exact
#   defect the script exists to prevent, one layer up.
#
# COMMISSIONING — 2026-08-13, iPhone 17 Pro / iOS 26.5, Xcode result bundles v3
#   Every code was PROVOKED and OBSERVED. A guard nobody has seen fire is a
#   guess, which is how the exit-2/exit-3 defect survived from the day it was
#   written until the day it mattered.
#
#     exit 0  clean run of LocaleCompletenessTests            → observed 0 ✓
#     exit 1  deliberate XCTFail added to that suite          → observed 1 ✓
#     exit 2  -only-testing:...\/NoSuchSuiteExists            → observed 2 ✓
#     exit 3  deliberate `let x: Int = "not an Int"`          → observed 3 ✓
#
#   exit 4 / exit 5 — COMMISSIONED 2026-08-26, iPhone 17 Pro / iOS 26.5.
#
#   WIRING, proved by a real full run (the count has to actually reach the check):
#     constant temporarily 1098 against a 1099-test tree, one test -skip-testing'd
#       → observed 4 ✓   "MISSING 1 test(s)", executed=1096 skipped=3
#
#   THE THREE STATES, provoked over ONE real bundle with the constant as the only
#   variable — same data, nothing else differing (see CHECK_BUNDLE below):
#     constant 1101 → adjusted 1100 vs 1099 known → observed 4 ✓  (short by one)
#     constant 1099 → adjusted 1098 vs 1099 known → observed 5 ✓  (stale gate; the
#                                                    message named 1100, correctly)
#     constant 1100 → adjusted 1099 vs 1099 known → observed 1 ✓  (count in range;
#                                                    verdict falls to the tests)
#
#   Three separate full runs were NOT used, deliberately: they would have differed
#   in flakiness and timing as well as in the constant, which is worse evidence and
#   an hour more expensive. The comparison arithmetic was separately unit-checked
#   across eight argument shapes (unfiltered, single-test skip, suite skip with and
#   without EXPECTED_SKIPPED, bundle skip, -only-testing, and combinations).
#
set -uo pipefail

PROJECT="FinanceTracker.xcodeproj"
SCHEME="FinanceTracker"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

# ── How big is a whole run? ONE place. ───────────────────────────────────────
# OBSERVED, never counted from source. At tolerance 0 a constant derived by
# grepping declarations is wrong by construction: the first honest run goes red
# for no reason. The number below came from an actual clean run of this tree —
# see PROVENANCE.
#
# THE METRIC IS executed + skipped, NOT executed. Measured 2026-08-26, of the
# three tests this suite skips, TWO are CONDITIONAL:
#     PaywallClarityRenderTests.test_render_clarity_en/ru
#         XCTSkipUnless(env["RENDER_ARTIFACTS"] == "1")   ← PaywallClarityRenderTests.swift:33
#     "…deleted row traps"  .disabled(…)                  ← DeletedModelIdentifierTests.swift:183
# So `executed` alone is NOT deterministic — running with RENDER_ARTIFACTS=1
# executes two more tests and would fire the upper bound on a run where nothing
# grew. A guard that cries wolf on a legitimate invocation gets bypassed, which
# is worse than one that is loose. A conditional skip moves a test between the
# two buckets and leaves their SUM unchanged, while a truncated run reduces the
# sum — tests killed by an abort are reported in NEITHER bucket. So the sum is
# the honest metric: it is what the run knew about.
#
# PROVENANCE: 2026-08-26, iPhone 17 Pro / iOS 26.5.
#   HEAD 5a8ce5b, unfiltered            → executed=1084 skipped=3  → total 1087
#   this tree, one test -skip-testing'd → executed=1096 skipped=3  → total 1099,
#                                         i.e. 1100 unfiltered
#   + 1 test added since (PDFExportRenderTests.testTheWidestStorableAmountFitsTheTable)
# The confirming full run re-measures this and its own count becomes the entry
# above. If it disagrees, exit 5 below will say so and name the number.
#
# (Do not be reassured by a grep of declarations matching this figure. It did
#  once, at 1097, purely by coincidence — two unrelated sums landing on the same
#  value. Declared-vs-observed is not corroboration.)
EXPECTED_TOTAL_RUN=1101

# ── Tolerance: ZERO, and that is deliberate ──────────────────────────────────
# The obvious instinct is a percentage band for headroom. It is wrong here, twice
# over:
#
#   • Headroom exists for GROWTH, and growth moves the count UP. A downward floor
#     never fires on growth, so a wide band buys nothing in that direction.
#   • The count only falls when tests are LOST. Measured 2026-08-26, the smallest
#     swift-testing suite in this tree is ONE test — there are seven of them
#     (LocalizedCallSiteGuardTests, ImportModeReachabilityGuardTests,
#     TransactionPersistenceTests, …). So ANY tolerance of 1 or more lets a crash
#     that erases a whole suite clear the check silently. That is precisely the
#     scenario this exists for, one size down.
#
# So the tolerance collapses to near-exact, and near-exact is what we take.
# Deleting or adding a test is a deliberate act; updating the constant above is
# its correct and cheap cost.
COUNT_TOLERANCE=0

# A -skip-testing of a single TEST subtracts exactly 1 — that is knowable from the
# argument. A -skip-testing of a SUITE or BUNDLE is not: the count lives in the
# source, not in the flag. Rather than guess (an earlier version guessed 60, which
# with a zero tolerance is meaningless), the caller states it:
#     EXPECTED_SKIPPED=37 scripts/run-tests.sh -skip-testing:Bundle/SomeSuite
# Without it the count check is DISABLED for that run — loudly, never silently.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 3

BUNDLE="$(mktemp -d)/result.xcresult"
LOG="$(mktemp)"

# ── COMMISSIONING AFFORDANCE: re-check an EXISTING bundle ────────────────────
#   CHECK_BUNDLE=/path/to/result.xcresult scripts/run-tests.sh [same args]
#
# Runs the verdict logic — count check, failure list, exit code — over a bundle
# that already exists. No build, no simulator, no tests.
#
# WHY IT EXISTS: the count check's own red states have to be OBSERVED, and
# provoking each one with a separate 35-minute full run costs an hour to vary a
# single integer. One real run produces one bundle; the reds are then obtained
# over that same bundle with the constant varied. Same data, one variable —
# cleaner evidence than three runs that also differ in flakiness and timing.
#
# WHAT IT IS NOT: a way to get a verdict without running tests. It reports on
# whatever bundle it is handed, so handing it a stale one produces a stale
# answer — the run banner below says CHECK_BUNDLE loudly for exactly that reason.
# Nothing in CI should ever set it.

echo "▶ xcodebuild test ${*:-（full suite）}"

# ── Multiple filters mask each other ──────────────────────────────────────────
# THE GUARD BELOW IS A TOTAL, NOT A PER-FILTER CHECK. With two -only-testing
# arguments where one matches nothing, the other's tests keep EXECUTED > 0 and
# the zero-match passes silently — the exact failure this script exists to catch,
# reintroduced by the arithmetic.
#
# Found the honest way, 2026-08-13: a newly added suite was run alongside an
# existing one, reported "6 passed", and had in fact contributed nothing (the
# file was written outside the target's directory). Run alone it correctly
# returned exit 2.
#
# Attributing per filter would need one xcodebuild invocation per filter, which
# costs a full build each. So this warns instead of refusing — but it warns
# LOUDLY, because "6 passed" is exactly as reassuring as it is wrong.
FILTER_COUNT=0
for arg in "$@"; do
    case "$arg" in -only-testing:*|-only-testing) FILTER_COUNT=$((FILTER_COUNT + 1)) ;; esac
done
if [ "$FILTER_COUNT" -gt 1 ]; then
    echo ""
    echo "⚠  $FILTER_COUNT -only-testing filters. The zero-tests guard is a TOTAL:"
    echo "   if ONE of these matches nothing, the others hide it and this run"
    echo "   still reports a pass. Verify a NEW or RENAMED suite on its own first."
    echo ""
fi
if [ -n "${CHECK_BUNDLE:-}" ]; then
    echo ""
    echo "⚠  CHECK_BUNDLE set — NO tests were run."
    echo "   Re-checking an existing bundle: $CHECK_BUNDLE"
    echo "   Everything below is a verdict on THAT bundle, not on the tree as it is now."
    echo ""
    if [ ! -d "$CHECK_BUNDLE" ]; then
        echo "✗ no such bundle: $CHECK_BUNDLE"
        exit 3
    fi
    BUNDLE="$CHECK_BUNDLE"
    XCODEBUILD_STATUS=0
    : >"$LOG"
else
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -parallel-testing-enabled NO \
        -resultBundlePath "$BUNDLE" \
        "$@" test >"$LOG" 2>&1
    XCODEBUILD_STATUS=$?
fi

if [ ! -d "$BUNDLE" ]; then
    echo "✗ no result bundle produced — treating as build failure, NOT a test result."
    tail -30 "$LOG"
    echo "  full log: $LOG"
    exit 3
fi

# ── Build failure is not a test result ────────────────────────────────────────
# This check MUST precede the zero-executed guard: a failed build also executes
# zero tests, and whichever check runs first claims the run.
#
# HOW THIS USED TO BE WRONG (fixed 2026-08-13, Brief 36 item 4)
#   The old condition was:
#       grep -qE "^(.*error:|\*\* BUILD FAILED)" "$LOG" && [ ! -d "$BUNDLE" ]
#   Measured against a deliberate compile error, BOTH halves were wrong:
#     1. xcodebuild WRITES a result bundle even when the build fails, so
#        `[ ! -d "$BUNDLE" ]` was false and the conjunction could never fire.
#     2. For the `test` action a compile error prints ** TEST FAILED **, never
#        ** BUILD FAILED **, so that half never matched either.
#   The run fell through to the zero-executed guard and was reported as exit 2 —
#   and printed filter-debugging advice for a filter that was perfectly correct.
#   Exit 3 exists precisely because a compile error was once scored as a catch;
#   the distinction it was built for did not fire.
#
#   The lesson is narrower than "the condition was buggy": both halves were
#   guesses about xcodebuild's CONSOLE OUTPUT, and console output is not a
#   contract. The bundle records the build result as structured data, so ask it.
#
# WHY NOT JUST grep FOR "error:"
#   XCTest prints its assertion failures as `file.swift:LINE: error: -[...]` too.
#   Any log-scraping check that catches compile errors also catches real test
#   failures, which would convert every RED into exit 3 — a worse bug than the
#   one being fixed. That is why the original author added the bundle-absence
#   half. The fix is not a better grep; it is to stop grepping.
BUILD_ERRORS="$(
  xcrun xcresulttool get build-results summary --path "$BUNDLE" 2>/dev/null \
  | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("UNKNOWN"); raise SystemExit
n = d.get("errorCount")
if n is None:
    print("UNKNOWN"); raise SystemExit
print(n)
for e in (d.get("errors") or [])[:20]:
    t = e.get("issueType", "?"); m = e.get("message", "").replace("\n", " ")
    print(f"   - [{t}] {m}")
'
)"
BUILD_ERROR_COUNT="$(printf '%s' "$BUILD_ERRORS" | head -1)"

if [ "$BUILD_ERROR_COUNT" = "UNKNOWN" ]; then
    # We could not read the build result. "Don't know" must never be scored as a
    # clean signal about the tests, so classify it as exit 3 (NOT a test result)
    # rather than letting it fall through to exit 2 or 0.
    echo "✗ could not read the BUILD result from the bundle — refusing to guess."
    echo "  This is reported as exit 3 (not a test result) because an unreadable"
    echo "  build status is indistinguishable from a failed one."
    echo "  bundle: $BUNDLE  log: $LOG"
    exit 3
fi

if [ "$BUILD_ERROR_COUNT" -gt 0 ]; then
    echo "✗ BUILD FAILED ($BUILD_ERROR_COUNT error(s)) — this is NOT a test result."
    printf '%s\n' "$BUILD_ERRORS" | tail -n +2
    echo "  full log: $LOG"
    exit 3
fi

# ── Count what actually executed ──────────────────────────────────────────────
SUMMARY="$(xcrun xcresulttool get test-results summary --path "$BUNDLE" 2>/dev/null)"

read -r PASSED FAILED SKIPPED EXPECTED <<<"$(
  printf '%s' "$SUMMARY" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("ERR ERR ERR ERR"); raise SystemExit
print(d.get("passedTests", 0), d.get("failedTests", 0),
      d.get("skippedTests", 0), d.get("expectedFailures", 0))
'
)"

if [ "$PASSED" = "ERR" ]; then
    echo "✗ could not read the result bundle — refusing to report a pass."
    echo "  bundle: $BUNDLE  log: $LOG"
    exit 3
fi

EXECUTED=$(( PASSED + FAILED + EXPECTED ))

echo "── executed=$EXECUTED  passed=$PASSED  failed=$FAILED  skipped=$SKIPPED"

# ── THE GUARD ─────────────────────────────────────────────────────────────────
if [ "$EXECUTED" -eq 0 ]; then
    echo ""
    echo "✗✗ FILTER MATCHED ZERO TESTS — this is NOT a pass."
    echo ""
    echo "   Filter: ${*:-（none）}"
    echo "   Nothing ran, so nothing was verified. Common causes:"
    echo "     • a Swift Testing case named without its trailing '()'"
    echo "     • -only-testing naming a FILE rather than its @Suite type names"
    echo "       (a .swift file may hold many suites whose names differ from it —"
    echo "        e.g. AccessManagerTests.swift holds 8, none of them named that)"
    echo "     • a renamed or deleted suite"
    echo ""
    echo "   Derive the suite list from the FILE's @Suite declarations:"
    echo "     grep -nE '@Suite|^struct ' <file>"
    exit 2
fi

print_failures() {
    xcrun xcresulttool get test-results tests --path "$BUNDLE" 2>/dev/null \
      | python3 -c '
import json, sys
def walk(n):
    if n.get("result") == "Failed" and n.get("nodeType") in ("Test Case", "Test Method"):
        print("   -", n.get("name"))
    for c in n.get("children", []) or []:
        walk(c)
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
for n in d.get("testNodes", []) or []:
    walk(n)
'
}

# ── THE COUNT CHECK ───────────────────────────────────────────────────────────
# Two-sided, on purpose. A one-sided floor degrades on its own: the suite grows,
# the constant does not, and a year later a run that lost a quarter of the tests
# still clears a floor set for a smaller tree. There is no event that makes that
# visible — so the upper bound IS the event. A guard that cannot go stale is
# worth more than one that is precisely tuned today.
#
# Applies only to unfiltered runs: any -only-testing means the caller asked for a
# small run on purpose.
COUNT_CHECK=1
COUNT_CHECK_REASON=""
SKIP_ALLOWANCE=0
SUITE_LEVEL_SKIP=0
for arg in "$@"; do
    case "$arg" in
        -only-testing:*|-only-testing)
            COUNT_CHECK=0
            COUNT_CHECK_REASON="-only-testing (a deliberately small run)"
            ;;
        -skip-testing:*)
            spec="${arg#-skip-testing:}"
            slashes="${spec//[!\/]/}"
            if [ "${#slashes}" -ge 2 ] && [ "${spec%\)}" != "$spec" ]; then
                SKIP_ALLOWANCE=$(( SKIP_ALLOWANCE + 1 ))   # a single test: exactly 1
            else
                SUITE_LEVEL_SKIP=1
            fi
            ;;
    esac
done

if [ "$SUITE_LEVEL_SKIP" -eq 1 ] && [ "$COUNT_CHECK" -eq 1 ]; then
    if [ -n "${EXPECTED_SKIPPED:-}" ]; then
        SKIP_ALLOWANCE=$(( SKIP_ALLOWANCE + EXPECTED_SKIPPED ))
    else
        COUNT_CHECK=0
        COUNT_CHECK_REASON="a suite-level -skip-testing with no EXPECTED_SKIPPED"
        echo ""
        echo "⚠  COUNT CHECK DISABLED for this run."
        echo "   A -skip-testing naming a SUITE or BUNDLE removes an unknown number of"
        echo "   tests, so executed-vs-expected cannot be computed. State it:"
        echo "     EXPECTED_SKIPPED=<n> $0 $*"
        echo "   Until then this run cannot tell a truncated suite from a skipped one."
        echo ""
    fi
fi

TOTAL_KNOWN=$(( EXECUTED + SKIPPED ))
ADJUSTED=$(( EXPECTED_TOTAL_RUN - SKIP_ALLOWANCE ))
DELTA=$(( TOTAL_KNOWN - ADJUSTED ))

# ── Always print it, pass or fail (drift should be visible before it is a gap) ─
if [ "$COUNT_CHECK" -eq 1 ]; then
    if [ "$DELTA" -ge 0 ]; then DELTA_STR="+$DELTA"; else DELTA_STR="$DELTA"; fi
    echo "── count: executed+skipped=$TOTAL_KNOWN  expected=$ADJUSTED  Δ=$DELTA_STR  tolerance=±$COUNT_TOLERANCE"
else
    echo "── count: not checked — $COUNT_CHECK_REASON"
fi

if [ "$COUNT_CHECK" -eq 1 ] && [ "$TOTAL_KNOWN" -lt $(( ADJUSTED - COUNT_TOLERANCE )) ]; then
    echo ""
    echo "✗✗ TRUNCATED RUN — $TOTAL_KNOWN test(s) known to this run, $ADJUSTED expected. NOT a verdict."
    echo ""
    echo "   expected (a whole run) : $EXPECTED_TOTAL_RUN   (executed + skipped)"
    if [ "$SKIP_ALLOWANCE" -gt 0 ]; then
        echo "   allowed for -skip-testing: -$SKIP_ALLOWANCE  → adjusted expectation $ADJUSTED"
    fi
    echo "   this run knew about    : $TOTAL_KNOWN  ($EXECUTED executed + $SKIPPED skipped)"
    echo "   MISSING                : $(( ADJUSTED - TOTAL_KNOWN )) test(s)  (tolerance ±$COUNT_TOLERANCE)"
    echo ""
    echo "   Fewer tests ran than this suite declares. Whatever passed below is a"
    echo "   statement about a FRACTION of the suite, and the tests that never ran"
    echo "   are not reported anywhere — they are simply absent."
    echo ""
    echo "   Two causes, and they need different responses:"
    echo "     • a test aborted the process and took the rest of its phase with it."
    echo "       Look for a pseudo-test named 'AppName (pid) encountered an error':"
    echo "         xcrun xcresulttool get test-results summary --path \"$BUNDLE\""
    echo "       then export the diagnosticsRef directory for DiagnosticReports/*.ips."
    echo "     • tests were deliberately deleted — then update EXPECTED_TOTAL_RUN in"
    echo "       this script, and say in its comment when and why."
    echo ""
    if [ "$FAILED" -gt 0 ]; then
        echo "   For reference, what DID fail in this partial run:"
        print_failures
        echo ""
    fi
    echo "   bundle: $BUNDLE  log: $LOG"
    exit 4
fi

if [ "$COUNT_CHECK" -eq 1 ] && [ "$TOTAL_KNOWN" -gt $(( ADJUSTED + COUNT_TOLERANCE )) ]; then
    echo ""
    echo "✗✗ STALE GATE — $TOTAL_KNOWN test(s) known to this run, $ADJUSTED expected."
    echo ""
    echo "   The suite has GROWN by $DELTA test(s) and this script does not know it."
    echo "   That is not harmless: while the constant lags, the lower bound is set"
    echo "   for a smaller tree, and a run that loses those $DELTA tests — plus more —"
    echo "   would still clear it. The gate degrades silently from here."
    echo ""
    echo "   Fix, one line, in $0 :"
    echo "       EXPECTED_TOTAL_RUN=$(( TOTAL_KNOWN + SKIP_ALLOWANCE ))"
    echo "   and record in its comment when this was measured and from what run."
    echo ""
    if [ "$FAILED" -gt 0 ]; then
        echo "   The tests themselves also had failures:"
        print_failures
        echo ""
    fi
    echo "   bundle: $BUNDLE  log: $LOG"
    exit 5
fi

if [ "$FAILED" -gt 0 ]; then
    echo "✗ $FAILED test(s) failed:"
    print_failures
    exit 1
fi

echo "✓ $PASSED passed, $EXECUTED executed."
exit 0
