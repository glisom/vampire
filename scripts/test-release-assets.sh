#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
production_script="$script_directory/prepare-release-assets.sh"

if [[ ! -f "$production_script" ]]; then
  echo "Missing release asset script: $production_script" >&2
  exit 1
fi

fixture="$(mktemp -d "${TMPDIR:-/tmp}/vampire-release-assets.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/build/release"
cp "$production_script" "$fixture/scripts/prepare-release-assets.sh"
printf 'vampire release fixture\n' > "$fixture/build/release/Vampire.dmg"
printf 'tracked fixture\n' > "$fixture/tracked.txt"

git -C "$fixture" init -q
git -C "$fixture" config user.name 'Vampire Tests'
git -C "$fixture" config user.email 'tests@example.invalid'
git -C "$fixture" add .
git -C "$fixture" commit -qm 'test fixture'

(
  cd "$fixture"
  bash scripts/prepare-release-assets.sh build/release/Vampire.dmg
  test "$(cat build/release/source-commit.txt)" = "$(git rev-parse HEAD)"
  /usr/bin/grep -Eq '^[0-9a-f]{64}  Vampire\.dmg$' build/release/Vampire.dmg.sha256
  cd build/release
  /usr/bin/shasum -a 256 -c Vampire.dmg.sha256
)

if output=$(bash "$production_script" 2>&1); then
  echo "Expected missing arguments to fail" >&2
  exit 1
fi
/usr/bin/grep -q 'Usage:' <<<"$output"

printf 'wrong asset\n' > "$fixture/build/release/Other.dmg"
if output=$(cd "$fixture" && bash scripts/prepare-release-assets.sh build/release/Other.dmg 2>&1); then
  echo "Expected a non-Vampire basename to fail" >&2
  exit 1
fi
/usr/bin/grep -q 'Expected an asset named Vampire.dmg' <<<"$output"

printf '/build/release/*.sha256\n/build/release/source-commit.txt\n/build/release/Other.dmg\n' > "$fixture/.gitignore"
git -C "$fixture" add .gitignore
git -C "$fixture" commit -qm 'ignore generated evidence'
printf 'dirty\n' >> "$fixture/tracked.txt"
if output=$(cd "$fixture" && bash scripts/prepare-release-assets.sh build/release/Vampire.dmg 2>&1); then
  echo "Expected a dirty worktree to fail" >&2
  exit 1
fi
/usr/bin/grep -q 'Release source worktree is not clean' <<<"$output"

echo "Release asset tests passed"
