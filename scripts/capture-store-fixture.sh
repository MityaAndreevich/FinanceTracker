#!/bin/bash
#
# capture-store-fixture.sh — capture the store a SHIPPED BINARY actually writes.
#
# WHY THIS EXISTS
#   `FinanceTrackerSchemaV1` turned out to describe the 1.0.2 shape, not the
#   1.0.0 shape: it carries `isPossibleDuplicate`, added the day AFTER 1.0.0
#   shipped. Stores last written by 1.0.0 could not be migrated at all, and their
#   owners were stranded on the terminal floor screen for two releases
#   (`outputs/BUG_MIGRATION_FLOOR_1_0_0_STORES_2026-08-14.md`).
#
#   It went unnoticed because every fixture we had came from a version that
#   works, so every drill validated the path that works. A store this repo builds
#   TODAY is by definition the shape we already believe in — it cannot disagree
#   with what a released binary put on disk. Only a capture from that binary can.
#
# WHY THE FIXTURES ARE COMMITTED AND THIS SCRIPT IS STILL KEPT
#   > A fixture that exists only while an old commit still compiles disappears
#   > exactly when it becomes historical.
#   The committed .sqlite is the evidence; this script is how new versions join,
#   and how a fixture can be re-derived while its commit does still build.
#   Neither replaces the other.
#
# WHEN TO RUN IT
#   As part of SHIPPING version N — beside the tag and the release branch, not as
#   archaeology later. That is the one moment the binary that writes this store
#   definitely exists and definitely builds.
#
# ⚠️ THIS SCRIPT IS A NEW WRITER INTO THE SHARED-CONTAINER PROBLEM
#
#   It is not hermetic and cannot be: capturing what a binary writes means running
#   that binary on a real simulator. Two consequences, both of which have already
#   confused one run (see BRIEF_UI_SHARED_CONTAINER_RESIDUE §9):
#
#     1. It ERASES the device it targets, chosen BY NAME, without asking. If
#        another run is using that simulator — a staged repro, a suite in flight —
#        this destroys it silently.
#     2. It LEAVES the device non-pristine: the old app version installed, an
#        App Group store holding the demo seed, and whatever UserDefaults that
#        launch wrote. A test run started afterwards inherits all of it.
#
#   That is the same class of defect the UI suite has been chasing all month, and
#   this script is now one of its sources. The rule that follows:
#
#     ERASE THE SIMULATOR BEFORE A TEST RUN THAT FOLLOWS A CAPTURE.
#     A green run on an erased device and a red run on a captured-on device are
#     not the same experiment, and the difference is invisible in the output.
#
# USAGE
#   scripts/capture-store-fixture.sh <commit-ish> <label> [device-name]
#   scripts/capture-store-fixture.sh 1e9b20b V1_0_0
#   scripts/capture-store-fixture.sh v1.0.4-build8 V1_0_4 "iPhone 17 Pro Max"
#
#   Refuses to overwrite an existing fixture unless FORCE=1 — a fixture is
#   evidence, and silently replacing it destroys the only copy of what a release
#   actually wrote.
#
set -uo pipefail

COMMIT="${1:-}"
LABEL="${2:-}"
DEVICE="${3:-iPhone 17 Pro Max}"
BUNDLE_ID="com.dmitrylogachev.budgetcrab"
GROUP_ID="group.$BUNDLE_ID"

if [ -z "$COMMIT" ] || [ -z "$LABEL" ]; then
    echo "usage: $0 <commit-ish> <label> [device-name]"
    echo "   e.g. $0 1e9b20b V1_0_0"
    exit 64
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

DEST="$REPO_ROOT/StoreFixtures/Store$LABEL"
if [ -d "$DEST" ] && [ "${FORCE:-0}" != "1" ]; then
    echo "✗ $DEST already exists."
    echo "  A fixture is EVIDENCE about a released binary. Re-run with FORCE=1 only"
    echo "  if you are deliberately replacing it, and say why in its MANIFEST.md."
    exit 1
fi

WORKTREE="$(mktemp -d)/src"
DERIVED="$(mktemp -d)/dd"
cleanup() { git worktree remove "$WORKTREE" --force >/dev/null 2>&1; }
trap cleanup EXIT

echo "▶ worktree at $COMMIT"
git worktree add "$WORKTREE" "$COMMIT" >/dev/null 2>&1 || { echo "✗ could not create a worktree at $COMMIT"; exit 1; }

VERSION="$(grep -m1 "MARKETING_VERSION" "$WORKTREE/FinanceTracker.xcodeproj/project.pbxproj" | sed 's/.*= *//;s/;//')"
BUILD="$(grep -m1 "CURRENT_PROJECT_VERSION" "$WORKTREE/FinanceTracker.xcodeproj/project.pbxproj" | sed 's/.*= *//;s/;//')"
SUBJECT="$(git log -1 --format=%s "$COMMIT")"
COMMIT_DATE="$(git log -1 --format=%ci "$COMMIT")"
FULL_SHA="$(git rev-parse --short "$COMMIT")"
echo "  $FULL_SHA  version $VERSION (build $BUILD)  $COMMIT_DATE"

echo "▶ building (this is the binary whose output we are capturing)"
(cd "$WORKTREE" && xcodebuild -project FinanceTracker.xcodeproj -scheme FinanceTracker \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "$DERIVED" build >/tmp/capture-build-$$.log 2>&1)
if [ $? -ne 0 ]; then
    echo "✗ build failed — see /tmp/capture-build-$$.log"
    echo "  If an old commit no longer builds under the current Xcode, that is exactly"
    echo "  the case the COMMITTED fixtures exist for. Do not fake the fixture."
    exit 1
fi
APP="$DERIVED/Build/Products/Debug-iphonesimulator/FinanceTracker.app"
[ -d "$APP" ] || { echo "✗ no .app at $APP"; exit 1; }

UDID="$(xcrun simctl list devices available | grep -m1 "$DEVICE (" | sed 's/.*(\([0-9A-F-]*\)).*/\1/')"
[ -n "$UDID" ] || { echo "✗ no available simulator named '$DEVICE'"; exit 1; }

echo "▶ erasing $DEVICE ($UDID) — the store must be the ONLY thing this run writes"
xcrun simctl shutdown "$UDID" >/dev/null 2>&1
xcrun simctl erase "$UDID" || exit 1
xcrun simctl boot "$UDID" || exit 1
sleep 8

echo "▶ install + launch with --demo-mode (deterministic rows)"
xcrun simctl install "$UDID" "$APP" || exit 1
xcrun simctl launch "$UDID" "$BUNDLE_ID" --demo-mode >/dev/null || exit 1
sleep 18
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1

GROUP="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" "$GROUP_ID" 2>/dev/null)"
[ -n "$GROUP" ] && [ -f "$GROUP/Vela.sqlite" ] || { echo "✗ no store in the App Group container"; exit 1; }

mkdir -p "$DEST"
cp "$GROUP/Vela.sqlite" "$DEST/" || exit 1
for side in -shm -wal; do
    [ -f "$GROUP/Vela.sqlite$side" ] && cp "$GROUP/Vela.sqlite$side" "$DEST/"
done

TX="$(sqlite3 "$DEST/Vela.sqlite" "SELECT count(*) FROM ZTRANSACTION;" 2>/dev/null)"
SUM="$(sqlite3 "$DEST/Vela.sqlite" "SELECT ifnull(sum(ZAMOUNTCENTS),0) FROM ZTRANSACTION;" 2>/dev/null)"
CATS="$(sqlite3 "$DEST/Vela.sqlite" "SELECT count(*) FROM ZCATEGORY;" 2>/dev/null)"
SRCS="$(sqlite3 "$DEST/Vela.sqlite" "SELECT count(*) FROM ZSOURCE;" 2>/dev/null)"
TABLES="$(sqlite3 "$DEST/Vela.sqlite" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>/dev/null | tr '\n' ' ')"
COLS="$(sqlite3 "$DEST/Vela.sqlite" "PRAGMA table_info(ZTRANSACTION);" 2>/dev/null | awk -F'|' '{print $2}' | tr '\n' ' ')"

# A capture with zero rows is almost certainly a launch that did not settle —
# say so rather than committing an empty fixture that will pass every test.
if [ "${TX:-0}" -eq 0 ]; then
    echo "⚠  captured store has ZERO transactions. If this version supports --demo-mode,"
    echo "   the launch probably did not finish seeding. Check before committing this."
fi

cat > "$DEST/MANIFEST.md" <<EOF
# Fixture: store as written by $VERSION (build $BUILD)

**Evidence about a released binary, not a store we constructed.** Generated by
\`scripts/capture-store-fixture.sh $COMMIT $LABEL\`.

| | |
|---|---|
| commit | \`$FULL_SHA\` — $SUBJECT |
| commit date | $COMMIT_DATE |
| marketing version | \`$VERSION\` (build $BUILD) |
| captured | $(date '+%Y-%m-%d') on $DEVICE, erased simulator, \`--demo-mode\`, Debug build |
| transactions | $TX (\`sum(ZAMOUNTCENTS)\` = $SUM) |
| categories / sources | $CATS / $SRCS |
| tables | \`$TABLES\` |

\`ZTRANSACTION\` columns:

\`\`\`
$COLS
\`\`\`

## Rules

- **Never open this store in place** — an open MIGRATES it, destroying the
  property the fixture exists for. Tests stage a copy in a temp directory.
- Reading it with \`sqlite3\` rewrites the \`-shm\`/\`-wal\` sidecars; the
  \`.sqlite\` is what carries the evidence.
- To re-derive: \`FORCE=1 scripts/capture-store-fixture.sh $COMMIT $LABEL\`.
EOF

echo "✓ captured → StoreFixtures/Store$LABEL"
echo "  $TX transactions, sum $SUM, $CATS categories, $SRCS sources"
echo "  Add a case to ShippedStoreShapeTests so this shape is actually asserted on."
