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
#   exit 3  — the build itself failed             (NOT a caught mutation)
#
#   Exit 2 and exit 3 exist so a mutation-testing driver can never again
#   classify a compile error or an empty filter as "the test caught it".
#
# USAGE
#   scripts/run-tests.sh                                   # whole suite
#   scripts/run-tests.sh -only-testing:FinanceTrackerTests/CapabilityMatrixTests
#   scripts/run-tests.sh "-only-testing:FinanceTrackerTests/Suite/testName()"
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

# ── Build failure is not a test result ────────────────────────────────────────
# xcodebuild prints ** TEST FAILED ** for a compile error too. Distinguish them,
# because "the mutation was caught" and "the mutation did not compile" are
# opposite conclusions drawn from identical output.
if grep -qE "^(.*error:|\*\* BUILD FAILED)" "$LOG" && [ ! -d "$BUNDLE" ]; then
    echo "✗ BUILD FAILED — this is NOT a test result."
    grep -E "error:" "$LOG" | head -20
    echo "  full log: $LOG"
    exit 3
fi

if [ ! -d "$BUNDLE" ]; then
    echo "✗ no result bundle produced — treating as build failure, NOT a test result."
    tail -30 "$LOG"
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
