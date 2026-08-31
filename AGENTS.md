# Vampire Repository Instructions

## Product Boundary

Vampire is a native macOS menu-bar utility that changes lid-close sleep behavior through `pmset -a disablesleep`. It does not prevent ordinary idle sleep and does not replace Lungo. Its Insomnia-era bundle ID, helper label, target names, and recovery path stay stable for compatibility.

## Canonical Documents

Read these completely before implementation:

- `docs/superpowers/specs/2026-08-28-insomnia-menu-bar-app-design.md`
- `docs/superpowers/plans/2026-08-31-insomnia-implementation.md`

The approved spec governs product behavior. The implementation plan governs sequencing, file boundaries, tests, and commits. If they conflict, stop and ask Grant before changing either document.

## Safety

- Never invoke a shell from the privileged helper.
- The helper may execute only the three fixed `pmset` forms named in the spec.
- Ordinary tests use fakes and temporary marker stores. They must never change the Mac's real power settings.
- Ask Grant immediately before any real helper registration, administrator approval, `pmset` mutation, restart test, or lid-close test.
- After every privileged test attempt, restore `sudo /usr/bin/pmset -a disablesleep 0`, including after failures.
- Never commit signing credentials, Keychain material, notary credentials, Apple IDs, or Developer ID private data.

## Development

- Minimum target: macOS 13 Ventura.
- UI: AppKit status item only. No SwiftUI, Dock icon, or main window.
- Runtime dependencies: Apple frameworks only.
- Use TDD and make the commits specified by the implementation plan.
- Keep files focused by the responsibilities in the plan's File Map.
- Do not expand scope with timers, schedules, shortcuts, updates, telemetry, or automatic activation.
