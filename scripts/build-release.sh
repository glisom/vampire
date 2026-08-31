#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: VAMPIRE_SIGNING_IDENTITY='Developer ID Application: …' $0" >&2
}

if [[ -z "${VAMPIRE_SIGNING_IDENTITY:-}" ]]; then
  usage
  exit 64
fi

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
release_root="$repository_root/build/release"
archive_path="$release_root/Vampire.xcarchive"
dmg_root="$release_root/dmg-root"
dmg_path="$release_root/Vampire.dmg"
identity="$VAMPIRE_SIGNING_IDENTITY"

mkdir -p "$release_root"
rm -rf "$archive_path" "$dmg_root"
rm -f "$dmg_path"

cd "$repository_root"
xcodegen generate
xcodebuild archive \
  -project Insomnia.xcodeproj \
  -scheme Insomnia \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$identity"

archived_app="$archive_path/Products/Applications/Vampire.app"
if [[ ! -d "$archived_app" ]]; then
  echo "Archive did not contain Vampire.app" >&2
  exit 66
fi

mkdir -p "$dmg_root"
/usr/bin/ditto "$archived_app" "$dmg_root/Vampire.app"
ln -s /Applications "$dmg_root/Applications"

helper="$dmg_root/Vampire.app/Contents/MacOS/InsomniaHelper"
/usr/bin/codesign --force --sign "$identity" --options runtime --timestamp \
  --entitlements "$repository_root/Config/InsomniaHelper.entitlements" "$helper"
/usr/bin/codesign --force --sign "$identity" --options runtime --timestamp \
  --entitlements "$repository_root/Config/Insomnia.entitlements" "$dmg_root/Vampire.app"

/usr/bin/hdiutil create \
  -fs HFS+ \
  -volname Vampire \
  -srcfolder "$dmg_root" \
  "$dmg_path"

echo "Created $dmg_path"
