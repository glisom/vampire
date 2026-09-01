---
type: context
status: approved
date: 2026-09-01
tags: [project, macos, open-source, github, release]
---

# Vampire GitHub and Open-Source Release Design

**Status:** Approved by Grant on 2026-09-01  
**Owner:** Grant Isom  
**Repository:** `https://github.com/glisom/vampire`  
**Initial release:** `v0.1.0`  
**License:** MIT

## Objective

Publish Vampire as a trustworthy open-source macOS utility with a signed and notarized GitHub Release that a non-developer can install. Preserve Vampire's full lid-close behavior and its existing privileged-helper security contract. Do not create a reduced Mac App Store edition.

The website announcement is deferred and is not part of this release pass.

## Product and Safety Boundaries

- Vampire remains a native AppKit menu-bar utility for macOS 13 or newer.
- Vampire changes lid-close sleep behavior only. It does not prevent ordinary idle sleep and does not replace Lungo.
- The stable Insomnia-era bundle ID, helper label, XPC names, target names, and recovery paths remain unchanged.
- The helper may execute only the three fixed `pmset` forms in the canonical product design and may never invoke a shell.
- Ordinary builds and tests must never register the helper, request administrator approval, change `pmset`, restart the Mac, or perform a lid-close test.
- No signing certificate, private key, Keychain material, Apple ID, or notary credential may leave the development Mac or enter GitHub.
- The release remains direct distribution outside the Mac App Store because the product requires a privileged root helper that is incompatible with Mac App Store review rules.

## Approaches Considered

### 1. Local signing with unsigned GitHub CI

**Chosen.** GitHub Actions compiles and tests the source without signing. Release artifacts are built, signed, notarized, stapled, and verified locally with credentials stored in the developer's Keychain, then uploaded to GitHub. This provides public CI without expanding the credential boundary.

### 2. Fully automated signed GitHub releases

Rejected for the initial release. It would require exporting signing material and Apple credentials into GitHub Secrets, adding credential rotation and CI hardening work without improving the user experience.

### 3. Source-only publication

Rejected. It would make the code inspectable but would not give non-developers a practical installation path.

## Public Repository

Create `glisom/vampire` as a public GitHub repository with the existing Git history and `main` as its default branch. The repository description should state the narrow product promise: a native macOS menu-bar utility that keeps a MacBook awake with its lid closed. Repository topics should cover macOS, Swift, AppKit, menu-bar apps, and sleep behavior.

The public repository contains:

- the MIT `LICENSE`;
- a concise `README.md` centered on Releases installation, first-run approval, exact scope, safety, privacy, source builds, tests, and local release commands;
- `CONTRIBUTING.md` with the supported development flow and the privileged-test boundary;
- `SECURITY.md` directing vulnerability reports to GitHub's private Security Advisories rather than public issues;
- `docs/privacy.md` stating that Vampire has no networking, telemetry, analytics, accounts, or collected data;
- the canonical product design and implementation history, sanitized where needed for public readability;
- a reusable release checklist that records evidence without personal machine details; and
- one unsigned GitHub Actions CI workflow.

Remove the obsolete fresh-session kickoff prompt. Reduce `AGENTS.md` to project-specific product and safety instructions suitable for public contributors. Do not add a code of conduct, governance process, or issue-template suite for the initial release.

## Public-Exposure Audit

Before creating the public remote, inspect the current tree and reachable Git history for:

- private keys and certificate material;
- GitHub, Apple, notary, or other access tokens;
- passwords and credential-bearing environment files;
- signing or Keychain exports;
- personal absolute paths in current public documentation; and
- release evidence that unnecessarily identifies the test machine or local processes.

Public signing-team identifiers, bundle identifiers, source commit hashes, notarization submission identifiers, and binary checksums are not secrets, but the current release documentation should retain only information useful to downstream verification. If an actual secret is found in history, stop before pushing and ask Grant before any history rewrite or credential rotation.

## Continuous Integration

Create `.github/workflows/ci.yml` for pushes and pull requests. The workflow runs on GitHub's `macos-26` image with Xcode 26.6, installs XcodeGen through Homebrew, verifies XcodeGen is at least version 2.45, generates `Insomnia.xcodeproj`, and runs:

1. app unit tests;
2. helper unit tests;
3. packaged-app integration tests using ad-hoc signing;
4. shell script syntax and smoke tests; and
5. a source-policy check for forbidden helper shell execution and release credential files.

CI must not launch Vampire, call `SMAppService.register`, connect to a real privileged helper, invoke real `pmset` writes, use `sudo`, or upload an application artifact. Workflow permissions default to read-only contents access.

## Local Release Flow

The initial release is `v0.1.0`, matching marketing version `0.1.0` and build `1`.

1. Run the complete nonprivileged test suite from a clean generated project.
2. Build a universal Release archive locally with the Developer ID Application identity already available in Keychain.
3. Create `Vampire.dmg` with an Applications shortcut.
4. Submit the DMG with the existing local `notarytool` Keychain profile and wait for acceptance.
5. Staple the ticket and verify the app, helper, architectures, Gatekeeper assessment, and outer DMG ticket.
6. Generate `Vampire.dmg.sha256` using `shasum -a 256` in standard checksum-file format.
7. Verify the checksum locally and stage both release assets without changing the source commit used for the build.
8. Push the source branch, allow GitHub CI to pass, merge or fast-forward the approved release commit to `main`, and create annotated tag `v0.1.0` at that exact commit.
9. Publish a GitHub Release containing `Vampire.dmg`, `Vampire.dmg.sha256`, a short product summary, install steps, macOS requirements, a note that first launch needs administrator approval, and the checksum as release evidence.

Do not publish a release from a dirty worktree, a commit that differs from the notarized candidate, or a commit whose GitHub CI run failed. Never print credential values in release-script output.

## Failure Handling

- If the public-exposure audit finds a plausible credential, stop before creating or pushing the public repository.
- If local tests or static policy checks fail, do not build or upload a release candidate.
- If signing, notarization, stapling, Gatekeeper, architecture, or checksum verification fails, do not tag or publish the release.
- If GitHub CI fails after the first push, keep the GitHub Release unpublished until the source is corrected and a new exact candidate passes both local and hosted verification.
- If repository creation or upload partially succeeds, preserve the remote and report its exact state rather than deleting or force-pushing it.

## Verification Strategy

### Automated

- All three Xcode test schemes pass locally and in GitHub Actions.
- All shell scripts pass syntax and smoke checks.
- The helper source contains no shell execution path and no caller-controlled executable or arguments.
- The project contains no network, analytics, telemetry, updater, or automatic-On behavior.
- CI has read-only permissions and contains no privileged or release-signing step.
- Public documentation links resolve within the repository and uses the Vampire product name while retaining stable internal identifiers where technically necessary.

### Release Artifact

- `Vampire.app` and `InsomniaHelper` contain both `arm64` and `x86_64`.
- Nested signatures and designated requirements validate.
- Gatekeeper accepts the contained app as notarized Developer ID software.
- Stapler validates the distributed DMG.
- `shasum -a 256 -c Vampire.dmg.sha256` succeeds for the uploaded asset.
- The release tag resolves to the clean source commit captured in local release metadata when the checksum is generated.

### Manual Boundaries

The prior privileged acceptance evidence remains relevant because this pass does not change app or helper behavior. No real helper registration, administrator approval, `pmset` mutation, restart, or lid-close test is authorized by this design. Any later repeat requires Grant's explicit approval immediately before the action and must end with `sudo /usr/bin/pmset -a disablesleep 0`, including after failure.

## Definition of Done

- `https://github.com/glisom/vampire` is public with `main` as the default branch.
- The repository has an MIT license, focused public documentation, a private vulnerability-reporting path, and passing unsigned CI.
- Current public files contain no credentials or unnecessary personal-machine details.
- GitHub Release `v0.1.0` is published from the exact verified source tag.
- The release contains the signed and notarized `Vampire.dmg` plus a matching SHA-256 checksum file.
- The local worktree is clean and the final source commit is pushed.
- The website/blog announcement remains deferred.
