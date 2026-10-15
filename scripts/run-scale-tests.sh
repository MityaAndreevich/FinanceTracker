#!/bin/bash
#
# run-scale-tests.sh — the bulk-delete SCALE benchmarks, on demand.
#
# WHY (2026-10-14, D33): these three suites seed 16k-row stores and took ~1 374 s
# of the 1 509 s unit phase. On 2026-10-12 the full suite peaked at 13.9 GB swap
# during that phase. They are benchmarks, so the default run disables them
# (FinanceTrackerTests/ScaleTestGate.swift). Their correctness half stays in the
# default gate (BulkDeleteCorrectnessTests).
#
# WHEN: any release whose diff touches deletion, purge or reset paths needs a
# GREEN run of this script on the archived commit, recorded in STATE §11
# (ARCHITECTURE.md, release section).
#
# CONTRACT (on top of run-tests.sh's codes, which pass through: 1 red, 3 build)
#   exit 0  — exactly 4 executed, 0 skipped, all passed
#   exit 2  — 0 executed: the variable never reached the test process and the
#             suites skipped themselves. That is a SILENT NO-OP, never a pass.
#   exit 4  — anything else short of 4 executed / 0 skipped (a partial gate)
#
# REPORTS: seconds per test, and peak swap from scripts/machine-sampler.sh
# (30 s samples).
#
# Machine rules: ~/.claude/CLAUDE.md. This script REFUSES to start when another
# xcodebuild is alive. A scale run under a second suite measures nothing.
#
# Do not pipe this script (same reason as run-tests.sh: $? would be the pipe's).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 3

EXPECTED_EXECUTED=4
SUITES=(
    -only-testing:FinanceTrackerTests/BulkDeleteFixMeasurementTests
    -only-testing:FinanceTrackerTests/BulkDeleteCostMeasurementTests
    -only-testing:FinanceTrackerTests/BulkDeleteQuadraticMechanismTests
)

if pgrep -x xcodebuild >/dev/null; then
    echo "✗ another xcodebuild is running — not starting (one run per machine):"
    pgrep -fl xcodebuild | sed 's/^/     /'
    exit 3
fi

WORK="$(mktemp -d)"
export RESULT_BUNDLE="$WORK/result.xcresult"
SAMPLES="$WORK/machine-samples.txt"
SWAP_START="$(sysctl -n vm.swapusage)"

"$REPO_ROOT/scripts/machine-sampler.sh" "$SAMPLES" 30 &
SAMPLER=$!

# THE MECHANISM: xcodebuild passes every TEST_RUNNER_<VAR> to the test runner
# with the prefix stripped (`man xcodebuild`), so the test process sees
# RUN_SCALE_TESTS=1 and ScaleTestGate.isEnabled is true.
TEST_RUNNER_RUN_SCALE_TESTS=1 "$REPO_ROOT/scripts/run-tests.sh" "${SUITES[@]}"
RC=$?

SWAP_END="$(sysctl -n vm.swapusage)"
wait "$SAMPLER" 2>/dev/null

echo ""
echo "══ scale run ══"
echo "── swap at start: $SWAP_START"
echo "── swap at end  : $SWAP_END"
if [ -s "$SAMPLES" ]; then
    awk '{for(i=1;i<=NF;i++) if($i ~ /^swap_used_mb=/){split($i,a,"="); if(a[2]+0>m){m=a[2]+0; t=$1}}}
         END{ if (t) printf "── peak swap    : %.0f MB at %s (30 s samples, %s)\n", m, t, FILENAME }' "$SAMPLES"
    awk '$NF ~ /^xcb=/ {split($NF,a,"="); if (a[2]+0>1) n++} END{ if (n) printf "⚠  %d sample(s) saw more than one xcodebuild: see %s\n", n, FILENAME }' "$SAMPLES"
else
    echo "── peak swap    : no samples (the run ended inside the first 30 s)"
fi

if [ "$RC" -eq 3 ] || [ ! -d "$RESULT_BUNDLE" ]; then
    echo "✗ no test verdict (run-tests.sh exit $RC)"
    exit 3
fi

read -r EXECUTED SKIPPED <<<"$(
  xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" 2>/dev/null \
  | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("passedTests",0)+d.get("failedTests",0)+d.get("expectedFailures",0), d.get("skippedTests",0))
' 2>/dev/null || echo "-1 -1")"

echo "── per test (seconds):"
xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE" 2>/dev/null | python3 -c '
import json, sys
# durationInSeconds, not "duration": that string is locale-formatted ("0,089s").
def walk(n):
    if n.get("nodeType") in ("Test Case", "Test Method"):
        print("     %8.1f  %s  %s" % (n.get("durationInSeconds") or 0, n.get("result"), n.get("name")))
    for c in n.get("children", []) or []:
        walk(c)
for n in json.load(sys.stdin).get("testNodes", []) or []:
    walk(n)
'
echo "── executed=$EXECUTED skipped=$SKIPPED (expected $EXPECTED_EXECUTED executed, 0 skipped)"
echo "   bundle: $RESULT_BUNDLE"

if [ "$EXECUTED" -eq 0 ]; then
    echo "✗ ZERO scale tests executed ($SKIPPED skipped). RUN_SCALE_TESTS did not reach"
    echo "  the test process. This is a silent no-op, NOT a pass."
    exit 2
fi
if [ "$EXECUTED" -ne "$EXPECTED_EXECUTED" ] || [ "$SKIPPED" -ne 0 ]; then
    echo "✗ partial scale run: $EXECUTED executed / $SKIPPED skipped"
    exit 4
fi
[ "$RC" -eq 0 ] && echo "✓ all $EXPECTED_EXECUTED scale tests passed"
exit "$RC"
