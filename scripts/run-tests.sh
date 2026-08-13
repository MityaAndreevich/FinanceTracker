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
#
#   Exit 2 and exit 3 exist so a mutation-testing driver can never again
#   classify a compile error or an empty filter as "the test caught it".
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
#   The load-bearing case is the PAIR, not exit 3 alone. A build failure and a
#   test failure both had to be provoked, because the cheap fix for the old bug
#   (grep harder for "error:") passes the exit-3 test and silently breaks exit 1
#   — XCTest prints assertion failures with an `error:` prefix too. Checking
#   only that exit 3 now fires would have commissioned that bug into place.
#   Re-run BOTH if this logic is ever touched.
#
set -uo pipefail

PROJECT="FinanceTracker.xcodeproj"
SCHEME="FinanceTracker"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 3

BUNDLE="$(mktemp -d)/result.xcresult"
LOG="$(mktemp)"

echo "▶ xcodebuild test ${*:-（full suite）}"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -parallel-testing-enabled NO \
    -resultBundlePath "$BUNDLE" \
    "$@" test >"$LOG" 2>&1
XCODEBUILD_STATUS=$?

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

if [ "$FAILED" -gt 0 ]; then
    echo "✗ $FAILED test(s) failed:"
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
    exit 1
fi

echo "✓ $PASSED passed, $EXECUTED executed."
exit 0
