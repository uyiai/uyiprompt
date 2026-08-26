#!/usr/bin/env bash
# Local Release: build, zip, optionally notarize + staple.
# Usage:
#   scripts/release.sh
#   NOTARY_PROFILE=uyiprompt-notary scripts/release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(python3 - <<'PY'
import re, pathlib
text = pathlib.Path("uyiprompt.xcodeproj/project.pbxproj").read_text()
match = re.search(r"MARKETING_VERSION = ([0-9.]+);", text)
print(match.group(1) if match else "dev")
PY
)"

DERIVED="${DERIVED:-/tmp/uyiprompt-DerivedData}"
APP="$DERIVED/Build/Products/Release/uyiprompt.app"
ZIP="${ZIP:-/tmp/uyiprompt-${VERSION}.zip}"

xcodebuild -project uyiprompt.xcodeproj -scheme uyiprompt \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" build

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built $APP"
echo "Zip    $ZIP"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
codesign --verify --deep --strict "$APP"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "Submitting to notary with keychain profile $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Notarized and stapled $ZIP"
else
  echo "Skip notary (set NOTARY_PROFILE to a notarytool keychain profile)."
fi
