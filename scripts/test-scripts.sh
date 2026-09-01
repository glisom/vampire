#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"

expect_usage_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local output
  if output=$("$@" 2>&1); then
    echo "Expected $name to fail with missing inputs" >&2
    exit 1
  fi
  if ! grep -q "Usage:" <<<"$output"; then
    echo "Expected usage text from $name" >&2
    exit 1
  fi
  if ! grep -q "$expected" <<<"$output"; then
    echo "Expected Vampire-branded usage text from $name" >&2
    exit 1
  fi
}

expect_usage_failure build-release VAMPIRE_SIGNING_IDENTITY env -u VAMPIRE_SIGNING_IDENTITY -u INSOMNIA_SIGNING_IDENTITY bash "$script_directory/build-release.sh"
expect_usage_failure notarize VAMPIRE_NOTARY_PROFILE env -u VAMPIRE_NOTARY_PROFILE -u INSOMNIA_NOTARY_PROFILE bash "$script_directory/notarize.sh"
expect_usage_failure verify-release Vampire.dmg bash "$script_directory/verify-release.sh"

if [[ -n "${VAMPIRE_NOTARIZED_DMG:-}" ]]; then
  bash "$script_directory/verify-release.sh" "$VAMPIRE_NOTARIZED_DMG"
fi

bash "$script_directory/test-release-assets.sh"

echo "Release script smoke tests passed"
