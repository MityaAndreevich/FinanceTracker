#!/usr/bin/env bash
# Sample memory pressure and machine quietness while a test run is alive.
#
#   scripts/machine-sampler.sh <out-file> [interval-seconds, default 30]
#
# Why (2026-10-12, D33): `vm.swapusage` "used" is RESIDUE, not activity. A run
# peaked at 13.9 GB swap in its unit phase and still read 3-4 GB, falling,
# through the UI phase, which says nothing about whether the machine was paging
# at the moment a UI test went red. Page-ins/page-outs PER INTERVAL do. The
# 2-min sampler of that run also counted two xcodebuild processes once and could
# not say whose; this one logs every xcodebuild's project and action.
#
# Runs until no `xcodebuild` has been alive for two consecutive samples (so it
# can be started just before run-tests.sh). One line per sample:
#   HH:MM:SS swap_used_mb=… pageins=… pageouts=… swapins=… swapouts=… booted=… sim_app=… xcb=N
#     xcb: <pid> <project> <action>        (one per xcodebuild)
# pageins..swapouts are deltas in PAGES (16 KB on Apple silicon) since the last sample.
set -u
OUT="${1:?usage: machine-sampler.sh <out-file> [interval]}"
INTERVAL="${2:-30}"

vm() { vm_stat | awk -v k="$1" -F: '$1==k {gsub(/[ .]/,"",$2); print $2}'; }
read_counters() { echo "$(vm Pageins) $(vm Pageouts) $(vm Swapins) $(vm Swapouts)"; }

read -r pi po si so <<<"$(read_counters)"
idle=0
while :; do
  sleep "$INTERVAL"
  read -r npi npo nsi nso <<<"$(read_counters)"
  swap=$(sysctl -n vm.swapusage | awk '{for(i=1;i<=NF;i++) if($i=="used") {gsub(/M/,"",$(i+2)); print $(i+2)}}')
  booted=$(xcrun simctl list devices booted 2>/dev/null | grep -c Booted)
  simapp=$(pgrep -x Simulator >/dev/null && echo 1 || echo 0)
  xcb=$(pgrep -x xcodebuild | wc -l | tr -d ' ')
  {
    echo "$(date +%H:%M:%S) swap_used_mb=$swap pageins=$((npi-pi)) pageouts=$((npo-po)) swapins=$((nsi-si)) swapouts=$((nso-so)) booted=$booted sim_app=$simapp xcb=$xcb"
    for p in $(pgrep -x xcodebuild); do
      args=$(ps -o args= -p "$p" 2>/dev/null)
      proj=$(grep -oE '[^ /]+\.xcodeproj' <<<"$args" | head -1)
      act=$(grep -oE '(^| )(test|build|build-for-testing|test-without-building|archive)( |$)' <<<"$args" | tr -d ' ' | head -1)
      echo "  xcb: $p ${proj:-?} ${act:-?}"
    done
  } >> "$OUT"
  pi=$npi; po=$npo; si=$nsi; so=$nso
  if [ "$xcb" -eq 0 ]; then idle=$((idle+1)); [ "$idle" -ge 2 ] && break; else idle=0; fi
done
