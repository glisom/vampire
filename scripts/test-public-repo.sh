#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
production_script="$script_directory/check-public-repo.sh"

bash "$production_script"

fixture="$(mktemp -d "${TMPDIR:-/tmp}/vampire-public-repo.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/Insomnia" "$fixture/InsomniaHelper/Sources" "$fixture/InsomniaShared"
cp "$production_script" "$fixture/scripts/check-public-repo.sh"
touch "$fixture/LICENSE" "$fixture/README.md" "$fixture/CONTRIBUTING.md" "$fixture/SECURITY.md"
mkdir -p "$fixture/docs"
touch "$fixture/docs/privacy.md"

git -C "$fixture" init -q
git -C "$fixture" config user.name 'Vampire Tests'
git -C "$fixture" config user.email 'tests@example.invalid'
git -C "$fixture" add .
git -C "$fixture" commit -qm 'test fixture'

for normal_path in docs/mycredentials.json secrets-notes.md; do
  touch "$fixture/$normal_path"
  git -C "$fixture" add -- "$normal_path"
done
if ! (cd "$fixture" && bash scripts/check-public-repo.sh); then
  echo "Expected normal filenames containing related text to pass" >&2
  exit 1
fi
git -C "$fixture" reset -q HEAD -- docs/mycredentials.json secrets-notes.md
rm -f "$fixture/docs/mycredentials.json" "$fixture/secrets-notes.md"

for credential_like_path in .env.local credentials.json secrets.yml; do
  touch "$fixture/$credential_like_path"
  git -C "$fixture" add -- "$credential_like_path"
  if output=$(cd "$fixture" && bash scripts/check-public-repo.sh 2>&1); then
    echo "Expected tracked credential-like filename to fail: $credential_like_path" >&2
    exit 1
  fi
  /usr/bin/grep -q 'Tracked credential-like filename found' <<<"$output"
  git -C "$fixture" reset -q HEAD -- "$credential_like_path"
  rm -f "$fixture/$credential_like_path"
done

echo "Public repository policy regression tests passed"
