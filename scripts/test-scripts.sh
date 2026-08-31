#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"

expect_usage_failure() {
  local name="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "Expected $name to fail with missing inputs" >&2
    exit 1
  fi
  if ! grep -q "Usage:" <<<"$output"; then
    echo "Expected usage text from $name" >&2
    exit 1
  fi
}

expect_usage_failure build-release env -u INSOMNIA_SIGNING_IDENTITY bash "$script_directory/build-release.sh"
expect_usage_failure notarize env -u INSOMNIA_NOTARY_PROFILE bash "$script_directory/notarize.sh"
expect_usage_failure verify-release bash "$script_directory/verify-release.sh"

echo "Release script smoke tests passed"
