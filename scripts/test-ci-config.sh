#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
workflow="$repository_root/.github/workflows/ci.yml"
production_script="$script_directory/test-ci-config.sh"

if [[ ! -f "$workflow" ]]; then
  echo "Missing GitHub Actions workflow: .github/workflows/ci.yml" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "Required scanner not found: rg; CI workflow policy scan incomplete" >&2
  exit 127
fi

required_lines=(
  'runs-on: macos-26'
  'contents: read'
  'timeout-minutes: 30'
  'scripts/ci.sh'
)
for line in "${required_lines[@]}"; do
  required_line_status=0
  /usr/bin/grep -Fq "$line" "$workflow" || required_line_status=$?
  case "$required_line_status" in
    0)
      ;;
    1)
      echo "CI workflow is missing required policy: $line" >&2
      exit 1
      ;;
    *)
      echo "CI workflow required-policy scan failed for '$line' (grep exit $required_line_status); validation blocked" >&2
      exit "$required_line_status"
      ;;
  esac
done

scan_status=0
rg -n 'sudo|VAMPIRE_SIGNING_IDENTITY|VAMPIRE_NOTARY_PROFILE|notarytool|stapler|upload-artifact|SMAppService|pmset' "$workflow" || scan_status=$?
case "$scan_status" in
  0)
    echo "CI workflow contains a privileged, signing, or artifact-upload step" >&2
    exit 1
    ;;
  1)
    ;;
  *)
    echo "CI workflow policy scan failed (rg exit $scan_status); validation blocked" >&2
    exit "$scan_status"
    ;;
esac

if [[ "${VAMPIRE_CI_CONFIG_SCANNER_CHILD:-0}" != "1" ]]; then
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/vampire-ci-config.XXXXXX")"
  trap 'rm -rf "$fixture"' EXIT
  regression_failures=0

  scanner_error_bin="$fixture/scanner-error-bin"
  mkdir -p "$scanner_error_bin"
  printf '#!/bin/bash\nexit 2\n' > "$scanner_error_bin/rg"
  chmod +x "$scanner_error_bin/rg"
  if output=$(VAMPIRE_CI_CONFIG_SCANNER_CHILD=1 PATH="$scanner_error_bin:$PATH" /bin/bash "$production_script" 2>&1); then
    echo "Expected an rg status 2 failure to block CI config validation" >&2
    regression_failures=$((regression_failures + 1))
  elif ! /usr/bin/grep -q 'rg exit 2' <<<"$output"; then
    echo "CI config rg status 2 failure did not report a safe scanner diagnostic" >&2
    regression_failures=$((regression_failures + 1))
  fi

  missing_rg_bin="$fixture/missing-rg-bin"
  mkdir -p "$missing_rg_bin"
  ln -s /usr/bin/dirname "$missing_rg_bin/dirname"
  if output=$(VAMPIRE_CI_CONFIG_SCANNER_CHILD=1 PATH="$missing_rg_bin" /bin/bash "$production_script" 2>&1); then
    echo "Expected a missing rg executable to block CI config validation" >&2
    regression_failures=$((regression_failures + 1))
  elif ! /usr/bin/grep -q 'Required scanner not found: rg' <<<"$output"; then
    echo "CI config missing rg failure did not report a safe scanner diagnostic" >&2
    regression_failures=$((regression_failures + 1))
  fi

  if [[ "$regression_failures" -ne 0 ]]; then
    echo "$regression_failures CI config scanner regression(s) failed" >&2
    exit 1
  fi
fi

echo "CI workflow policy checks passed"
