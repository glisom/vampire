#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/Vampire.dmg" >&2
}

if [[ $# -ne 1 || -z "$1" ]]; then
  usage
  exit 64
fi

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
dmg="$1"

if [[ ! -f "$dmg" ]]; then
  echo "DMG not found: $dmg" >&2
  exit 66
fi

if [[ "$(basename "$dmg")" != "Vampire.dmg" ]]; then
  echo "Expected an asset named Vampire.dmg" >&2
  exit 65
fi

if [[ -n "$(git -C "$repository_root" status --porcelain --untracked-files=normal)" ]]; then
  echo "Release source worktree is not clean" >&2
  exit 67
fi

dmg_directory="$(cd "$(dirname "$dmg")" && pwd -P)"
dmg_name="$(basename "$dmg")"
checksum_name="$dmg_name.sha256"
source_commit="$(git -C "$repository_root" rev-parse HEAD)"

(
  cd "$dmg_directory"
  /usr/bin/shasum -a 256 "$dmg_name" > "$checksum_name"
  /usr/bin/shasum -a 256 -c "$checksum_name"
  printf '%s\n' "$source_commit" > source-commit.txt
)

echo "Prepared $dmg_directory/$checksum_name for source commit $source_commit"
