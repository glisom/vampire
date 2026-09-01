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
