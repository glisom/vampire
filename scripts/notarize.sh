#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: INSOMNIA_NOTARY_PROFILE=profile $0 /path/to/Insomnia.dmg" >&2
}

if [[ $# -ne 1 || -z "$1" || -z "${INSOMNIA_NOTARY_PROFILE:-}" ]]; then
  usage
  exit 64
fi

dmg="$1"
if [[ ! -f "$dmg" ]]; then
  echo "DMG not found: $dmg" >&2
  exit 66
fi

xcrun notarytool submit "$dmg" --keychain-profile "$INSOMNIA_NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
