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

regression_failures=0

mkdir -p "$fixture/.github/workflows"
printf 'credential: AKIA%s\n' 'ABCDEFGHIJKLMNOP' > "$fixture/.github/workflows/hidden-policy-fixture.yml"
git -C "$fixture" add -- .github/workflows/hidden-policy-fixture.yml
if output=$(cd "$fixture" && bash scripts/check-public-repo.sh 2>&1); then
  echo "Expected a credential-like value in a hidden tracked file to fail" >&2
  regression_failures=$((regression_failures + 1))
elif ! /usr/bin/grep -q 'Current tree contains a credential-like value' <<<"$output"; then
  echo "Hidden tracked file failure did not report the credential policy" >&2
  regression_failures=$((regression_failures + 1))
fi
git -C "$fixture" reset -q HEAD -- .github/workflows/hidden-policy-fixture.yml
rm -f "$fixture/.github/workflows/hidden-policy-fixture.yml"

printf '/build/\n' > "$fixture/.gitignore"
git -C "$fixture" add -- .gitignore
git -C "$fixture" commit -qm 'ignore generated output'
mkdir -p "$fixture/build"
printf 'credential: AKIA%s\n' 'QRSTUVWXYZABCDEF' > "$fixture/build/ignored-generated-output.txt"
if ! (cd "$fixture" && bash scripts/check-public-repo.sh >/dev/null); then
  echo "Expected ignored generated output to remain outside publication scans" >&2
  regression_failures=$((regression_failures + 1))
fi

scanner_error_bin="$fixture/scanner-error-bin"
mkdir -p "$scanner_error_bin"
printf '#!/bin/bash\nexit 2\n' > "$scanner_error_bin/rg"
chmod +x "$scanner_error_bin/rg"
if output=$(cd "$fixture" && PATH="$scanner_error_bin:$PATH" bash scripts/check-public-repo.sh 2>&1); then
  echo "Expected an rg status 2 failure to block publication" >&2
  regression_failures=$((regression_failures + 1))
elif ! /usr/bin/grep -q 'rg exit 2' <<<"$output"; then
  echo "rg status 2 failure did not report a safe scanner diagnostic" >&2
  regression_failures=$((regression_failures + 1))
fi

missing_rg_bin="$fixture/missing-rg-bin"
mkdir -p "$missing_rg_bin"
ln -s /usr/bin/dirname "$missing_rg_bin/dirname"
if output=$(cd "$fixture" && PATH="$missing_rg_bin" /bin/bash scripts/check-public-repo.sh 2>&1); then
  echo "Expected a missing rg executable to block publication" >&2
  regression_failures=$((regression_failures + 1))
elif ! /usr/bin/grep -q 'Required scanner not found: rg' <<<"$output"; then
  echo "Missing rg failure did not report a safe scanner diagnostic" >&2
  regression_failures=$((regression_failures + 1))
fi

inventory_error_bin="$fixture/inventory-error-bin"
mkdir -p "$inventory_error_bin"
printf '#!/bin/bash\nif [[ "$1" == "ls-files" ]]; then\n  exit 2\nfi\nexec /usr/bin/git "$@"\n' > "$inventory_error_bin/git"
chmod +x "$inventory_error_bin/git"
if output=$(cd "$fixture" && PATH="$inventory_error_bin:$PATH" bash scripts/check-public-repo.sh 2>&1); then
  echo "Expected a git ls-files failure to block publication" >&2
  regression_failures=$((regression_failures + 1))
elif ! /usr/bin/grep -q 'git ls-files exit 2' <<<"$output"; then
  echo "git ls-files failure did not report a safe inventory diagnostic" >&2
  regression_failures=$((regression_failures + 1))
fi

if [[ "$regression_failures" -ne 0 ]]; then
  echo "$regression_failures public policy scanner regression(s) failed" >&2
  exit 1
fi

echo "Public repository policy regression tests passed"
