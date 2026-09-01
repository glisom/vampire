# Vampire GitHub and Open-Source Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish Vampire's source under the MIT License at `glisom/vampire` and ship a locally signed, notarized, and checksummed `v0.1.0` GitHub Release.

**Architecture:** Public GitHub Actions run only unsigned, nonprivileged verification on `macos-26`; signing and notarization remain local and use credentials already stored in the developer's Keychain. Repository policy scripts make the public-source boundary executable, while ignored local release metadata binds the notarized DMG and checksum to the exact clean source commit that is tagged and published.

**Tech Stack:** Swift 6, AppKit, Xcode 26.6, XcodeGen 2.45+, Bash 3.2, GitHub Actions, GitHub CLI, Developer ID signing, `notarytool`, GitHub Releases.

**Spec:** `docs/superpowers/specs/2026-09-01-github-open-source-release-design.md`

## Global Constraints

- Vampire remains a native AppKit menu-bar utility for macOS 13 or newer.
- Vampire changes lid-close sleep behavior only. It does not prevent ordinary idle sleep and does not replace Lungo.
- The stable Insomnia-era bundle ID, helper label, XPC names, target names, and recovery paths remain unchanged.
- The helper may execute only the three fixed `pmset` forms in the canonical product design and may never invoke a shell.
- Ordinary builds and tests must never register the helper, request administrator approval, change `pmset`, restart the Mac, or perform a lid-close test.
- No signing certificate, private key, Keychain material, Apple ID, or notary credential may leave the development Mac or enter GitHub.
- Distribution is direct through GitHub Releases, outside the Mac App Store.
- The public source license is MIT, copyright 2026 Grant Isom.
- GitHub CI is unsigned, read-only, and must not upload an application artifact.
- The initial public release is `v0.1.0`, marketing version `0.1.0`, build `1`.
- The website and blog announcement remain deferred.
- Use TDD for repository scripts and commit after every code or documentation task passes its scoped checks.

## File Map

```text
LICENSE                                         MIT license grant
README.md                                       Public install, use, safety, build, and release guide
CONTRIBUTING.md                                 Contributor workflow and privileged-test boundary
SECURITY.md                                     Private vulnerability-reporting instructions
AGENTS.md                                       Public project constraints for agentic contributors
docs/privacy.md                                 Plain-language no-data-collection statement
docs/release-checklist.md                       Reusable release evidence template
docs/superpowers/specs/2026-08-28-insomnia-menu-bar-app-design.md  Canonical product design with GitHub distribution amendment
docs/superpowers/specs/2026-09-01-github-open-source-release-design.md  Approved open-source release design
docs/superpowers/plans/2026-09-01-github-open-source-release.md  This implementation plan
.github/workflows/ci.yml                        Unsigned hosted verification
scripts/check-public-repo.sh                    Current-tree public exposure and product-policy guard
scripts/test-public-repo.sh                     Regression test for public repository policy
scripts/ci.sh                                   One local/hosted nonprivileged verification entrypoint
scripts/test-ci-config.sh                       Regression checks for hosted workflow safety
scripts/prepare-release-assets.sh               Clean-commit provenance and SHA-256 generation
scripts/test-release-assets.sh                  Isolated tests for release provenance and checksum output
scripts/test-scripts.sh                         Aggregate release-script smoke checks
KICKOFF.md                                      Remove obsolete private-session prompt
build/release/source-commit.txt                 Ignored exact candidate commit metadata
build/release/Vampire.dmg.sha256                Ignored GitHub Release checksum asset
build/release/release-notes.md                  Ignored GitHub Release notes
```

---

### Task 1: Public Documentation and Repository Policy

**Files:**
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `docs/privacy.md`
- Create: `scripts/check-public-repo.sh`
- Create: `scripts/test-public-repo.sh`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/release-checklist.md`
- Delete: `KICKOFF.md`

**Interfaces:**
- Consumes: the canonical product design, the approved GitHub release design, and the existing local development commands.
- Produces: `scripts/check-public-repo.sh`, a zero-argument policy check that exits `0` only when required public files exist, obsolete/private files are absent, credential-like tracked filenames are absent, current Markdown has no personal absolute path or machine-run details, no private-key/token pattern is present, and the helper/source product boundary remains intact.

- [ ] **Step 1: Write the failing public-repository policy scripts**

Create `scripts/check-public-repo.sh` with these checks:

```bash
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
```

Create `scripts/test-public-repo.sh`:

```bash
#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
bash "$script_directory/check-public-repo.sh"
```

Make both executable:

```bash
chmod +x scripts/check-public-repo.sh scripts/test-public-repo.sh
```

- [ ] **Step 2: Run the policy test and verify it fails**

Run:

```bash
scripts/test-public-repo.sh
```

Expected: FAIL with `Missing required public file: LICENSE` before evaluating later checks.

- [ ] **Step 3: Add the MIT license and public support documents**

Create `LICENSE` with this exact text:

```text
MIT License

Copyright (c) 2026 Grant Isom

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Create `CONTRIBUTING.md` with these exact policies:

````markdown
# Contributing to Vampire

Thanks for taking a look! Small, focused fixes and improvements are welcome.

## Before you start

Vampire changes lid-close sleep behavior only. It intentionally has no timers, schedules, shortcuts, networking, analytics, updater, Dock icon, main window, SwiftUI, or ordinary idle-sleep features.

Please open an issue before starting a change that affects product behavior or the privileged-helper contract.

## Development

You need macOS, full Xcode 26 or newer, and XcodeGen 2.45 or newer.

```bash
xcodegen generate
scripts/ci.sh
```

Use focused commits and include tests for behavioral changes.

## Safety

Ordinary tests use fakes and temporary marker stores. They must never register the real helper or change the Mac's power settings.

Do not run real helper registration, administrator approval, `pmset` mutation, restart, or lid-close tests as part of a contribution. Maintainer release testing handles those steps separately.

Never commit signing credentials, certificates, private keys, Apple IDs, Keychain exports, or notary credentials.

## Security reports

Please do not open a public issue for a vulnerability. Follow [SECURITY.md](SECURITY.md) instead.
````

Create `SECURITY.md`:

```markdown
# Security Policy

## Supported versions

Security fixes are made against the latest release and `main`.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository: open the Security tab, choose Advisories, then choose Report a vulnerability.

Include the affected version, macOS version, impact, reproduction steps, and any suggested mitigation. Please do not include credentials, personal data, or destructive proof-of-concept steps.

Do not open a public issue until a fix or coordinated disclosure plan is ready.
```

Create `docs/privacy.md`:

```markdown
# Vampire Privacy

Vampire does not collect data.

The app has no networking, accounts, telemetry, analytics, advertising, or third-party runtime dependencies. Its work happens locally on your Mac.

Vampire writes a root-owned local recovery marker only while lid-close sleep is disabled. It uses Apple's unified logging for operational errors and excludes passwords, usernames, file contents, and device identifiers.
```

- [ ] **Step 4: Rewrite the README for GitHub distribution**

Keep the current accurate behavior, recovery, troubleshooting, and stable-identifier explanations. Make these exact changes:

- Add an opening install link to `https://github.com/glisom/vampire/releases/latest`.
- Make “Download the latest `Vampire.dmg` from GitHub Releases” the first installation step.
- Add a “Verify the download” section with `shasum -a 256 -c Vampire.dmg.sha256`.
- Link the Privacy section to `docs/privacy.md` and state “Vampire does not collect data.”
- Change the development prerequisite from Xcode 16 to Xcode 26 because the checked-in Icon Composer source requires Xcode 26.
- Replace the three duplicated test commands with `scripts/ci.sh`, followed by the individual commands for contributors who need focused runs.
- Link `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`.
- State that official binaries are signed and notarized by Grant Isom while source builds use the contributor's own signing context.
- Preserve the warning that emergency manual restoration is `sudo /usr/bin/pmset -a disablesleep 0`.
- Do not add the deferred website/blog announcement.

- [ ] **Step 5: Sanitize contributor instructions and the release checklist**

Update `AGENTS.md` to list both approved specs and both implementation plans as canonical documents:

```markdown
- `docs/superpowers/specs/2026-08-28-insomnia-menu-bar-app-design.md`
- `docs/superpowers/specs/2026-09-01-github-open-source-release-design.md`
- `docs/superpowers/plans/2026-08-31-insomnia-implementation.md`
- `docs/superpowers/plans/2026-09-01-github-open-source-release.md`
```

Keep its existing product, safety, TDD, AppKit, and scope constraints. Remove any claim that only the original plan governs all future work.

Replace `docs/release-checklist.md` with this reusable unchecked template:

````markdown
# Vampire Release Checklist

Record each result for the exact candidate being published.

- Vampire version/build:
- Clean source commit:
- `Vampire.dmg` SHA-256:
- Tester/date:

## Nonprivileged checks

- [ ] `scripts/ci.sh` passes from the clean source commit.
- [ ] Public repository and reachable-history exposure audits pass.
- [ ] Vampire and InsomniaHelper contain both `arm64` and `x86_64`.
- [ ] Nested signatures and designated requirements validate.
- [ ] Gatekeeper accepts Vampire as notarized Developer ID software.
- [ ] Stapler validates `Vampire.dmg`.
- [ ] `Vampire.dmg.sha256` validates locally.
- [ ] GitHub Actions CI passes. Run URL:
- [ ] Remote `main`, release tag, and local `source-commit.txt` resolve to the same commit.
- [ ] Freshly downloaded GitHub Release assets pass checksum verification.

## Privileged setup and recovery acceptance

Explicit approval is required immediately before this section. These checks temporarily change lid-close sleep. Do not run them unattended or as part of ordinary release automation.

- [ ] Install the signed candidate in `/Applications` and launch it.
- [ ] Complete the one-time macOS helper approval.
- [ ] Confirm later On and Off actions do not prompt again.
- [ ] Confirm On appears only after helper acknowledgement.
- [ ] Confirm normal Quit while On restores Off before exit.
- [ ] Confirm force quit while On causes helper recovery to Off.
- [ ] Confirm helper termination while On relaunches and restores Off.
- [ ] Confirm restart while On restores Off before the next app session.
- [ ] Confirm Launch at Login starts Vampire Off.
- [ ] Confirm disabling Launch at Login prevents the next login launch.
- [ ] Confirm Remove Helper verifies Off before unregistration.
- [ ] Confirm physical lid-close behavior while On and while Off.

After every privileged attempt, including failure, restore and verify:

```bash
sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g custom
```

- [ ] Final physical power state is `disablesleep 0` on every reported profile, or the key is absent after a successful Off write on a supported MacBook.

## Distribution

- [ ] GitHub repository is public with `main` as the default branch.
- [ ] GitHub Release tag matches the exact verified source commit.
- [ ] Release contains only `Vampire.dmg` and `Vampire.dmg.sha256`.
- [ ] Release is public, latest, and neither draft nor prerelease.
````

This removes personal hardware, process IDs, prior submission IDs, team ID, and narrative results from earlier candidates.

Delete `KICKOFF.md`.

- [ ] **Step 6: Run the public policy and documentation checks**

Run:

```bash
scripts/test-public-repo.sh
git diff --check
rg -n '/Users/[A-Za-z0-9._-]+|Grant Isom / [C]odex|Apple [M]5|PID [0-9]+' --glob '*.md' .
```

Expected: the policy script passes, `git diff --check` produces no output, and the final `rg` command produces no output.

- [ ] **Step 7: Commit the public repository documentation**

```bash
git add LICENSE README.md CONTRIBUTING.md SECURITY.md AGENTS.md docs/privacy.md docs/release-checklist.md scripts/check-public-repo.sh scripts/test-public-repo.sh KICKOFF.md
git commit -m "docs: prepare Vampire for open source"
```

---

### Task 2: Unsigned GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `scripts/ci.sh`
- Create: `scripts/test-ci-config.sh`

**Interfaces:**
- Consumes: Xcode 26.6, XcodeGen 2.45+, ripgrep, the three existing Xcode test schemes, and Task 1's repository policy scripts.
- Produces: `scripts/ci.sh`, the single nonprivileged verification entrypoint used locally and by `.github/workflows/ci.yml`; hosted CI has read-only contents permission and publishes no artifact.

- [ ] **Step 1: Write the failing workflow-policy test**

Create `scripts/test-ci-config.sh`:

```bash
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
```

Make it executable, then run it:

```bash
chmod +x scripts/test-ci-config.sh
scripts/test-ci-config.sh
```

Expected: FAIL with `Missing GitHub Actions workflow: .github/workflows/ci.yml`.

- [ ] **Step 2: Add the shared nonprivileged CI entrypoint**

Create `scripts/ci.sh`:

```bash
#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
cd "$repository_root"

xcodegen generate
bash -n scripts/*.sh
scripts/test-public-repo.sh
scripts/test-ci-config.sh
scripts/test-scripts.sh

xcodebuild -project Insomnia.xcodeproj -scheme InsomniaTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaHelperTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaIntegrationTests -destination 'platform=macOS' test
```

Make it executable:

```bash
chmod +x scripts/ci.sh
```

- [ ] **Step 3: Add the hosted workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: macos-26
    timeout-minutes: 30
    steps:
      - name: Check out source
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - name: Install build tools
        run: brew install xcodegen ripgrep
      - name: Show tool versions
        run: |
          xcodebuild -version
          xcodegen --version
      - name: Run nonprivileged verification
        run: scripts/ci.sh
```

The checkout action is pinned to the full signed `v7.0.1` commit. Do not add caches, release credentials, `sudo`, signing, notarization, or artifact upload.

- [ ] **Step 4: Run focused workflow checks**

```bash
scripts/test-ci-config.sh
bash -n scripts/*.sh
git diff --check
```

Expected: PASS with no diff errors.

- [ ] **Step 5: Run the shared CI entrypoint locally**

```bash
scripts/ci.sh
```

Expected: all public-policy, workflow-policy, release-script smoke, app, helper, and integration tests pass without launching Vampire, registering a helper, or changing `pmset`.

- [ ] **Step 6: Commit CI**

```bash
git add .github/workflows/ci.yml scripts/ci.sh scripts/test-ci-config.sh
git commit -m "ci: add unsigned macOS verification"
```

---

### Task 3: Release Provenance and Checksum Assets

**Files:**
- Create: `scripts/prepare-release-assets.sh`
- Create: `scripts/test-release-assets.sh`
- Modify: `scripts/test-scripts.sh`

**Interfaces:**
- Consumes: an existing file named `Vampire.dmg` and a clean Git worktree containing the exact candidate source.
- Produces: `Vampire.dmg.sha256` in standard `shasum` format plus `source-commit.txt` containing the full 40-character clean source commit; neither file is tracked because `build/` is ignored.

- [ ] **Step 1: Write failing isolated release-asset tests**

Create `scripts/test-release-assets.sh`:

```bash
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
```

Make the test executable and run it:

```bash
chmod +x scripts/test-release-assets.sh
scripts/test-release-assets.sh
```

Expected: FAIL because `scripts/prepare-release-assets.sh` does not exist.

- [ ] **Step 2: Implement clean-source provenance and checksum generation**

Create `scripts/prepare-release-assets.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x scripts/prepare-release-assets.sh
```

- [ ] **Step 3: Add release-asset tests to the smoke-test aggregate**

Append this call before the final success message in `scripts/test-scripts.sh`:

```bash
bash "$script_directory/test-release-assets.sh"
```

The isolated test repository prevents the main task's uncommitted implementation files from invalidating its clean-worktree assertion.

- [ ] **Step 4: Run release tooling tests**

```bash
scripts/test-release-assets.sh
scripts/test-scripts.sh
bash -n scripts/*.sh
```

Expected: PASS, including checksum validation, exact commit capture, dirty-worktree rejection, basename rejection, and usage failures.

- [ ] **Step 5: Commit release provenance tooling**

```bash
git add scripts/prepare-release-assets.sh scripts/test-release-assets.sh scripts/test-scripts.sh
git commit -m "release: bind assets to clean source commits"
```

---

### Task 4: Pre-Publication Exposure Audit and Full Local Verification

**Files:**
- Verify only; no repository files change.

**Interfaces:**
- Consumes: the clean commits from Tasks 1–3 and all reachable existing Git history.
- Produces: evidence that no plausible credential or prohibited product behavior is present before the repository becomes public.

- [ ] **Step 1: Confirm the current tree passes the public policy**

```bash
git status --short
scripts/check-public-repo.sh
```

Expected: clean status and `Public repository policy checks passed`.

- [ ] **Step 2: Scan reachable history for credential-like filenames**

```bash
git rev-list --objects --all | rg -i '\.(p12|pfx|key|pem|cer|mobileprovision|provisionprofile)$|(^|/)(\.env($|\.)|credentials|secrets?)(/|$)'
```

Expected: no output. If output identifies real credential material, stop before any GitHub creation or push and ask Grant before history rewriting or credential rotation.

- [ ] **Step 3: Scan reachable history for credential-like contents without printing values**

Run:

```bash
for revision in $(git rev-list --all); do
  git grep -I -l -E -e '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}' "$revision" -- . || true
done | sort -u
```

Expected: no output. This uses `-l`, so a finding reports only a revision/path and never prints a credential value. Treat any output as a publication blocker until reviewed.

- [ ] **Step 4: Reconfirm the source security boundary**

```bash
rg -n '/bin/(sh|bash|zsh)|system\(|popen\(' InsomniaHelper/Sources
rg -n 'URLSession|Network\.framework|import Network|Sparkle|Telemetry|Analytics' Insomnia InsomniaHelper InsomniaShared
rg -n 'pmset' InsomniaHelper/Sources
```

Expected: the first two commands produce no output. The final command references only `CommandRunner.swift`'s fixed `/usr/bin/pmset` executable and the fixed commands owned by `PMSetController`.

- [ ] **Step 5: Run all nonprivileged verification from the clean tree**

```bash
scripts/ci.sh
git status --short
```

Expected: every test passes and status remains clean except for ignored generated project/build output.

---

### Task 5: Build and Verify the Exact Signed Candidate

**Files:**
- Generate ignored: `build/release/Vampire.dmg`
- Generate ignored: `build/release/Vampire.dmg.sha256`
- Generate ignored: `build/release/source-commit.txt`

**Interfaces:**
- Consumes: the clean Task 3 source commit, local identity `Developer ID Application: Grant Isom (3D247B7547)`, and local `notarytool` Keychain profile `vampire-notary`.
- Produces: a universal signed, notarized, stapled, Gatekeeper-accepted DMG plus checksum and exact source provenance. No helper registration or `pmset` mutation occurs.

- [ ] **Step 1: Reconfirm the local release prerequisites**

```bash
git status --short
xcodebuild -version
xcodegen --version
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile vampire-notary
```

Expected: clean status; Xcode 26 or newer; XcodeGen 2.45 or newer; the exact Developer ID identity is valid; notary history succeeds without printing credential material.

- [ ] **Step 2: Build the universal Developer ID candidate**

```bash
VAMPIRE_SIGNING_IDENTITY='Developer ID Application: Grant Isom (3D247B7547)' scripts/build-release.sh
```

Expected: `build/release/Vampire.dmg` is created. This archives and signs only; it does not launch Vampire or register the helper.

- [ ] **Step 3: Notarize and staple the candidate**

```bash
VAMPIRE_NOTARY_PROFILE='vampire-notary' scripts/notarize.sh build/release/Vampire.dmg
```

Expected: Apple's notary service reports `Accepted` and stapling succeeds.

- [ ] **Step 4: Verify the signed distribution artifact**

```bash
scripts/verify-release.sh build/release/Vampire.dmg
VAMPIRE_NOTARIZED_DMG="$PWD/build/release/Vampire.dmg" scripts/test-scripts.sh
```

Expected: nested signatures, designated requirements, Gatekeeper, outer DMG staple, `arm64`, and `x86_64` all validate.

- [ ] **Step 5: Generate and verify release provenance assets**

```bash
scripts/prepare-release-assets.sh build/release/Vampire.dmg
test "$(cat build/release/source-commit.txt)" = "$(git rev-parse HEAD)"
(cd build/release && /usr/bin/shasum -a 256 -c Vampire.dmg.sha256)
git status --short
```

Expected: commit equality and checksum validation succeed, and the worktree remains clean because release output is ignored.

---

### Task 6: Create and Verify the Public GitHub Repository

**Files:**
- External state: create public repository `glisom/vampire`
- External state: add local remote `origin`
- External state: push the exact candidate commit to remote `main`

**Interfaces:**
- Consumes: the clean, audited, signed candidate source commit and the authenticated GitHub CLI account `glisom`.
- Produces: a public repository with Issues, secret scanning, push protection, private vulnerability reporting, focused topics, and passing CI on `main`.

- [ ] **Step 1: Reconfirm that the target is unused and the candidate is exact**

```bash
gh auth status
gh repo view glisom/vampire
test "$(cat build/release/source-commit.txt)" = "$(git rev-parse HEAD)"
git status --short
```

Expected: GitHub authentication succeeds, `gh repo view` reports that the repository does not exist, source commits match, and status is clean. If the repository now exists unexpectedly, inspect it and stop rather than overwriting it.

- [ ] **Step 2: Create the public repository without pushing**

```bash
gh repo create glisom/vampire \
  --public \
  --source=. \
  --remote=origin \
  --disable-wiki \
  --description 'A native macOS menu-bar utility that keeps your MacBook awake with the lid closed.'
```

Expected: `https://github.com/glisom/vampire` exists publicly and `origin` points to it. Do not use `--push` in this step so security settings can be enabled first.

- [ ] **Step 3: Configure the repository security and collaboration surface**

```bash
gh repo edit glisom/vampire \
  --enable-issues=true \
  --enable-wiki=false \
  --enable-projects=false \
  --delete-branch-on-merge=true \
  --enable-squash-merge=true \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --enable-secret-scanning=true \
  --enable-secret-scanning-push-protection=true \
  --add-topic macos,swift,appkit,menu-bar,sleep
gh api --method PUT repos/glisom/vampire/private-vulnerability-reporting
```

Expected: settings calls succeed. If a plan-tier limitation prevents a security feature, continue only after recording the exact unavailable feature; do not weaken repository visibility or upload credentials as a workaround.

- [ ] **Step 4: Push the exact candidate source to remote main**

```bash
git push origin HEAD:refs/heads/main
gh repo edit glisom/vampire --default-branch main
gh repo set-default glisom/vampire
```

Expected: remote `main` points at the commit in `build/release/source-commit.txt`. No force push is allowed.

- [ ] **Step 5: Wait for hosted CI and verify repository state**

```bash
run_id="$(gh run list --repo glisom/vampire --branch main --workflow CI --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$run_id" --repo glisom/vampire --exit-status
gh repo view glisom/vampire --json nameWithOwner,visibility,url,defaultBranchRef
test "$(gh api repos/glisom/vampire/commits/main --jq .sha)" = "$(cat build/release/source-commit.txt)"
```

Expected: CI succeeds, visibility is `PUBLIC`, default branch is `main`, and remote/source provenance commits match. If CI fails, do not tag or publish a release; fix the source, rebuild the exact signed candidate, and repeat Tasks 4–6.

---

### Task 7: Tag and Publish GitHub Release v0.1.0

**Files:**
- Generate ignored: `build/release/release-notes.md`
- External state: annotated tag `v0.1.0`
- External state: GitHub Release `v0.1.0`

**Interfaces:**
- Consumes: passing hosted CI, exact source provenance, `Vampire.dmg`, and `Vampire.dmg.sha256`.
- Produces: the public GitHub Release with installable notarized DMG and matching checksum.

- [ ] **Step 1: Verify every publication gate immediately before tagging**

```bash
test "$(cat build/release/source-commit.txt)" = "$(git rev-parse HEAD)"
test "$(gh api repos/glisom/vampire/commits/main --jq .sha)" = "$(git rev-parse HEAD)"
(cd build/release && /usr/bin/shasum -a 256 -c Vampire.dmg.sha256)
scripts/verify-release.sh build/release/Vampire.dmg
git status --short
```

Expected: all commit comparisons, checksum, release verification, and clean-status checks pass.

- [ ] **Step 2: Create and push the annotated release tag**

```bash
git tag -a v0.1.0 -m 'Vampire 0.1.0'
git push origin refs/tags/v0.1.0
test "$(git rev-list -n 1 v0.1.0)" = "$(cat build/release/source-commit.txt)"
```

Expected: the tag points to the exact locally recorded and remotely verified candidate commit. If a `v0.1.0` tag already exists, inspect it and stop rather than moving or deleting it.

- [ ] **Step 3: Write the brief GitHub release notes**

Create ignored `build/release/release-notes.md` with this exact copy:

````markdown
Vampire is a tiny native Mac menu-bar app that keeps your MacBook awake with the lid closed. That's it!

Download `Vampire.dmg`, drag Vampire to Applications, and follow the one-time helper approval on first launch. Later On and Off changes do not need another administrator prompt.

Requires a MacBook running macOS 13 Ventura or newer. Vampire changes lid-close sleep only and does not prevent ordinary idle sleep.

To verify the download, place both assets together and run:

```bash
shasum -a 256 -c Vampire.dmg.sha256
```
````

- [ ] **Step 4: Publish the release assets**

```bash
gh release create v0.1.0 \
  build/release/Vampire.dmg \
  build/release/Vampire.dmg.sha256 \
  --repo glisom/vampire \
  --verify-tag \
  --latest \
  --title 'Vampire 0.1.0' \
  --notes-file build/release/release-notes.md
```

Expected: GitHub publishes `Vampire 0.1.0` with exactly two downloadable assets.

- [ ] **Step 5: Verify the public release from a fresh download**

```bash
verification_directory="$(mktemp -d "${TMPDIR:-/tmp}/vampire-github-release.XXXXXX")"
gh release download v0.1.0 --repo glisom/vampire --dir "$verification_directory"
(cd "$verification_directory" && /usr/bin/shasum -a 256 -c Vampire.dmg.sha256)
gh release view v0.1.0 --repo glisom/vampire --json isDraft,isPrerelease,tagName,url,assets
git status --short
```

Expected: the fresh download validates, the release is neither draft nor prerelease, the tag is `v0.1.0`, the two assets are present, and the local source worktree is clean.

Do not delete the verification directory with a broad or unresolved path. It is safe to leave under the system temporary directory; the OS will clean it up.

---

## Final Verification

- [ ] `git status --short` is empty.
- [ ] `scripts/ci.sh` passes locally.
- [ ] GitHub Actions CI passes on remote `main`.
- [ ] Public repository policy and reachable-history exposure audits report no credential or private-machine blocker.
- [ ] `glisom/vampire` is public with `main` as its default branch, Issues enabled, and private vulnerability reporting enabled.
- [ ] Secret scanning and push protection are enabled or their exact plan-tier limitation is recorded.
- [ ] Remote `main`, annotated tag `v0.1.0`, `build/release/source-commit.txt`, and the notarized candidate all refer to the same source commit.
- [ ] The GitHub Release contains only `Vampire.dmg` and `Vampire.dmg.sha256`.
- [ ] A fresh download passes `shasum -a 256 -c Vampire.dmg.sha256`.
- [ ] The DMG is Developer ID-signed, notarized, stapled, Gatekeeper-accepted, and universal for `arm64` and `x86_64`.
- [ ] No real helper registration, administrator approval, `pmset` mutation, restart, or lid-close test occurred during this release pass.
- [ ] The website/blog announcement remains deferred.
