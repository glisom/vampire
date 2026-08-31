# Insomnia Release Checklist

Record each result for the exact candidate being tested.

- macOS version:
- Mac model:
- Insomnia version/build:
- Git commit:
- Tester/date:

## Nonprivileged checks

- [ ] All app unit tests pass.
- [ ] All helper unit tests pass.
- [ ] Packaged-app integration tests pass.
- [ ] Bundle layout and static signature checks pass.
- [ ] App and helper contain both `arm64` and `x86_64`.

## Privileged setup and recovery acceptance

Explicit approval is required immediately before this section. These checks temporarily change lid-close sleep. Do not run them unattended.

- [ ] Copy the signed candidate to `/Applications/Insomnia.app` and launch it.
- [ ] Complete the one-time macOS helper approval.
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

- [ ] Build `build/release/Insomnia.dmg` with the selected Developer ID Application identity.
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
| Privileged helper setup |  |  |
| Enable and disable |  |  |
| Quit and crash recovery |  |  |
| Helper relaunch recovery |  |  |
| Restart recovery |  |  |
| Lid-close On and Off |  |  |
| Launch at Login |  |  |
| Safe removal |  |  |
| Notarization and Gatekeeper |  |  |
