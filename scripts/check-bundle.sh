#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/Insomnia.app" >&2
}

if [[ $# -ne 1 || -z "$1" ]]; then
  usage
  exit 64
fi

app="$1"
helper_directory="$app/Contents/Library/LaunchDaemons"
helper="$app/Contents/MacOS/InsomniaHelper"
daemon_plist="$helper_directory/co.groundwork-ai.insomnia.helper.plist"

if [[ ! -d "$app" || ! -x "$helper" || ! -f "$daemon_plist" ]]; then
  echo "Invalid Insomnia app bundle: $app" >&2
  exit 66
fi

/usr/bin/plutil -lint "$app/Contents/Info.plist" "$daemon_plist"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"

if [[ -e "$helper_directory/InsomniaHelper" || -e "$app/Contents/Resources/InsomniaHelper" ]]; then
  echo "Unexpected duplicate helper outside Contents/MacOS" >&2
  exit 65
fi

echo "Bundle check passed: $app"
