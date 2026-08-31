# Insomnia Release Checklist

Record each result for the exact candidate being tested.

- macOS version: 26.6.2 (25G83)
- Mac model: MacBook Pro (Mac17,2, Apple M5)
- Insomnia version/build: 0.1.0 (1)
- Git commit: `7dbbb41`
- Tester/date: Grant Isom / Codex, 2026-08-31 11:42 CDT

## Nonprivileged checks

- [x] All app unit tests pass. (35 tests)
- [x] All helper unit tests pass. (27 tests)
- [x] Packaged-app integration tests pass. (4 tests; 2 expected ad-hoc Team-ID skips)
- [x] Bundle layout and static signature checks pass.
- [x] App and helper contain both `arm64` and `x86_64`.

## Privileged setup and recovery acceptance

Explicit approval is required immediately before this section. These checks temporarily change lid-close sleep. Do not run them unattended.

- [ ] Copy the signed candidate to `/Applications/Insomnia.app` and launch it.
- [x] Complete the one-time macOS helper approval. (Approved on signed pre-final candidate; helper is enabled and running.)
- [ ] Confirm later On and Off actions do not prompt again.
- [ ] Turn On and confirm the app reports On only after helper acknowledgement.
- [ ] Choose normal Quit while On and confirm Off before exit.
- [ ] Turn On, force quit the app, and confirm the helper restores Off.
- [ ] Turn On, kill the helper, and confirm launchd relaunch restores Off.
- [ ] Turn On, restart the Mac, and confirm Off before using the app after login.
- [ ] Enable Launch at Login, restart/login, and confirm Insomnia starts Off.
- [ ] Disable Launch at Login and confirm it no longer launches.
- [ ] Use Remove Helper and confirm Off is verified before unregistration.
- [ ] On a MacBook, verify actual lid-close behavior while On.
- [ ] Restore Lullaby and verify actual lid-close behavior while Off.

After every privileged attempt, including any failed step, restore and verify:

```bash
sudo /usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -g custom
```

- [ ] Final physical power state is `disablesleep 0` on every reported profile, or the key is absent after a successful Off write on the supported MacBook.

## Notarization and distribution

- [x] Build `build/release/Insomnia.dmg` with the selected Developer ID Application identity.
- [ ] Notary service reports Accepted.
- [ ] Stapler validates the DMG and contained app.
- [ ] `codesign --verify --deep --strict` passes.
- [ ] Gatekeeper accepts the app with `spctl --assess --type execute`.
- [ ] Test the DMG on a Mac that did not build it.
- [ ] On a clean macOS 13-or-newer account, complete install and one-time approval.
- [ ] Record final result and any failures below.

## Results

| Check | Pass/Fail | Notes |
|---|---|---|
| Privileged helper setup | Pass | Service Management approval completed; daemon is enabled and running. Initial UI falsely reported failure while approval was pending; fixed by `7dbbb41`. |
| Enable and disable |  |  |
| Quit and crash recovery |  |  |
| Helper relaunch recovery |  |  |
| Restart recovery |  |  |
| Lid-close On and Off |  |  |
| Launch at Login |  |  |
| Safe removal |  |  |
| Notarization and Gatekeeper |  |  |

Privileged acceptance notes:

- First signed launch exposed and resolved three pre-acceptance defects: modern MacBook detection (`289e073`), AppKit delegate bootstrapping (`492de3f`), and helper bundle layout (`f88db32`).
- Service Management raw status 3 is the normal unregistered state, so Setup is now offered from that state (`a14ca8f`).
- macOS recorded the helper and posted approval while synchronous registration reported not-yet-allowed; the final candidate handles that pending-approval race (`7dbbb41`).
- Required manual `sudo /usr/bin/pmset -a disablesleep 0` restores were completed after the registration attempt and before final-candidate privileged testing.
