#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source packaging/version.env
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit or stash changes before a release build' >&2; exit 1; }
export MACOSX_DEPLOYMENT_TARGET=13.0
app=build/release/DrinkWater.app
# Only remove this script's generated app bundle.
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
  swift build -c release --arch "$arch" --scratch-path ".build/release-$arch"
done
arm_path=$(swift build -c release --arch arm64 --scratch-path .build/release-arm64 --show-bin-path)
intel_path=$(swift build -c release --arch x86_64 --scratch-path .build/release-x86_64 --show-bin-path)
lipo -create "$arm_path/DrinkWater" "$intel_path/DrinkWater" -output "$app/Contents/MacOS/DrinkWater"
chmod 755 "$app/Contents/MacOS/DrinkWater"
cp packaging/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
plutil -lint "$app/Contents/Info.plist"
lipo "$app/Contents/MacOS/DrinkWater" -verify_arch arm64 x86_64
# Remove Finder metadata copied from source files before signing.
xattr -cr "$app"
# Local preview only. Public distribution must replace this ad-hoc signature.
codesign --force --sign - "$app"
xattr -cr "$app"
codesign --verify --deep --strict --verbose=2 "$app"
git rev-parse HEAD > build/release/source-commit.txt
swift --version > build/release/toolchain.txt
printf 'Built %s (%s): %s\n' "$VERSION" "$BUILD_NUMBER" "$app"
