#!/bin/sh
# Captures App Store screenshots on 6.9" iPhone and 13" iPad simulators into ./screenshots.
set -e
cd "$(dirname "$0")/.."
rm -rf screenshots && mkdir -p screenshots
for device in "iPhone 17 Pro Max" "iPad Pro 13-inch (M5)"; do
  # Newest runtime that has this device.
  udid=$(xcrun simctl list devices available | grep -F "    $device (" | tail -1 | grep -oE '[0-9A-F-]{36}')
  bundle="screenshots/$(echo "$device" | tr -cd '[:alnum:]').xcresult"
  TEST_RUNNER_SCREENSHOTS=1 xcodebuild test -project GetSmarter.xcodeproj -scheme GetSmarter \
    -destination "id=$udid" \
    -only-testing:GetSmarterUITests/ScreenshotTests -resultBundlePath "$bundle" CODE_SIGNING_ALLOWED=NO -quiet
  out="screenshots/$(echo "$device" | tr -cd '[:alnum:]')"
  mkdir -p "$out"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$out"
  # Rename UUID files to their attachment names (01-menu.png, …).
  python3 - "$out" <<'PY'
import json, os, sys
out = sys.argv[1]
for test in json.load(open(os.path.join(out, "manifest.json"))):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"].split("_")[0] + ".png"
        os.rename(os.path.join(out, a["exportedFileName"]), os.path.join(out, name))
PY
done
echo "Screenshots in ./screenshots"
