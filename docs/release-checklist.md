# Vampire Release Checklist

Record each result for the exact candidate being tested.

- macOS version: 26.6.2 (25G83)
- Mac model: MacBook Pro (Mac17,2, Apple M5)
- Vampire version/build: 0.1.0 (1)
- Signed candidate source commit: `1300e6cd89eabd95863bfd3ed47d45418c6da845`
- `Vampire.dmg` SHA-256: `112effbdb59ef2a1437d1a3f93b95300bf806bbc615a03e0a76e6fbc683a80fa`
- Tester/date: Grant Isom / Codex, 2026-08-31 13:20 CDT

## Nonprivileged checks

- [x] All app unit tests pass on the Vampire candidate. (41 tests)
- [x] All helper unit tests pass. (28 tests)
- [x] Packaged-app integration tests pass on `Vampire.app`. (4 tests; 2 expected ad-hoc Team-ID skips)
- [x] Vampire bundle layout, DMG checksum, and static signature checks pass.
- [x] Vampire and the helper contain both `arm64` and `x86_64`.

## Privileged setup and recovery acceptance

Explicit approval is required immediately before this section. These checks temporarily change lid-close sleep. Do not run them unattended.

- [x] Copy the signed candidate to `/Applications/Vampire.app` and launch it.
- [x] Complete the one-time macOS helper approval. (Approved on signed pre-final candidate; helper is enabled and running.)
- [x] Confirm later On and Off actions do not prompt again.
- [x] Turn On and confirm the app reports On only after helper acknowledgement.
- [x] Choose normal Quit while On and confirm Off before exit.
- [x] Turn On, force quit the app, and confirm the helper restores Off.
- [ ] Turn On, kill the helper, and confirm launchd relaunch restores Off.
- [ ] Turn On, restart the Mac, and confirm Off before using the app after login.
- [ ] Enable Launch at Login, restart/login, and confirm Vampire starts Off.
- [ ] Disable Launch at Login and confirm it no longer launches.
- [ ] Use Remove Helper and confirm Off is verified before unregistration.
- [ ] On a MacBook, verify actual lid-close behavior while On.
- [ ] Turn Off Vampire and verify actual lid-close behavior while Off.

After every privileged attempt, including any failed step, restore and verify:

```bash
sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g custom
```

- [x] Final physical power state is `disablesleep 0` on every reported profile, or the key is absent after a successful Off write on the supported MacBook.

## Notarization and distribution

- [x] Build `build/release/Vampire.dmg` with Developer ID Application identity for Team `3D247B7547`.
- [ ] Notary service reports Accepted.
- [ ] Stapler validates the DMG and contained app.
- [x] `codesign --verify --deep --strict` passes.
- [ ] Gatekeeper accepts the app with `spctl --assess --type execute`.
- [ ] Test the DMG on a Mac that did not build it.
- [ ] On a clean macOS 13-or-newer account, complete install and one-time approval.
- [ ] Record final result and any failures below.

## Results

| Check | Pass/Fail | Notes |
|---|---|---|
| Privileged helper setup | Pass | Service Management approval completed; daemon is enabled and running. Initial UI falsely reported failure while approval was pending; fixed by `7dbbb41`. |
| Enable and disable | Pass | Signed `/Applications/Vampire.app` reused the approved helper without a new prompt. Wake Vampire reported On only after helper acknowledgement; Turn Off Vampire reported Off; the required explicit restore completed. |
| Quit and crash recovery | Pass | Normal Quit waited for the helper's Off acknowledgement before termination. A `SIGKILL` while On invalidated XPC, and the helper restored Off while remaining healthy. Explicit safety restores followed both attempts. |
| Helper relaunch recovery |  |  |
| Restart recovery |  |  |
| Lid-close On and Off |  |  |
| Launch at Login |  |  |
| Safe removal |  |  |
| Notarization and Gatekeeper |  |  |

Privileged acceptance notes:

- The user-facing Vampire rebrand preserves the existing bundle ID, helper label, XPC contract, and recovery path. The signed A+C icon candidate was built and verified without launching the app or changing real power settings.
- The refined menu-bar coffin and crescent in `1300e6c` passed six pixel-level renderer tests, including a regression test for a fully transparent open crescent edge, and received visual approval before this candidate was built.
- Independent review found two helper-originated Insomnia error strings; both are Vampire-branded and covered by helper tests in `da85228`.
- The signed Vampire candidate replaced `/Applications/Insomnia.app`; the previous app remains recoverably backed up at `build/release/acceptance-backup/Insomnia.app`.
- An accidental ad-hoc Xcode Debug launch was rejected by the helper's Team-ID requirement before any `pmset` command ran. Relaunching the Developer-ID-signed `/Applications/Vampire.app` established the authenticated XPC connection and completed the On/Off test without renewed approval.
- Normal Quit while On completed only after Off was acknowledged. Force-quitting the signed app while On caused the helper to observe the client disconnect and restore Off; the helper remained running.
- First signed launch exposed and resolved three pre-acceptance defects: modern MacBook detection (`289e073`), AppKit delegate bootstrapping (`492de3f`), and helper bundle layout (`f88db32`).
- Service Management raw status 3 is the normal unregistered state, so Setup is now offered from that state (`a14ca8f`).
- macOS recorded the helper and posted approval while synchronous registration reported not-yet-allowed; the final candidate handles that pending-approval race (`7dbbb41`).
- Required manual `sudo /usr/bin/pmset -a disablesleep 0` restores were completed after the registration attempt, after the rejected Debug-client attempt, after the signed candidate's successful On/Off test, after normal Quit recovery, and after force-quit recovery. Final `pmset -g custom` output omitted `disablesleep` from both battery and AC profiles.
