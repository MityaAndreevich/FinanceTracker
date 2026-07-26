#!/usr/bin/env bash
#
# capture-screenshots.sh — App Store Connect screenshot generator for Budget Crab
#
# Generates all 8 storyboard screenshots for ONE locale in a single command,
# ready for App Store Connect upload. Drives the iOS Simulator with xcrun simctl
# and the app's DEBUG-only screenshot-automation launch arguments (see
# FinanceTracker/Data/ScreenshotMode.swift and DemoSeeder.swift).
#
# Usage:
#   AppStore/capture-screenshots.sh EN
#   AppStore/capture-screenshots.sh RU
#   AppStore/capture-screenshots.sh ES
#   AppStore/capture-screenshots.sh PT-BR
#   AppStore/capture-screenshots.sh ALL          # loops every locale
#
# Overridable via env:
#   DEVICE        simulator device name      (default: "iPhone 15 Pro Max")
#   RENDER_WAIT   seconds to wait per screen (default: 6)
#   SKIP_BUILD    "1" to reuse an installed build (default: build + install)
#   TARGET_W/H    force-resize output to W×H via sips (default: native, no resize)
#
# Output: AppStore/screenshots/<LOCALE>/01_dashboard.png … 08_lifetime.png
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SCHEME="FinanceTracker"
BUNDLE_ID="com.dmitrylogachev.budgetcrab"
DEVICE_NAME="${DEVICE:-iPhone 16 Pro Max}"   # 6.9" canvas, 1320 × 2868 (ASC primary size)
RENDER_WAIT="${RENDER_WAIT:-6}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="$REPO_ROOT/build/screenshots"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/FinanceTracker.app"

# Storyboard order: "<screen-id>:<output-filename>" (see screenshots-storyboard.md)
# 1.0.3 shelf: 05/06 now carry the two new features (split purchases + gentle
# category limits), replacing 05_categories / 06_faceid. Both retired screens are
# still routable (`--screenshot-screen categories|lock`) for ad-hoc captures.
SCREENS=(
  "dashboard:01_dashboard"
  "privacy:02_privacy"
  "quickentry:03_quickentry"
  "analytics:04_analytics"
  "split:05_split"
  "categorylimit:06_limits"
  "export:07_export"
  "lifetime:08_lifetime"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[0;36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '\033[0;32m✓ %s\033[0m\n' "$*"; }
die()  { printf '\033[0;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Map a UI locale → (seed json code, AppleLanguages code, AppleLocale, keyboard).
# Currency is driven by the seed JSON, not here: RUB/EUR/BRL/USD.
# KB is an AppleKeyboards entry: the "sw=" software layout drives the on-screen
# keyboard. es_ES (Spain, ñ) not es_MX; pt_BR (Brazilian, ç) not pt_PT.
resolve_locale() {
  case "$(echo "$1" | tr '[:lower:]' '[:upper:]')" in
    EN)            SEED=en;    LANG_CODE=en;    APPLE_LOCALE=en_US; KB="en_US@sw=QWERTY;hw=Automatic" ;;
    RU)            SEED=ru;    LANG_CODE=ru;    APPLE_LOCALE=ru_RU; KB="ru_RU@sw=Russian;hw=Automatic" ;;
    ES)            SEED=es;    LANG_CODE=es;    APPLE_LOCALE=es_ES; KB="es_ES@sw=Spanish;hw=Automatic" ;;
    PT-BR|PTBR|PT) SEED=pt-BR; LANG_CODE=pt-BR; APPLE_LOCALE=pt_BR; KB="pt_BR@sw=Portuguese-Brazilian;hw=Automatic" ;;
    UK|UA)         SEED=uk;    LANG_CODE=uk;    APPLE_LOCALE=uk_UA; KB="uk_UA@sw=Ukrainian;hw=Automatic" ;;
    *) die "Unknown locale '$1' (use EN | RU | ES | PT-BR | UK | ALL)" ;;
  esac
}

# Force the on-screen keyboard to the locale's layout. Installing only the
# target layout (+ emoji) leaves iOS no other input source to fall back to, so
# the next app launch renders that keyboard. Without this the simulator keeps
# the last-used input source (e.g. Russian leaking into es/pt-BR screenshots).
set_keyboard() {
  xcrun simctl spawn "$UDID" defaults write -g AppleKeyboards -array "$KB" "emoji@sw=Emoji"
  xcrun simctl spawn "$UDID" defaults write -g AppleKeyboardsExpanded -int 1
  # Flush the prefs daemon so the next launch reads the new value, not a cache.
  xcrun simctl spawn "$UDID" killall cfprefsd >/dev/null 2>&1 || true
}

boot_device() {
  UDID="$(xcrun simctl list devices available \
          | grep -m1 "$DEVICE_NAME (" \
          | grep -oE '[0-9A-Fa-f-]{36}' || true)"
  if [ -z "${UDID:-}" ]; then
    echo "Available Pro Max simulators:" >&2
    xcrun simctl list devices available | grep -i "Pro Max" >&2 || true
    die "Simulator '$DEVICE_NAME' not installed. Set DEVICE=... or install it via Xcode › Settings › Components. (iPhone 16 Pro Max is 6.9\" — also ASC-valid.)"
  fi
  log "Booting $DEVICE_NAME ($UDID)"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  # Force DARK for the premium capture look. The app default is now System
  # (respects the device), so we pin the simulator to dark; each launch also
  # passes -appearanceMode dark as a belt-and-suspenders override.
  xcrun simctl ui "$UDID" appearance dark 2>/dev/null || true
  # Clean, deterministic status bar: 9:41, full battery/signal.
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 2>/dev/null || true
}

build_and_install() {
  if [ "${SKIP_BUILD:-0}" = "1" ] && [ -d "$APP_PATH" ]; then
    log "SKIP_BUILD=1 — reusing $APP_PATH"
  else
    log "Building Debug (demo mode is DEBUG-only) for $DEVICE_NAME"
    xcodebuild -scheme "$SCHEME" -configuration Debug \
      -destination "id=$UDID" -derivedDataPath "$DERIVED" \
      build >/dev/null
  fi
  [ -d "$APP_PATH" ] || die "Build product missing at $APP_PATH"
  # Uninstall first — installing OVER an existing app keeps its container, and a
  # container left by an older build carries a V1 store. `needsGuardedMigration`
  # is (storeFileExists && !isMigrationComplete), so every launch would open on
  # the pre-migration consent screen (LaunchGateView) and EVERY frame would be
  # that screen instead of the app. Wiping the container also clears the stale
  # `appLanguageCode` that used to leak the previous locale into a capture.
  log "Uninstalling any previous container (avoids the V1 pre-migration gate)"
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  log "Installing app"
  xcrun simctl install "$UDID" "$APP_PATH"
}

# ASC normalization: App Store Connect rejects PNGs that carry an alpha channel,
# so flatten RGBA → RGB. Prefer Pillow (lossless); fall back to a sips JPEG
# round-trip (built-in, slightly lossy) if Pillow is unavailable. Optionally
# resize to TARGET_W × TARGET_H.
normalize_for_asc() {
  local file="$1"
  if python3 - "$file" "${TARGET_W:-}" "${TARGET_H:-}" <<'PY' 2>/dev/null
import sys
try:
    from PIL import Image
except Exception:
    sys.exit(1)
path, tw, th = sys.argv[1], sys.argv[2], sys.argv[3]
im = Image.open(path).convert("RGB")  # drops alpha losslessly
if tw and th:
    im = im.resize((int(tw), int(th)), Image.LANCZOS)
im.save(path)
PY
  then
    return 0
  fi
  # Fallback: sips JPEG round-trip strips the alpha channel.
  command -v sips >/dev/null || { echo "  (warning: could not strip alpha from $file)" >&2; return 0; }
  local tmp="${file%.png}.flatten.jpg"
  sips -s format jpeg "$file" --out "$tmp" >/dev/null 2>&1 || return 0
  sips -s format png "$tmp" --out "$file" >/dev/null 2>&1 || true
  rm -f "$tmp"
  if [ -n "${TARGET_W:-}" ] && [ -n "${TARGET_H:-}" ]; then
    sips -z "$TARGET_H" "$TARGET_W" "$file" >/dev/null 2>&1 || true
  fi
}

capture_locale() {
  local locale="$1"
  resolve_locale "$locale"
  local out_dir="$REPO_ROOT/AppStore/screenshots/$locale"
  mkdir -p "$out_dir"
  log "Capturing $locale (seed=$SEED, $APPLE_LOCALE) → $out_dir"
  log "Keyboard → $KB"
  set_keyboard

  for entry in "${SCREENS[@]}"; do
    local screen="${entry%%:*}"
    local name="${entry##*:}"
    local out="$out_dir/$name.png"

    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    # Quick Entry (frame 03) preloads a parsed transaction so the capture shows the
    # populated parsed-preview state, not the bare idle. DEBUG-only launch flag.
    local qe_flag=""
    [ "$screen" = "quickentry" ] && qe_flag="--screenshot-quickentry-parsed"
    # Each launch wipes + re-seeds the locale demo data, then routes to one screen.
    # -appLanguageCode drives the app's in-app language override (LocalizedBundle),
    # which is what actually localizes UI chrome. -AppleLanguages alone only affects
    # OS-level date/number formatting, leaving chrome in the dev-region (English).
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
      --demo-mode-debug-only --demo-locale "$SEED" --screenshot-screen "$screen" $qe_flag \
      -AppleLanguages "($LANG_CODE)" -AppleLocale "$APPLE_LOCALE" \
      -appLanguageCode "$LANG_CODE" \
      -appearanceMode dark \
      -hasCompletedOnboarding 1 -hasSeenFeatureTour 1 -requireAuthMode never \
      >/dev/null
    sleep "$RENDER_WAIT"
    xcrun simctl io "$UDID" screenshot "$out" >/dev/null
    normalize_for_asc "$out"
    ok "$name"
  done

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  ok "$locale complete — 8 screenshots in $out_dir"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
INPUT="${1:-${LOCALE:-EN}}"

boot_device
build_and_install

if [ "$(echo "$INPUT" | tr '[:lower:]' '[:upper:]')" = "ALL" ]; then
  for L in EN RU ES PT-BR UK; do capture_locale "$L"; done
else
  capture_locale "$INPUT"
fi

# Restore the simulator status bar to its live values.
xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
ok "Done. Upload from AppStore/screenshots/<LOCALE>/ to App Store Connect."
