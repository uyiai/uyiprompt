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

# Notarization requires every nested binary to carry OUR Developer ID
# signature with a secure timestamp. Sparkle ships with upstream signatures,
# so re-sign inside-out, then re-sign the app itself.
IDENTITY="${IDENTITY:-Developer ID Application}"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
  for nested in \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/B/Autoupdate" \
    "$SPARKLE/Versions/B/Updater.app" \
    "$SPARKLE"; do
    codesign --force --options runtime --timestamp \
      --preserve-metadata=entitlements --sign "$IDENTITY" "$nested"
  done
fi
codesign --force --options runtime --timestamp \
  --entitlements Supporting/uyiprompt.entitlements --sign "$IDENTITY" "$APP"

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

# Sparkle appcast: point generate_appcast at the folder holding the zip.
# The binary ships with the Sparkle SPM checkout pulled by the Xcode build.
GENERATE_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" "$DERIVED" -type f -name generate_appcast -path "*artifacts*" 2>/dev/null | head -1 || true)"
if [[ -n "$GENERATE_APPCAST" ]]; then
  APPCAST_DIR="$(dirname "$ZIP")"
  "$GENERATE_APPCAST" \
    --link "https://github.com/uyiai/uyiprompt" \
    --download-url-prefix "https://github.com/uyiai/uyiprompt/releases/download/v${VERSION}/" \
    "$APPCAST_DIR"
  echo "Appcast $APPCAST_DIR/appcast.xml — upload it (and the zip) to the GitHub release."
else
  echo "generate_appcast not found; build once in Xcode so SPM fetches Sparkle, then rerun."
fi
