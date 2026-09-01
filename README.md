# Vampire

Vampire is a native macOS menu-bar utility that changes lid-close sleep behavior. Selecting Keep Mac Awake with Lid Closed applies `pmset -a disablesleep 1`; clearing it applies `pmset -a disablesleep 0`.

Vampire changes lid-close sleep only. It does not prevent ordinary idle sleep, display sleep, or screen locking, and it does not replace Lungo.

Install the latest release from [GitHub Releases](https://github.com/glisom/vampire/releases/latest).

## Requirements

- A MacBook with a built-in lid
- macOS 13 Ventura or newer
- Administrator approval during first-time helper setup

The app has no Dock icon, main window, networking, analytics, updater, or third-party runtime dependency.

## Installation and first launch

1. Download the latest `Vampire.dmg` from [GitHub Releases](https://github.com/glisom/vampire/releases/latest).
2. Open `Vampire.dmg` and drag Vampire to Applications.
3. Launch `/Applications/Vampire.app`.
4. Continue through the one-time helper setup prompt.
5. If macOS requires approval, choose Open System Settings and enable Vampire under Login Items.

Later On and Off changes should not request an administrator password.

## Verify the download

Download `Vampire.dmg.sha256` with the disk image, then run:

```bash
shasum -a 256 -c Vampire.dmg.sha256
```

## Using Vampire

Select Keep Mac Awake with Lid Closed to prevent lid-close sleep. The item does not show a checkmark until the helper successfully changes and verifies the setting.

Clear Keep Mac Awake with Lid Closed to restore normal lid-close sleep. Normal Quit also restores Off and waits for acknowledgement before exiting. A helper restart, app disconnect, or Mac restart likewise normalizes the setting to Off.

## Launch at Login

Launch at Login mirrors the registration state managed by macOS. It defaults Off. Starting at login never turns Vampire On automatically.

## Safe helper removal

Open Setup & Status and choose Remove Helper. Vampire first restores and verifies Off, then unregisters the helper. If restoration fails, the helper remains registered so recovery can be retried.

## Troubleshooting

- Setup Required: open Setup & Status and retry registration or approve Vampire in System Settings.
- Unsupported Mac: Vampire requires a MacBook with a built-in internal battery. Legacy `MacBook*` and modern `Mac*` model identifiers are both supported.
- Error: choose Restore Normal Lid Sleep. Vampire will not claim Off while recovery is unresolved.
- Helper unavailable: confirm the app is installed in `/Applications`, then retry Setup & Status.

For emergency manual restoration, run `sudo /usr/bin/pmset -a disablesleep 0`.

## Privacy

Vampire does not collect data. See [Vampire Privacy](docs/privacy.md) for details. Unified logs exclude passwords, usernames, file contents, and device identifiers.

## Development

Full Xcode 26 or newer and XcodeGen 2.45 or newer are required because the checked-in Icon Composer source requires Xcode 26. Generate and build with:

```bash
xcodegen generate
xcodebuild -project Insomnia.xcodeproj -scheme Insomnia -destination 'platform=macOS' build
```

Ordinary tests use fake command adapters and temporary marker stores. They never register the helper or change the host Mac’s power settings.

```bash
scripts/ci.sh
```

Contributors who need focused runs can use:

```bash
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaHelperTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaIntegrationTests -destination 'platform=macOS' test
```

Real helper registration, real `pmset`, restart, and lid-close testing require explicit approval immediately before execution. Follow [docs/release-checklist.md](docs/release-checklist.md).

## Release

Use a Developer ID Application identity and an existing `notarytool` Keychain profile:

```bash
VAMPIRE_SIGNING_IDENTITY='Developer ID Application: …' scripts/build-release.sh
VAMPIRE_NOTARY_PROFILE='vampire-notary' scripts/notarize.sh build/release/Vampire.dmg
scripts/verify-release.sh build/release/Vampire.dmg
```

Credentials, certificate material, Apple IDs, and Keychain profiles must never be committed.

The Xcode targets, bundle identifier `co.groundwork-ai.insomnia`, helper label, and recovery path retain their original internal names so existing helper approval and the signed XPC contract remain stable.

Official binaries are signed and notarized by Grant Isom. Source builds use the contributor's own signing context.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development and safety boundaries, [SECURITY.md](SECURITY.md) for private vulnerability reporting, and [LICENSE](LICENSE) for the MIT license.
