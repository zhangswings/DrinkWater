#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/version.env
[[ -z "$(git status --porcelain)" ]] || { echo 'Release checkout must be clean' >&2; exit 1; }
[[ "$(cat build/release/source-commit.txt)" == "$(git rev-parse HEAD)" ]] || { echo 'Rebuild from current commit' >&2; exit 1; }
app=build/release/DrinkWater.app
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a configured notarytool keychain profile}"
[[ -d "$app" ]] || { echo 'Run scripts/build-release.sh first' >&2; exit 1; }
[[ "$SIGN_IDENTITY" == 'Developer ID Application:'* ]] || { echo 'Developer ID Application identity required' >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$BUILD_NUMBER" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == "$BUNDLE_ID" ]]
lipo "$app/Contents/MacOS/DrinkWater" -verify_arch arm64 x86_64
base="DrinkWater-$VERSION-macos-universal"
out="dist/$VERSION"
[[ ! -e "$out" ]] || { echo "Output exists: $out; inspect before retrying" >&2; exit 1; }
mkdir -p "$out" build/release/notary
notarize() {
  local input="$1" label="$2" result="build/release/notary/$2.json"
  xcrun notarytool submit "$input" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$result"
  [[ "$(plutil -extract status raw -o - "$result")" == Accepted ]] || {
    echo "Notarization not accepted; inspect $result and retrieve notarytool log before retrying" >&2; exit 1;
  }
}
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" build/release/notary/application.zip
notarize build/release/notary/application.zip application
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=4 "$app"
rm -rf build/release/zip-root build/release/dmg-root
mkdir -p build/release/zip-root build/release/dmg-root
ditto "$app" build/release/zip-root/DrinkWater.app
cp LICENSE build/release/zip-root/LICENSE.txt
ditto -c -k --sequesterRsrc build/release/zip-root "$out/$base.zip"
ditto "$app" build/release/dmg-root/DrinkWater.app
cp LICENSE build/release/dmg-root/LICENSE.txt
ln -s /Applications build/release/dmg-root/Applications
hdiutil create -volname DrinkWater -srcfolder build/release/dmg-root -ov -format UDZO "$out/$base.dmg"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$out/$base.dmg"
notarize "$out/$base.dmg" disk-image
xcrun stapler staple "$out/$base.dmg"
xcrun stapler validate "$out/$base.dmg"
codesign --verify --strict --verbose=2 "$out/$base.dmg"
(cd "$out" && shasum -a 256 "$base.zip" "$base.dmg" > SHA256SUMS.txt)
printf 'Ready for download testing: %s\n' "$out"
