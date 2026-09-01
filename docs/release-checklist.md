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
