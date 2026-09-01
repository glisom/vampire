#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
cd "$repository_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "Required scanner not found: rg; public repository policy scan incomplete" >&2
  exit 127
fi

run_forbidden_rg_scan() {
  failure_message="$1"
  scan_description="$2"
  shift 2

  scan_status=0
  rg "$@" || scan_status=$?
  case "$scan_status" in
    0)
      echo "$failure_message" >&2
      exit 1
      ;;
    1)
      return 0
      ;;
    *)
      echo "Public repository policy scan failed: $scan_description (rg exit $scan_status); publication blocked" >&2
      exit "$scan_status"
      ;;
  esac
}

required_files=(LICENSE README.md CONTRIBUTING.md SECURITY.md docs/privacy.md)
for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing required public file: $path" >&2
    exit 1
  fi
done

if [[ -e KICKOFF.md ]]; then
  echo "KICKOFF.md is private-session material and must not be published" >&2
  exit 1
fi

tracked_inventory="$(mktemp "${TMPDIR:-/tmp}/vampire-tracked-files.XXXXXX")"
trap 'rm -f "$tracked_inventory"' EXIT

inventory_status=0
git ls-files > "$tracked_inventory" || inventory_status=$?
if [[ "$inventory_status" -ne 0 ]]; then
  echo "Tracked-file inventory failed (git ls-files exit $inventory_status); publication blocked" >&2
  exit "$inventory_status"
fi

credential_filename_status=0
/usr/bin/grep -Eiq '\.(p12|pfx|key|pem|cer|mobileprovision|provisionprofile)$|(^|/)(\.env|credentials|secrets?)([./]|$)' "$tracked_inventory" || credential_filename_status=$?
case "$credential_filename_status" in
  0)
    echo "Tracked credential-like filename found" >&2
    exit 1
    ;;
  1)
    ;;
  *)
    echo "Tracked credential filename scan failed (grep exit $credential_filename_status); publication blocked" >&2
    exit "$credential_filename_status"
    ;;
esac

run_forbidden_rg_scan \
  "Current Markdown contains private machine-run details" \
  "private machine detail scan" \
  -n '/Users/[A-Za-z0-9._-]+|Grant Isom / [C]odex|Apple [M]5|PID [0-9]+' \
  --glob '*.md' --hidden --glob '!.git/**' .

run_forbidden_rg_scan \
  "Current tree contains a credential-like value" \
  "credential value scan" \
  -l --regexp='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}' \
  --hidden --glob '!.git/**' .

run_forbidden_rg_scan \
  "Privileged helper contains a forbidden shell execution path" \
  "privileged helper shell execution scan" \
  -n '/bin/(sh|bash|zsh)|system\(|popen\(' InsomniaHelper/Sources

run_forbidden_rg_scan \
  "Runtime source exceeds Vampire's offline product boundary" \
  "offline product boundary scan" \
  -n 'URLSession|Network\.framework|import Network|Sparkle|Telemetry|Analytics' Insomnia InsomniaHelper InsomniaShared

echo "Public repository policy checks passed"
