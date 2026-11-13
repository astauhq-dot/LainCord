#!/bin/bash
# Execute on macOS with Xcode installed. Produces an unsigned iPhone .ipa.
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED_DIR="${RUNNER_TEMP:-/tmp}/LainCordDerived"
xcodebuild \
  -project LainCord.xcodeproj \
  -scheme LainCord \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  build
APP="$DERIVED_DIR/Build/Products/Release-iphoneos/LainCord.app"
if [[ ! -f "$APP/LainCord" ]]; then
  echo 'Compilation sans application iPhone produite.' >&2
  exit 1
fi
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
rm -f LainCord-unsigned.ipa
(cd "$OUT_DIR" && /usr/bin/zip -qry "$OLDPWD/LainCord-unsigned.ipa" Payload)
echo 'IPA cree : LainCord-unsigned.ipa'
