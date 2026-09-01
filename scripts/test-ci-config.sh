#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
workflow="$repository_root/.github/workflows/ci.yml"

if [[ ! -f "$workflow" ]]; then
  echo "Missing GitHub Actions workflow: .github/workflows/ci.yml" >&2
  exit 1
fi

required_lines=(
  'runs-on: macos-26'
  'contents: read'
  'timeout-minutes: 30'
  'scripts/ci.sh'
)
for line in "${required_lines[@]}"; do
  if ! /usr/bin/grep -Fq "$line" "$workflow"; then
    echo "CI workflow is missing required policy: $line" >&2
    exit 1
  fi
done

if rg -n 'sudo|VAMPIRE_SIGNING_IDENTITY|VAMPIRE_NOTARY_PROFILE|notarytool|stapler|upload-artifact|SMAppService|pmset' "$workflow"; then
  echo "CI workflow contains a privileged, signing, or artifact-upload step" >&2
  exit 1
fi

echo "CI workflow policy checks passed"
