# Vampire Release Checklist

Record each result for the exact candidate being tested.

- macOS version: 26.6.2 (25G83)
- Mac model: MacBook Pro (Mac17,2, Apple M5)
- Vampire version/build: 0.1.0 (1)
- Signed candidate source commit: `d37023e27cb0ba244caf3956dcc363ffb25362f5`
- `Vampire.dmg` SHA-256: `2b258beae65235e58f32c288529b681a9ca2c4712d6888b12a11586b08ca4fc5`
- Tester/date: Grant Isom / Codex, 2026-09-01 09:11 CDT

## Nonprivileged checks

- [x] All app unit tests pass on the Vampire candidate. (44 tests)
- [x] All helper unit tests pass. (28 tests)
- [x] Packaged-app integration tests pass on `Vampire.app`. (4 tests; 2 expected ad-hoc Team-ID skips)
- [x] Vampire bundle layout, DMG checksum, and static signature checks pass.
- [x] Vampire and the helper contain both `arm64` and `x86_64`.

## Privileged setup and recovery acceptance

Explicit approval is required immediately before this section. These checks temporarily change lid-close sleep. Do not run them unattended.

The results below were recorded against earlier signed candidates on this branch. They have not been repeated against commit `d37023e`; any repeat must respect Grant's standing decision to skip restart-based tests and still requires explicit approval immediately before helper or `pmset` activity.

- [x] Copy the signed candidate to `/Applications/Vampire.app` and launch it.
- [x] Complete the one-time macOS helper approval. (Approved on signed pre-final candidate; helper is enabled and running.)
- [x] Confirm later On and Off actions do not prompt again.
- [x] Turn On and confirm the app reports On only after helper acknowledgement.
- [x] Choose normal Quit while On and confirm Off before exit.
- [x] Turn On, force quit the app, and confirm the helper restores Off.
- [x] Turn On, kill the helper, and confirm launchd relaunch restores Off.
- [x] Turn On, restart the Mac, and confirm Off before using the app after login.
- [ ] Enable Launch at Login, restart/login, and confirm Vampire starts Off. (Restart check skipped by user request; setting was returned to disabled.)
- [ ] Disable Launch at Login and confirm it no longer launches. (Disabled state confirmed in the menu; restart check skipped by user request.)
- [ ] Use Remove Helper and confirm Off is verified before unregistration. (Skipped by user request to preserve the working helper installation.)
- [x] On a MacBook, verify actual lid-close behavior while On.
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
- [ ] Gatekeeper accepts the app with `spctl --assess --type execute`. (Current expected result: `source=Unnotarized Developer ID`.)
- [ ] Test the DMG on a Mac that did not build it.
- [ ] On a clean macOS 13-or-newer account, complete install and one-time approval.
- [ ] Record final result and any failures below.

## Results

| Check | Pass/Fail | Notes |
|---|---|---|
| Privileged helper setup | Pass | Service Management approval completed; daemon is enabled and running. Initial UI falsely reported failure while approval was pending; fixed by `7dbbb41`. |
| Enable and disable | Pass | Signed `/Applications/Vampire.app` reused the approved helper without a new prompt. Wake Vampire reported On only after helper acknowledgement; Turn Off Vampire reported Off; the required explicit restore completed. |
| Quit and crash recovery | Pass | Normal Quit waited for the helper's Off acknowledgement before termination. A `SIGKILL` while On invalidated XPC, and the helper restored Off while remaining healthy. Explicit safety restores followed both attempts. |
| Helper relaunch recovery | Pass | Killing helper PID 25514 left the root-owned recovery marker in place. Turn Off Vampire discarded the interrupted XPC connection, launchd started helper PID 37817, startup normalization completed, the marker cleared, and the app reported Off. The required explicit restore followed. |
| Restart recovery | Pass | The Mac restarted while Vampire was On. Before the app ran after login, launchd had started helper PID 553, `disablesleep` was absent from both reported profiles, and the recovery marker was absent. The required explicit restore followed. |
| Lid-close On and Off | Partial | Grant confirmed the Mac remained usable after the physical lid-close check while Vampire reported On. Vampire was then turned Off and the required explicit restore completed. The normal-sleep Off leg remains pending. |
| Launch at Login | Skipped | The setting successfully toggled On and back Off while Vampire remained Off. Grant chose to skip the two additional restart checks, so launch and non-launch behavior after login remain unverified. |
| Safe removal | Skipped | Grant chose to preserve the installed and approved helper. The fake-backed unit tests pass, but live unregistration was not exercised. |
| Notarization and Gatekeeper | Pending | Candidate signatures and both architectures validate. Notarization is blocked until a `notarytool` Keychain profile is stored; Gatekeeper currently reports the expected `Unnotarized Developer ID`. |

Privileged acceptance notes:

- Commit `d37023e` produced a fresh Developer ID-signed universal DMG with SHA-256 `2b258beae65235e58f32c288529b681a9ca2c4712d6888b12a11586b08ca4fc5`. The app and helper satisfy their designated requirements, both contain `arm64` and `x86_64`, and the bundle contains the Icon Composer-generated `AppIcon` resources. No helper registration, app launch, or power-setting mutation occurred while building or inspecting it.
- The user-facing Vampire rebrand preserves the existing bundle ID, helper label, XPC contract, and recovery path. The signed A+C icon candidate was built and verified without launching the app or changing real power settings.
- The refined menu-bar coffin and crescent in `1300e6c` passed six pixel-level renderer tests, including a regression test for a fully transparent open crescent edge, and received visual approval before this candidate was built.
- That signed icon candidate is superseded by the Task 14 Icon Composer app icon. The current source uses Apple's rounded canvas, three flat vector layers, and generated Default, Dark, and Mono appearances while preserving the approved moon/stars-to-bat menu marks. The replacement signed candidate is built and statically verified; notarization remains pending.
- The first helper-kill attempt safely restored Off but showed that the app retained a dead XPC connection, so the demand-launched helper did not restart. Commit `965c8de` installs the plan-required interruption and invalidation handlers and replaces the dead connection on retry; fake-connection regression coverage and independent review passed before rebuilding this candidate.
- The repaired helper-kill acceptance rerun confirmed the recovery marker existed before PID 25514 was killed. A fresh Turn Off request launched PID 37817 through the replacement XPC connection; helper startup successfully normalized Off and removed the marker before the final explicit safety restore.
- Restart-while-On acceptance confirmed the root helper launched during boot and normalized Off before Vampire ran in the login session. The stale marker was already cleared when checked as root, and the explicit post-test restore succeeded.
- Launch at Login was enabled and then returned to disabled without changing the power state. The restart-based enabled and disabled checks were skipped at Grant's request.
- Live safe removal was skipped at Grant's request so the working helper remains installed and approved.
- Grant reported the physical lid-close behavior worked while Vampire was On. Codex then confirmed the app was still On, turned it Off, and completed the explicit safety restore; the Off physical leg has not yet run.
- Independent review found two helper-originated Insomnia error strings; both are Vampire-branded and covered by helper tests in `da85228`.
- The signed Vampire candidate replaced `/Applications/Insomnia.app`; the previous app remains recoverably backed up at `build/release/acceptance-backup/Insomnia.app`.
- An accidental ad-hoc Xcode Debug launch was rejected by the helper's Team-ID requirement before any `pmset` command ran. Relaunching the Developer-ID-signed `/Applications/Vampire.app` established the authenticated XPC connection and completed the On/Off test without renewed approval.
- Normal Quit while On completed only after Off was acknowledged. Force-quitting the signed app while On caused the helper to observe the client disconnect and restore Off; the helper remained running.
- First signed launch exposed and resolved three pre-acceptance defects: modern MacBook detection (`289e073`), AppKit delegate bootstrapping (`492de3f`), and helper bundle layout (`f88db32`).
- Service Management raw status 3 is the normal unregistered state, so Setup is now offered from that state (`a14ca8f`).
- macOS recorded the helper and posted approval while synchronous registration reported not-yet-allowed; the final candidate handles that pending-approval race (`7dbbb41`).
- Required manual `sudo /usr/bin/pmset -a disablesleep 0` restores were completed after the registration attempt, after the rejected Debug-client attempt, after the signed candidate's successful On/Off test, after normal Quit recovery, and after force-quit recovery. Final `pmset -g custom` output omitted `disablesleep` from both battery and AC profiles.
