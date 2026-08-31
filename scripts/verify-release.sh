#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/Vampire.dmg" >&2
}

if [[ $# -ne 1 || -z "$1" ]]; then
  usage
  exit 64
fi

dmg="$1"
if [[ ! -f "$dmg" ]]; then
  echo "DMG not found: $dmg" >&2
  exit 66
fi

mountpoint="$(mktemp -d "${TMPDIR:-/tmp}/vampire-verify.XXXXXX")"
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then
    /usr/bin/hdiutil detach "$mountpoint" >/dev/null || true
  fi
  rmdir "$mountpoint" 2>/dev/null || true
}
trap cleanup EXIT

/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$mountpoint" "$dmg" >/dev/null
mounted=true

app="$mountpoint/Vampire.app"
helper="$app/Contents/MacOS/InsomniaHelper"
main_executable="$app/Contents/MacOS/Vampire"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
/usr/bin/codesign --verify --strict --verbose=2 "$helper"
/usr/sbin/spctl --assess --type execute --verbose=2 "$app"
xcrun stapler validate "$dmg"
xcrun stapler validate "$app"

for executable in "$main_executable" "$helper"; do
  architectures="$(/usr/bin/lipo -archs "$executable")"
  grep -qw arm64 <<<"$architectures"
  grep -qw x86_64 <<<"$architectures"
done

echo "Release verification passed: $dmg"
