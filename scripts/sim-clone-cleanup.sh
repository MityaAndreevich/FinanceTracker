#!/usr/bin/env bash
# Remove the simulator clones that `xcodebuild test` leaves behind.
#
# Why (2026-10-04): the disk filled to 93% with no visible cause. Every parallel
# test run clones simulators into ~/Library/Developer/XCTestDevices, and an
# interrupted run (a killed agent, ^C) never deletes them. Worse, deleting a
# device only *moves* it to $TMPDIR/Deleting-<UUID>; CoreSimulator is meant to
# purge those in the background and often never does: 397 of them sat under
# /private/var/folders, where no ordinary disk scan looks. Removing them freed
# ~34 GB. The purge stalls on files with the user-immutable flag (uchg) --
# Budget Crab's StoreBackup marks its backups immutable, and migration tests
# leave them inside the simulator -- so clear the flag before deleting.
#
# Called from an EXIT trap in each test script; safe to run by hand any time.
# Never touches regular simulators (the default device set) or runtimes.
set -u

# Clones belong to whichever xcodebuild is running. Another worktree may be
# mid-run, so only delete the clone set when no xcodebuild is alive.
if ! pgrep -x xcodebuild >/dev/null 2>&1; then
  xcrun simctl --set testing delete all >/dev/null 2>&1 || true
fi

# Already-deleted devices waiting for CoreSimulator's purge. The age floor only
# avoids racing a move that is still in progress.
# SIM_CLONE_TMPDIR: commissioning seam only, so the rm -rf below can be shown to
# hit ONLY old Deleting-* folders in a scratch directory (2026-10-11).
TMP="${SIM_CLONE_TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)}"
if [ -n "$TMP" ] && [ -d "$TMP" ]; then
  # One folder at a time: two `-exec {} +` batches in one find have no
  # guaranteed order, and rm before chflags leaves the folder behind.
  find "$TMP" -mindepth 1 -maxdepth 1 -type d -name 'Deleting-*' -mmin +30 -print0 |
    while IFS= read -r -d '' d; do
      chflags -R nouchg "$d" 2>/dev/null
      rm -rf "$d" 2>/dev/null
    done
fi
exit 0
