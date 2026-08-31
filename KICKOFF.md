# Fresh-Session Kickoff Prompt

Copy the prompt below into a new Codex task opened at `/Users/grantisom/Developer/insomnia`.

```text
Implement the Insomnia macOS menu-bar app in this repository.

Before touching code:

1. Read AGENTS.md completely.
2. Read docs/superpowers/specs/2026-08-28-insomnia-menu-bar-app-design.md completely.
3. Read docs/superpowers/plans/2026-08-31-insomnia-implementation.md completely.
4. Use the superpowers:executing-plans skill and follow the implementation plan task by task with its TDD cycles and commits.
5. Verify full Xcode is installed and selected. This Mac previously had only Command Line Tools selected, while XcodeGen 2.45.4 was available. If xcodebuild is missing or xcrun points inside CommandLineTools, stop and ask me to install or select full Xcode. Do not work around that prerequisite with a different architecture.

Important safety boundary: do not register the real helper, request administrator approval, mutate the real pmset setting, restart the Mac, or run a lid-close test until the plan reaches the privileged acceptance step and you have shown me the exact action and received explicit approval. Unit and ordinary integration tests must use fakes and temporary files. After any approved privileged test attempt, restore `sudo /usr/bin/pmset -a disablesleep 0`, including after failures.

Keep the app minimal: AppKit menu bar only, no Dock icon, no main window, no SwiftUI, no third-party runtime dependencies, no networking, no analytics, no updater, and no ordinary idle-sleep features. The required behavior is only the exact lid-close setting controlled by the existing Insomnia and Lullaby aliases.

Work through the entire plan, keep its checklist updated, run verification proportional to each task, and continue until the next genuine user-approval boundary or external prerequisite blocks progress.
```

