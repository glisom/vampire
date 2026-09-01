#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
cd "$repository_root"

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

if git ls-files | /usr/bin/grep -Eiq '\.(p12|pfx|key|pem|cer|mobileprovision|provisionprofile)$|(^|/)(\.env($|\.)|credentials|secrets?)(/|$)'; then
  echo "Tracked credential-like filename found" >&2
  exit 1
fi

if rg -n '/Users/[A-Za-z0-9._-]+|Grant Isom / [C]odex|Apple [M]5|PID [0-9]+' --glob '*.md' .; then
  echo "Current Markdown contains private machine-run details" >&2
  exit 1
fi

if rg -l --regexp='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}' .; then
  echo "Current tree contains a credential-like value" >&2
  exit 1
fi

if rg -n '/bin/(sh|bash|zsh)|system\(|popen\(' InsomniaHelper/Sources; then
  echo "Privileged helper contains a forbidden shell execution path" >&2
  exit 1
fi

if rg -n 'URLSession|Network\.framework|import Network|Sparkle|Telemetry|Analytics' Insomnia InsomniaHelper InsomniaShared; then
  echo "Runtime source exceeds Vampire's offline product boundary" >&2
  exit 1
fi

echo "Public repository policy checks passed"
