#!/bin/bash
#
# App Store screenshots for Toehold.
#
# The rules kept here were learned the hard way and are not tool-specific:
#
#   * the pixel size is dictated by the App Store Connect slot, not by whatever
#     device the runner happens to have
#   * a screenshot is taken only once two consecutive frames are identical --
#     a fixed sleep photographs a spinner and reports success
#   * `simctl install` before `launch`, or launch fails with `code=4` and the
#     error looks exactly like "the app is missing"
#   * the size is asserted in the script, because App Store Connect infers the
#     slot from the pixels and says so only at upload time
#
# Demo mode is built into the app rather than bolted on for CI: launching with
# `-ToeholdDemo <screen>` seeds fixed data and opens straight onto that screen,
# so nothing here drives a UI. See `Core/AppEnvironment.swift`.
set -euo pipefail

APP="${APP:-build/Build/Products/Debug-iphonesimulator/Toehold.app}"
OUT="${OUT:-shots}"

# The slots, not preferences. 1284x2778 is 6.5" and 2064x2752 is 13".
PHONE_W=1284; PHONE_H=2778
TABLET_W=2064; TABLET_H=2752

# Five, in the order they will appear. The order is the pitch: what the app is,
# what it does to a stuck moment, what the result looks like.
PHONE_SCREENS=(home runner allsteps done home)
TABLET_SCREENS=(home runner allsteps)

[ -d "$APP" ] || { echo "::error::no .app at $APP"; exit 1; }

# Read from the product rather than hardcoded. A bundle id that disagrees with
# the built app makes `simctl launch` fail with `code=4`, which is the same
# error as never having installed it.
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
echo "app:    $APP"
echo "bundle: $BUNDLE_ID"
echo

dims() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null \
    | awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{print w"x"h}'
}

pick() {
  # By name, not UDID: simulator identifiers are not stable across Xcode
  # versions, so one captured in an earlier run is a device that no longer
  # exists.
  xcrun simctl list devices available -j | jq -r --arg p "$1" '
    [ .devices | to_entries[] | select(.key | test("SimRuntime.iOS-")) ]
    | sort_by(.key) | reverse
    | [ .[].value[] | select(.name | test($p)) ][0].udid // empty'
}

# macOS ships no `timeout`, and the simctl calls below are exactly the ones
# that hang: a wedged simulator makes `simctl io screenshot` return nothing and
# never exit. Without this the job sits "in progress" for the full six-hour
# default and reads like slow work rather than a stuck runner.
#
# SIGTERM first so simctl can clean up, SIGKILL if it will not.
with_timeout() {
  local secs="$1"; shift
  local rc=0
  "$@" & local pid=$!
  ( sleep "$secs"
    kill -TERM "$pid" 2>/dev/null
    sleep 5
    kill -KILL "$pid" 2>/dev/null ) & local watcher=$!
  wait "$pid" || rc=$?
  kill -TERM "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  return $rc
}

# A device only if one is creatable. Apple removes device types from newer
# runtimes, so building a 6.5" iPhone works on some runners and not others --
# and when it does not, the runner's own devices are all 6.9", which is a
# different slot. Escalating to the newest iPhone and scaling is the documented
# fallback, and the scale factor is small enough to be invisible.
make_or_borrow_phone() {
  local rt udid out dt
  rt=$(xcrun simctl list runtimes -j \
        | jq -r '[.runtimes[] | select(.platform=="iOS" and .isAvailable)][0].identifier')
  for dt in iPhone-14-Plus iPhone-13-Pro-Max iPhone-12-Pro-Max iPhone-11-Pro-Max; do
    if out=$(xcrun simctl create "shots-$dt" \
               "com.apple.CoreSimulator.SimDeviceType.$dt" "$rt" 2>&1); then
      echo "$out"; return 0
    fi
    echo "  cannot create $dt" >&2
  done
  echo "  no 6.5\" device creatable -- borrowing the newest iPhone" >&2
  pick '^iPhone 1[6-9]' || pick '^iPhone'
}

make_or_borrow_tablet() {
  local udid
  udid=$(pick '^iPad Pro 13-inch') || true
  [ -n "$udid" ] || udid=$(pick '^iPad Pro 12\.9') || true
  [ -n "$udid" ] || udid=$(pick '^iPad')
  echo "$udid"
}

# Two identical frames in a row, or no picture. A spinner changes every frame,
# so a fixed sleep returns one and the job still goes green.
wait_stable() {
  local udid="$1" out="$2" prev="" cur="" i
  for i in $(seq 1 45); do
    # Bounded per call. The loop's own 45 iterations only bound a simulator
    # that keeps answering; they do not bound one call that never returns.
    with_timeout 30 xcrun simctl io "$udid" screenshot "$out" >/dev/null 2>&1 || true
    cur=$(md5 -q "$out" 2>/dev/null || echo "")
    if [ -n "$prev" ] && [ "$cur" = "$prev" ]; then return 0; fi
    prev="$cur"
    sleep 2
  done
  return 1
}

# Always to the slot size, even when the capture was already right: `sips -z`
# is a no-op at the same size, and a capture path that sometimes scales and
# sometimes does not is one where the assertion below fails intermittently.
fit() {
  local src="$1" dst="$2" w="$3" h="$4"
  sips -z "$h" "$w" "$src" --out "$dst" >/dev/null
}

capture() {
  local udid="$1" dir="$2" kind="$3"; shift 3
  local screens=("$@")
  local w h
  if [ "$kind" = iphone ]; then w=$PHONE_W; h=$PHONE_H; else w=$TABLET_W; h=$TABLET_H; fi

  mkdir -p "$dir"
  echo "  [$kind] booting $udid"
  # bootstatus blocks until the device finishes booting, which on a cold
  # runtime is minutes -- and forever if the boot wedges. Bounded, and the
  # failure is allowed through because the install below is the real test.
  with_timeout 420 xcrun simctl bootstatus "$udid" -b 2>/dev/null \
    || echo "  note: bootstatus timed out or non-zero, continuing"

  with_timeout 180 xcrun simctl install "$udid" "$APP"   # before launch, always
  with_timeout 60 xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3

  # Warm launch, discarded. The first launch of a freshly installed app does
  # its first-run work while the screen is already up.
  with_timeout 60 xcrun simctl launch "$udid" "$BUNDLE_ID" -ToeholdDemo "${screens[0]}" >/dev/null 2>&1 || true
  wait_stable "$udid" /tmp/warm.png || echo "  note: warm-up never settled"
  with_timeout 60 xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true

  local screen raw d n=0 total=${#screens[@]}
  for screen in "${screens[@]}"; do
    n=$((n + 1))
    # Printed before the work, so a hung run says which screen hung. Without
    # it the last line is the one before the loop and every screen looks alike.
    echo "  [$kind $n/$total] $screen"
    with_timeout 60 xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    if ! with_timeout 90 xcrun simctl launch "$udid" "$BUNDLE_ID" -ToeholdDemo "$screen" > /tmp/launch.log 2>&1; then
      echo "::error::launch failed or timed out screen=$screen"; cat /tmp/launch.log; exit 1
    fi
    raw="/tmp/raw-$kind-$n.png"
    if ! wait_stable "$udid" "$raw"; then
      echo "::error::$screen never settled -- refusing to ship a spinner"; exit 1
    fi
    # Numbered rather than named: two entries are both `home`, and a filename
    # collision would silently drop one of the five.
    fit "$raw" "$dir/$(printf '%02d' "$n")-$screen.png" "$w" "$h"

    d=$(dims "$dir/$(printf '%02d' "$n")-$screen.png")
    if [ "$d" != "${w}x${h}" ]; then
      echo "::error::$screen is $d, expected ${w}x${h}"; exit 1
    fi
    echo "  ok $n-$screen -> $d"
  done
  echo "  [$kind] done"
}

PHONE=$(make_or_borrow_phone)
TABLET=$(make_or_borrow_tablet)
[ -n "$PHONE" ]  || { echo "::error::no iPhone simulator available";  exit 1; }
[ -n "$TABLET" ] || { echo "::error::no iPad simulator available";    exit 1; }
echo "phone:  $PHONE"
echo "tablet: $TABLET"
echo

capture "$PHONE"  "$OUT/iphone65" iphone "${PHONE_SCREENS[@]}"
capture "$TABLET" "$OUT/ipad13"   tablet "${TABLET_SCREENS[@]}"

echo
echo "captured:"
find "$OUT" -name '*.png' | sort | while read -r f; do echo "  $(dims "$f")  $f"; done
