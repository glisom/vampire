# Insomnia Menu Bar App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a signed, notarizable macOS menu-bar app that toggles lid-close sleep through a one-time-approved privileged helper and always fails safe to normal sleep.

**Architecture:** A native AppKit status-item app registers a bundled `SMAppService` launch daemon and talks to it through a code-signing-restricted XPC interface. The root helper owns a serial state machine, an atomic recovery marker, and a fixed-argument `/usr/bin/pmset` adapter; every disconnect, helper start, and system restart normalizes `disablesleep` to `0`.

**Tech Stack:** Swift 6, AppKit, Foundation XPC, ServiceManagement, Security, OSLog, XCTest, XcodeGen 2.45+, Xcode 16+, macOS 13 deployment target.

**Spec:** `docs/superpowers/specs/2026-08-28-insomnia-menu-bar-app-design.md`

## Global Constraints

- Support macOS 13 Ventura or newer on Apple Silicon and Intel.
- Use AppKit only for UI; no SwiftUI, third-party runtime dependencies, analytics, networking, updater, Dock icon, or main window.
- Use bundle identifier `co.groundwork-ai.insomnia` and helper label/Mach service `co.groundwork-ai.insomnia.helper`.
- The helper may execute only `/usr/bin/pmset -a disablesleep 1`, `/usr/bin/pmset -a disablesleep 0`, and `/usr/bin/pmset -g custom`.
- Never invoke a shell and never accept caller-supplied executable paths or command arguments.
- Unit and ordinary integration tests must use fake command runners and temporary marker stores; they must never change the host Mac's power settings.
- Any test that invokes the real privileged helper or real `pmset` requires explicit user confirmation immediately before it runs.
- Every normal Quit path must confirm Off before terminating.
- Launch at Login defaults Off and never automatically enables Insomnia.
- Use `NSXPCListener.setConnectionCodeSigningRequirement(_:)` before listener activation to pin callers to the main app identifier and the helper's signing team.
- Use TDD for every behavioral task and commit after each task passes its scoped tests.

## File Map

```text
project.yml                                      Deterministic Xcode project definition
.gitignore                                       Xcode and release-output exclusions
Config/Info.plist                                LSUIElement app metadata
Config/Insomnia.entitlements                     Hardened app entitlements
Config/InsomniaHelper.entitlements               Hardened helper entitlements
Insomnia/Sources/AppDelegate.swift               App lifecycle and status-item composition root
Insomnia/Sources/AppModel.swift                  Main-actor app state and user actions
Insomnia/Sources/AppState.swift                  UI state enum and copy
Insomnia/Sources/HardwareSupport.swift           Portable-Mac model and battery preflight
Insomnia/Sources/HelperClient.swift              Privileged XPC client
Insomnia/Sources/HelperRegistration.swift        SMAppService daemon registration/removal
Insomnia/Sources/LaunchAtLoginController.swift   SMAppService.mainApp adapter
Insomnia/Sources/MenuController.swift            NSStatusItem and NSMenu rendering
Insomnia/Sources/SetupPresenter.swift             Native setup, error, and About alerts
InsomniaShared/Sources/Constants.swift            Bundle, service, version, and path constants
InsomniaShared/Sources/HelperState.swift          XPC-safe helper state values
InsomniaShared/Sources/InsomniaHelperXPC.swift    Narrow @objc XPC protocol
InsomniaHelper/Sources/CommandRunner.swift        Foundation Process adapter
InsomniaHelper/Sources/HardwareSupport.swift      Helper-side portable-Mac validation
InsomniaHelper/Sources/PMSetController.swift      Fixed pmset writes and readback parser
InsomniaHelper/Sources/RecoveryMarkerStore.swift  Atomic root-owned active marker
InsomniaHelper/Sources/HelperController.swift     Serialized fail-safe state machine
InsomniaHelper/Sources/HelperService.swift        XPC exported object per connection
InsomniaHelper/Sources/HelperListener.swift       Signing-restricted Mach-service listener
InsomniaHelper/Sources/TeamIdentifier.swift       Helper signing-team lookup
InsomniaHelper/Sources/main.swift                 Startup normalization and listener activation
InsomniaHelper/Resources/co.groundwork-ai.insomnia.helper.plist  Bundled launchd definition
InsomniaTests/*                                   App-model and menu-model XCTest files
InsomniaHelperTests/*                             Parser, marker, and state-machine XCTest files
InsomniaIntegrationTests/*                        XPC signing and packaged-helper checks
scripts/build-release.sh                          Universal archive and DMG creation
scripts/notarize.sh                               notarytool submission and stapling
scripts/verify-release.sh                         codesign, spctl, and stapler checks
docs/release-checklist.md                         Privileged and physical acceptance checks
README.md                                         Install, setup, removal, and troubleshooting
```

---

### Task 1: Deterministic App and Helper Project Skeleton

**Files:**
- Create: `project.yml`
- Create: `.gitignore`
- Create: `Config/Info.plist`
- Create: `Config/Insomnia.entitlements`
- Create: `Config/InsomniaHelper.entitlements`
- Create: `Insomnia/Sources/AppDelegate.swift`
- Create: `InsomniaShared/Sources/Constants.swift`
- Create: `InsomniaHelper/Sources/main.swift`
- Create: `InsomniaHelper/Resources/co.groundwork-ai.insomnia.helper.plist`

**Interfaces:**
- Consumes: Full Xcode selected by `xcode-select`; XcodeGen 2.45+.
- Produces: Buildable `Insomnia`, `InsomniaHelper`, `InsomniaTests`, `InsomniaHelperTests`, and `InsomniaIntegrationTests` schemes; `AppConstants` shared by both executables.

- [x] **Step 1: Verify toolchain prerequisites without installing anything**

Run:

```bash
xcodebuild -version
xcrun --show-sdk-path
xcodegen --version
```

Expected: full Xcode reports version 16 or newer, the SDK path is inside `Xcode.app`, and XcodeGen reports 2.45 or newer. If `xcodebuild` is missing or the SDK remains under `CommandLineTools`, stop and ask Grant to install/select full Xcode.

- [x] **Step 2: Create the project definition and metadata**

Create `project.yml`:

```yaml
name: Insomnia
options:
  minimumXcodeGenVersion: 2.45.0
  deploymentTarget:
    macOS: "13.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
    CODE_SIGN_STYLE: Automatic
    ENABLE_HARDENED_RUNTIME: YES
    MARKETING_VERSION: 0.1.0
    CURRENT_PROJECT_VERSION: 1
    ONLY_ACTIVE_ARCH: NO
targets:
  InsomniaShared:
    type: library.static
    platform: macOS
    sources: [InsomniaShared/Sources]
  InsomniaHelper:
    type: tool
    platform: macOS
    sources: [InsomniaHelper/Sources]
    dependencies:
      - target: InsomniaShared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.groundwork-ai.insomnia.helper
        CODE_SIGN_ENTITLEMENTS: Config/InsomniaHelper.entitlements
        SKIP_INSTALL: YES
  Insomnia:
    type: application
    platform: macOS
    sources: [Insomnia/Sources]
    dependencies:
      - target: InsomniaShared
      - target: InsomniaHelper
    info:
      path: Config/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: co.groundwork-ai.insomnia
        CODE_SIGN_ENTITLEMENTS: Config/Insomnia.entitlements
        ENABLE_USER_SCRIPT_SANDBOXING: NO
    postBuildScripts:
      - name: Embed Privileged Helper
        basedOnDependencyAnalysis: false
        script: |
          set -euo pipefail
          helper_destination="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/MacOS"
          plist_destination="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Library/LaunchDaemons"
          /bin/mkdir -p "$helper_destination" "$plist_destination"
          /usr/bin/install -m 755 "${BUILT_PRODUCTS_DIR}/InsomniaHelper" "$helper_destination/InsomniaHelper"
          /usr/bin/install -m 644 "${SRCROOT}/InsomniaHelper/Resources/co.groundwork-ai.insomnia.helper.plist" "$plist_destination/co.groundwork-ai.insomnia.helper.plist"
          identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
          /usr/bin/codesign --force --sign "$identity" --options runtime --timestamp=none --entitlements "${SRCROOT}/Config/InsomniaHelper.entitlements" "$helper_destination/InsomniaHelper"
  InsomniaTests:
    type: bundle.unit-test
    platform: macOS
    sources: [InsomniaTests]
    dependencies:
      - target: Insomnia
  InsomniaHelperTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: InsomniaHelperTests
      - path: InsomniaHelper/Sources
        excludes: [main.swift]
    dependencies:
      - target: InsomniaShared
  InsomniaIntegrationTests:
    type: bundle.unit-test
    platform: macOS
    sources: [InsomniaIntegrationTests]
    dependencies:
      - target: Insomnia
      - target: InsomniaShared
schemes:
  Insomnia:
    build:
      targets:
        Insomnia: all
  InsomniaTests:
    build:
      targets:
        Insomnia: all
        InsomniaTests: [test]
    test:
      targets: [InsomniaTests]
  InsomniaHelperTests:
    build:
      targets:
        InsomniaHelperTests: [test]
    test:
      targets: [InsomniaHelperTests]
  InsomniaIntegrationTests:
    build:
      targets:
        Insomnia: all
        InsomniaIntegrationTests: [test]
    test:
      targets: [InsomniaIntegrationTests]
```

Create `.gitignore`:

```gitignore
.DS_Store
/Insomnia.xcodeproj/
/build/
/DerivedData/
*.xcuserstate
xcuserdata/
```

The app post-build phase copies the helper executable to `Contents/MacOS`, copies only the daemon plist to `Contents/Library/LaunchDaemons`, and signs the embedded helper with the active build identity before the outer app is signed. This is the `SMAppService.daemon` bundle layout documented by Apple.

The launchd plist must contain exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>co.groundwork-ai.insomnia.helper</string>
  <key>BundleProgram</key>
  <string>Contents/MacOS/InsomniaHelper</string>
  <key>MachServices</key>
  <dict>
    <key>co.groundwork-ai.insomnia.helper</key>
    <true/>
  </dict>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

Create `Config/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key><string>Insomnia</string>
  <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key><string>$(CURRENT_PROJECT_VERSION)</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
```

Create both entitlements files with this exact content; Hardened Runtime comes from `ENABLE_HARDENED_RUNTIME = YES`. Do not enable App Sandbox.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
```

- [x] **Step 3: Add minimal compilation stubs**

Create `InsomniaShared/Sources/Constants.swift`:

```swift
import Foundation

public enum AppConstants {
    public static let appBundleID = "co.groundwork-ai.insomnia"
    public static let helperLabel = "co.groundwork-ai.insomnia.helper"
    public static let helperPlistName = "co.groundwork-ai.insomnia.helper.plist"
    public static let helperVersion = "1"
    public static let recoveryDirectory = URL(fileURLWithPath: "/Library/Application Support/Insomnia", isDirectory: true)
    public static let recoveryMarker = recoveryDirectory.appendingPathComponent("active.plist")
}
```

Create an `@main` AppKit `AppDelegate` that terminates after the last window closes is disabled, and create helper `main.swift` that exits with status `0`. These are temporary compilation stubs only; later tasks replace behavior without changing target names.

- [x] **Step 4: Generate the Xcode project and build every target**

Run:

```bash
xcodegen generate
xcodebuild -project Insomnia.xcodeproj -scheme Insomnia -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaTests -configuration Debug -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaHelperTests -configuration Debug -destination 'platform=macOS' test
```

Expected: all commands exit `0`, and the built app contains `Contents/MacOS/InsomniaHelper` plus the plist under `Contents/Library/LaunchDaemons`.

- [x] **Step 5: Commit the skeleton**

```bash
git add project.yml .gitignore Config Insomnia InsomniaShared InsomniaHelper
git commit -m "build: scaffold Insomnia app and helper targets"
```

---

### Task 2: Shared XPC Contract and State Values

**Files:**
- Create: `InsomniaShared/Sources/HelperState.swift`
- Create: `InsomniaShared/Sources/InsomniaHelperXPC.swift`
- Create: `InsomniaHelperTests/SharedContractTests.swift`

**Interfaces:**
- Consumes: `AppConstants.helperVersion` from Task 1.
- Produces: `HelperState`, `HelperErrorCode`, and `InsomniaHelperXPC` used by the helper service and app client.

- [x] **Step 1: Write failing contract tests**

Test exact raw values and round trips:

```swift
func testHelperStateRawValuesAreStable() {
    XCTAssertEqual(HelperState.off.rawValue, 0)
    XCTAssertEqual(HelperState.on.rawValue, 1)
    XCTAssertEqual(HelperState.error.rawValue, 2)
}

func testUnknownStateFallsBackToError() {
    XCTAssertEqual(HelperState(xpcValue: 99), .error)
}
```

- [x] **Step 2: Run the focused test and verify failure**

Run:

```bash
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaHelperTests -destination 'platform=macOS' -only-testing:InsomniaHelperTests/SharedContractTests test
```

Expected: FAIL because `HelperState` is undefined.

- [x] **Step 3: Implement stable XPC values and protocol**

Use:

```swift
import Foundation

public enum HelperState: Int {
    case off = 0
    case on = 1
    case error = 2

    public init(xpcValue: Int) { self = HelperState(rawValue: xpcValue) ?? .error }
}

public enum HelperErrorCode: Int {
    case none = 0
    case unsupportedHardware = 1
    case commandFailed = 2
    case verificationFailed = 3
    case markerFailed = 4
    case recoveryFailed = 5
}

@objc public protocol InsomniaHelperXPC {
    func getStatus(reply: @escaping (Int, String, Int, String?) -> Void)
    func setEnabled(_ enabled: Bool, reply: @escaping (Int, Int, String?) -> Void)
}
```

The `getStatus` reply is state raw value, helper version, error raw value, and optional message. The `setEnabled` reply is state raw value, error raw value, and optional message.

- [x] **Step 4: Run shared contract tests**

Expected: PASS.

- [x] **Step 5: Commit the contract**

```bash
git add InsomniaShared InsomniaHelperTests/SharedContractTests.swift
git commit -m "feat: define privileged helper XPC contract"
```

---

### Task 3: Fixed PMSet Adapter and Verification Parser

**Files:**
- Create: `InsomniaHelper/Sources/CommandRunner.swift`
- Create: `InsomniaHelper/Sources/HardwareSupport.swift`
- Create: `InsomniaHelper/Sources/PMSetController.swift`
- Create: `InsomniaHelperTests/PMSetControllerTests.swift`

**Interfaces:**
- Consumes: no prior runtime interface.
- Produces: `CommandRunning.run(executable:arguments:)`, `HardwareChecking.isSupportedMacBook`, and `PowerSettingsManaging.setSleepDisabled(_:)`.

- [x] **Step 1: Write failing command-policy and parser tests**

Use a recording fake and cover:

```swift
func testEnableUsesOnlyFixedPMSetArguments() throws {
    let runner = RecordingCommandRunner(results: [.init(exitCode: 0, stdout: "", stderr: ""), .init(exitCode: 0, stdout: "AC Power:\n disablesleep 1\nBattery Power:\n disablesleep 1\n", stderr: "")])
    let sut = PMSetController(runner: runner, hardware: SupportedHardware())
    try sut.setSleepDisabled(true)
    XCTAssertEqual(runner.calls, [
        .init(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "1"]),
        .init(executable: "/usr/bin/pmset", arguments: ["-g", "custom"])
    ])
}

func testReadbackMismatchThrowsVerificationFailed() {
    let runner = RecordingCommandRunner(results: [
        .init(exitCode: 0, stdout: "", stderr: ""),
        .init(exitCode: 0, stdout: "AC Power:\n disablesleep 0\n", stderr: "")
    ])
    let sut = PMSetController(runner: runner, hardware: SupportedHardware())
    XCTAssertThrowsError(try sut.setSleepDisabled(true)) {
        XCTAssertEqual($0 as? PMSetError, .verificationFailed)
    }
}

func testMissingReadbackKeyAcceptsSuccessfulWriteOnlyOnMacBook() {
    let successfulWriteWithoutKey = [
        CommandResult(exitCode: 0, stdout: "", stderr: ""),
        CommandResult(exitCode: 0, stdout: "AC Power:\n sleep 1\n", stderr: "")
    ]
    XCTAssertNoThrow(try PMSetController(
        runner: RecordingCommandRunner(results: successfulWriteWithoutKey),
        hardware: SupportedHardware()
    ).setSleepDisabled(true))
    XCTAssertThrowsError(try PMSetController(
        runner: RecordingCommandRunner(results: successfulWriteWithoutKey),
        hardware: UnsupportedHardware()
    ).setSleepDisabled(true)) {
        XCTAssertEqual($0 as? PMSetError, .unsupportedHardware)
    }
}
```

- [x] **Step 2: Run the focused test and verify failure**

Expected: FAIL because the adapter types are undefined.

- [x] **Step 3: Implement the runner and controller**

Define:

```swift
struct CommandResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol CommandRunning {
    func run(executable: URL, arguments: [String]) throws -> CommandResult
}

protocol HardwareChecking { var isSupportedMacBook: Bool { get } }

protocol PowerSettingsManaging {
    func setSleepDisabled(_ disabled: Bool) throws
    func readSleepDisabled() throws -> Bool?
}

enum PMSetError: Error, Equatable {
    case unsupportedHardware
    case commandFailed(Int32, String)
    case verificationFailed
}
```

`ProcessCommandRunner` must set `Process.executableURL` directly to `/usr/bin/pmset`, pass the exact argument array, capture stdout/stderr through pipes, and never call `/bin/sh`, `zsh`, `bash`, `system`, or `NSTask.launchPath` with user data. `PMSetController` accepts only a `Bool`; it owns all argument construction.

Parse every line matching optional whitespace plus `disablesleep` plus `0` or `1`. Return `nil` when no such line exists. Throw verification failure if reported profiles disagree with each other or the requested value.

- [x] **Step 4: Run PMSet tests and the full helper test suite**

Expected: PASS and the recording fake shows no command other than the three spec-approved forms.

- [x] **Step 5: Commit the adapter**

```bash
git add InsomniaHelper/Sources InsomniaHelperTests/PMSetControllerTests.swift
git commit -m "feat: add fixed pmset power settings adapter"
```

---

### Task 4: Atomic Recovery Marker and Fail-Safe State Machine

**Files:**
- Create: `InsomniaHelper/Sources/RecoveryMarkerStore.swift`
- Create: `InsomniaHelper/Sources/HelperController.swift`
- Create: `InsomniaHelperTests/RecoveryMarkerStoreTests.swift`
- Create: `InsomniaHelperTests/HelperControllerTests.swift`

**Interfaces:**
- Consumes: `PowerSettingsManaging` and `HelperState`.
- Produces: `RecoveryMarkerStoring`, `HelperResult`, and serialized methods `normalizeAtStartup()`, `setEnabled(_:)`, and `connectionInvalidated()`.

- [x] **Step 1: Write failing marker tests**

Cover atomic creation, `0600` marker permissions, existence, and removal using a unique temporary directory. Assert the plist contains only `active = true`.

- [x] **Step 2: Write failing state-machine tests**

Cover these exact orderings with recording fakes:

```swift
func testEnableWritesMarkerBeforePMSet() {
    let recorder = EventRecorder()
    let sut = makeController(recorder: recorder)
    XCTAssertEqual(sut.setEnabled(true).state, .on)
    XCTAssertEqual(recorder.events, [.createMarker, .setPower(true)])
}

func testDisableSetsPMSetBeforeRemovingMarker() {
    let recorder = EventRecorder()
    let sut = makeController(markerExists: true, recorder: recorder)
    XCTAssertEqual(sut.setEnabled(false).state, .off)
    XCTAssertEqual(recorder.events, [.setPower(false), .removeMarker])
}

func testEnableFailureAttemptsOffRecoveryAndReturnsError() {
    let recorder = EventRecorder()
    let sut = makeController(enableError: PMSetError.commandFailed(1, "failed"), recorder: recorder)
    XCTAssertEqual(sut.setEnabled(true).state, .error)
    XCTAssertEqual(recorder.events, [.createMarker, .setPower(true), .setPower(false), .removeMarker])
}

func testStartupAlwaysNormalizesOffWithoutMarker() {
    let recorder = EventRecorder()
    let sut = makeController(recorder: recorder)
    XCTAssertEqual(sut.normalizeAtStartup().state, .off)
    XCTAssertEqual(recorder.events, [.setPower(false)])
}

func testStartupClearsStaleMarkerOnlyAfterOffSucceeds() {
    let recorder = EventRecorder()
    let sut = makeController(markerExists: true, recorder: recorder)
    XCTAssertEqual(sut.normalizeAtStartup().state, .off)
    XCTAssertEqual(recorder.events, [.setPower(false), .removeMarker])
}

func testDisconnectWhileOnRestoresOff() {
    let recorder = EventRecorder()
    let sut = makeController(markerExists: true, recorder: recorder)
    sut.connectionInvalidated()
    XCTAssertEqual(recorder.events, [.setPower(false), .removeMarker])
}

func testFailedRecoveryRetainsMarkerAndErrorState() {
    let recorder = EventRecorder()
    let marker = RecordingMarkerStore(exists: true, recorder: recorder)
    let sut = makeController(marker: marker, disableError: PMSetError.commandFailed(1, "failed"), recorder: recorder)
    XCTAssertEqual(sut.normalizeAtStartup().state, .error)
    XCTAssertTrue(marker.exists)
    XCTAssertEqual(recorder.events, [.setPower(false)])
}

func testEnableIsRejectedWhileRecoveryIsUnresolved() {
    let recorder = EventRecorder()
    let marker = RecordingMarkerStore(exists: true, recorder: recorder)
    let sut = makeController(marker: marker, disableError: PMSetError.commandFailed(1, "failed"), recorder: recorder)
    XCTAssertEqual(sut.normalizeAtStartup().state, .error)
    XCTAssertEqual(sut.setEnabled(true).error, .recoveryFailed)
    XCTAssertEqual(recorder.events, [.setPower(false)])
}
```

- [x] **Step 3: Run focused tests and verify failure**

Expected: FAIL because the marker and controller are undefined.

- [x] **Step 4: Implement marker storage and controller**

Define:

```swift
protocol RecoveryMarkerStoring {
    var exists: Bool { get }
    func create() throws
    func remove() throws
}

struct HelperResult {
    let state: HelperState
    let error: HelperErrorCode
    let message: String?
}
```

`HelperController` owns a private serial `DispatchQueue`. Every public operation executes synchronously on that queue. Startup always requests Off first. Enable creates the marker before requesting On. Disable requests Off before removing the marker. Disconnect checks the marker and performs disable recovery. Recovery failure retains the marker and state `.error`; while that state and marker persist, enable requests return `.recoveryFailed` without attempting On.

- [x] **Step 5: Run helper tests**

Expected: PASS, including event-order assertions.

- [x] **Step 6: Commit recovery behavior**

```bash
git add InsomniaHelper/Sources InsomniaHelperTests
git commit -m "feat: add fail-safe helper recovery state machine"
```

---

### Task 5: Code-Signing-Restricted Privileged XPC Helper

**Files:**
- Create: `InsomniaHelper/Sources/TeamIdentifier.swift`
- Create: `InsomniaHelper/Sources/HelperService.swift`
- Create: `InsomniaHelper/Sources/HelperListener.swift`
- Modify: `InsomniaHelper/Sources/main.swift`
- Create: `InsomniaHelperTests/SigningRequirementTests.swift`
- Create: `InsomniaHelperTests/HelperServiceTests.swift`

**Interfaces:**
- Consumes: `InsomniaHelperXPC`, `HelperController`, `AppConstants.appBundleID`, and `AppConstants.helperLabel`.
- Produces: live privileged Mach service `co.groundwork-ai.insomnia.helper` and a pure `SigningRequirementBuilding.requirement(appIdentifier:teamIdentifier:)` function.

- [x] **Step 1: Write failing signing-requirement tests**

Assert this exact result for team `ABCDE12345`:

```text
identifier "co.groundwork-ai.insomnia" and anchor apple generic and certificate leaf[subject.OU] = "ABCDE12345"
```

Reject an empty team identifier before creating the listener.

- [x] **Step 2: Write failing helper-service tests**

Verify `getStatus` maps controller results to stable raw values, `setEnabled` delegates exactly once, and invalidating an accepted connection calls `connectionInvalidated()` exactly once.

- [x] **Step 3: Implement signing-team lookup and listener**

Use `SecCodeCopySelf` and `SecCodeCopySigningInformation` with `kSecCSSigningInformation`; read `kSecCodeInfoTeamIdentifier` as a nonempty `String`. Build the requirement through the tested pure function.

In `HelperListener.start()`:

```swift
let listener = NSXPCListener(machServiceName: AppConstants.helperLabel)
try listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = self
listener.activate()
RunLoop.current.run()
```

In the delegate, assign `NSXPCInterface(with: InsomniaHelperXPC.self)`, export one `HelperService` per accepted connection, install an invalidation handler that calls controller recovery once, then activate the connection.

- [x] **Step 4: Replace helper main with fail-safe startup**

Construct `ProcessCommandRunner`, helper-side `MacBookHardwareSupport`, `PMSetController`, `FileRecoveryMarkerStore` at the fixed path, and `HelperController`. Call `normalizeAtStartup()` before creating the listener. If it returns Error, still start the listener so the app can display the failure and retry Off; never attempt On during startup.

- [x] **Step 5: Run helper tests and unsigned Debug build**

Expected: unit tests PASS and Debug build succeeds. Do not register or launch the real daemon yet.

- [x] **Step 6: Commit secure XPC helper**

```bash
git add InsomniaHelper InsomniaHelperTests
git commit -m "feat: expose helper through signed XPC service"
```

---

### Task 6: App-Side Registration, Hardware Preflight, and XPC Client

**Files:**
- Create: `Insomnia/Sources/AppState.swift`
- Create: `Insomnia/Sources/HardwareSupport.swift`
- Create: `Insomnia/Sources/HelperRegistration.swift`
- Create: `Insomnia/Sources/HelperClient.swift`
- Create: `InsomniaTests/HardwareSupportTests.swift`
- Create: `InsomniaTests/HelperRegistrationTests.swift`
- Create: `InsomniaTests/HelperClientTests.swift`

**Interfaces:**
- Consumes: `InsomniaHelperXPC`, `AppConstants.helperLabel`, and `AppConstants.helperPlistName`.
- Produces: `AppState`, `HelperRegistering`, and `HelperClientProtocol` for `AppModel`.

- [x] **Step 1: Write failing hardware and state tests**

Define legacy identifiers beginning with `MacBook` as supported. Per the 2026-08-31 approved portable-hardware amendment, also support modern identifiers beginning with `Mac` when I/O Kit reports `kIOPSInternalBatteryType`. Test `MacBookPro18,3`, `MacBookAir10,1`, and `Mac17,2` with an internal battery as supported; test modern `Mac` identifiers without an internal battery, `iMac21,1`, and empty strings as Unsupported. Apply the same rule and tests to the helper-side hardware check.

Define:

```swift
enum AppState: Equatable {
    case setupRequired
    case unsupported
    case off
    case on
    case error(String)
}
```

- [x] **Step 2: Write failing registration tests**

Wrap `SMAppService.Status` in a local enum so tests do not register anything. Verify `.notRegistered` maps to Setup Required, `.requiresApproval` maps to Setup Required plus `needsSystemSettings = true`, `.enabled` allows XPC connection, and `.notFound` maps to a clear configuration error.

- [x] **Step 3: Write failing client tests**

Using a fake XPC transport, verify status raw values map to AppState, connection errors map to Error, an unknown helper state maps to Error, and no callback is delivered off the main actor.

- [x] **Step 4: Implement adapters**

`HelperRegistration` owns `SMAppService.daemon(plistName: AppConstants.helperPlistName)`. Its register and unregister methods surface typed results and never modify the power setting themselves.

`HelperClient` creates:

```swift
NSXPCConnection(machServiceName: AppConstants.helperLabel, options: .privileged)
```

Assign `remoteObjectInterface`, interruption and invalidation handlers, then activate. All public completion handlers hop to `MainActor`. Never issue On until helper registration status is enabled and hardware is supported.

- [x] **Step 5: Run app tests**

Expected: PASS without any daemon registration or `pmset` invocation.

- [x] **Step 6: Commit app infrastructure**

```bash
git add Insomnia/Sources InsomniaTests
git commit -m "feat: add helper setup and XPC client infrastructure"
```

---

### Task 7: Main-Actor App Model and Menu-Bar UI

**Files:**
- Create: `Insomnia/Sources/AppModel.swift`
- Create: `Insomnia/Sources/MenuController.swift`
- Create: `Insomnia/Sources/SetupPresenter.swift`
- Modify: `Insomnia/Sources/AppDelegate.swift`
- Create: `InsomniaTests/AppModelTests.swift`
- Create: `InsomniaTests/MenuPresentationTests.swift`

**Interfaces:**
- Consumes: `AppState`, `HelperRegistering`, `HelperClientProtocol`, and hardware support.
- Produces: menu actions `toggleInsomnia()`, `setLaunchAtLogin(_:)`, `showSetupStatus()`, `showAbout()`, and `quit()`.

- [x] **Step 1: Write failing AppModel transition tests**

Cover:

```swift
func testStartOnUnsupportedMacNeverRegistersHelper()
func testStartWithUnregisteredHelperShowsSetupRequired()
func testEnableReportsOnOnlyAfterHelperAcknowledgesOn()
func testEnableFailureShowsError()
func testDisableReportsOffOnlyAfterHelperAcknowledgesOff()
func testQuitWhileOnDisablesBeforeTerminating()
func testQuitFailureKeepsAppRunningInError()
```

Use injected closures for termination and alert presentation; tests must not call `NSApp.terminate`.

- [x] **Step 2: Write failing menu-presentation tests**

Extract a pure `MenuPresentation` value containing status title, primary action title, symbol name, primary enabled flag, and error detail. Assert:

| State | Status | Action | Symbol |
|---|---|---|---|
| Setup Required | `Insomnia: Setup Required` | `Set Up Insomnia…` | `moon.zzz` |
| Unsupported | `Insomnia: Unsupported Mac` | disabled | `exclamationmark.triangle` |
| Off | `Insomnia: Off` | `Turn Insomnia On` | `moon.zzz` |
| On | `Insomnia: On` | `Restore Lullaby` | `moon.zzz.fill` |
| Error | `Insomnia: Error` | `Retry Restore Lullaby` | `exclamationmark.triangle.fill` |

- [x] **Step 3: Implement model and menu controller**

Mark `AppModel` and `MenuController` `@MainActor`. `MenuController` owns one `NSStatusItem`, rebuilds a small `NSMenu` whenever presentation changes, and uses only SF Symbols. It creates no window and no custom image asset.

The exact menu order is status, primary action, separator, Launch at Login, Setup Status, About Insomnia, Quit. Setup and errors use `NSAlert`; About uses `NSApp.orderFrontStandardAboutPanel`.

- [x] **Step 4: Compose the app in AppDelegate**

Instantiate production hardware support, registration, helper client, launch-at-login controller, presenter, model, and menu controller. Retain them for the app lifetime. Start the model from `applicationDidFinishLaunching`.

- [x] **Step 5: Run all app tests and build**

Expected: PASS and the app builds without registering the daemon during tests.

- [x] **Step 6: Commit menu app**

```bash
git add Insomnia InsomniaTests
git commit -m "feat: add fail-safe menu bar experience"
```

---

### Task 8: Launch at Login, Setup Status, and Safe Helper Removal

**Files:**
- Create: `Insomnia/Sources/LaunchAtLoginController.swift`
- Modify: `Insomnia/Sources/AppModel.swift`
- Modify: `Insomnia/Sources/MenuController.swift`
- Modify: `Insomnia/Sources/SetupPresenter.swift`
- Create: `InsomniaTests/LaunchAtLoginControllerTests.swift`
- Create: `InsomniaTests/SafeRemovalTests.swift`

**Interfaces:**
- Consumes: `SMAppService.mainApp`, `HelperClientProtocol.setEnabled(false)`, and `HelperRegistering.unregister()`.
- Produces: launch-at-login checkbox state and a removal sequence that cannot unregister before Off acknowledgement.

- [x] **Step 1: Write failing Launch at Login tests**

Verify default Off, enabled/disabled status reflection, register/unregister error mapping, and that app launch never calls helper enable.

- [x] **Step 2: Write failing safe-removal tests**

Assert exact event order `[setEnabled(false), unregisterHelper]`. If Off fails, assert unregister is never called. If unregister fails after Off, show the registration error while state remains Off.

- [x] **Step 3: Implement Launch at Login adapter**

Wrap `SMAppService.mainApp` behind a protocol with `status`, `register()`, and `unregister()`. The checkbox mirrors actual service status rather than persisting an independent `UserDefaults` boolean.

- [x] **Step 4: Implement Setup Status and Remove Helper**

Setup Status displays helper registration state and buttons appropriate to that state: Approve in System Settings, Retry Registration, Remove Helper, or Done. Open System Settings only after a user click. Remove Helper must first confirm Off through XPC, then unregister the daemon.

- [x] **Step 5: Run app tests**

Expected: PASS, with no real ServiceManagement mutation.

- [x] **Step 6: Commit lifecycle controls**

```bash
git add Insomnia InsomniaTests
git commit -m "feat: add login launch and safe helper removal"
```

---

### Task 9: Packaged-App and Security Integration Checks

**Files:**
- Create: `InsomniaIntegrationTests/BundleLayoutTests.swift`
- Create: `InsomniaIntegrationTests/SigningRequirementIntegrationTests.swift`
- Create: `scripts/check-bundle.sh`

**Interfaces:**
- Consumes: built `Insomnia.app`, embedded helper, launchd plist, and code-signing requirement builder.
- Produces: automated evidence that the bundle layout and signing restrictions match the design without registering the daemon.

- [x] **Step 1: Write failing bundle-layout tests**

Locate the built app via test environment. Assert the helper and plist exist under `Contents/Library/LaunchDaemons`, the app has `LSUIElement = true`, the daemon label and Mach service are exact, `RunAtLoad = true`, and `BundleProgram` points to the embedded helper.

- [x] **Step 2: Write failing signing tests**

Use `SecStaticCodeCreateWithPath` plus `SecCodeCopySigningInformation` to assert app and helper have the same nonempty Team Identifier in signed configurations. Compile a small wrong-identifier test client target, and assert its signature fails the generated requirement with `SecStaticCodeCheckValidity`.

- [x] **Step 3: Implement the bundle-check script**

`scripts/check-bundle.sh` accepts one app path, validates explicit nonempty input, runs `plutil -lint` on both plists, `codesign --verify --deep --strict --verbose=2`, and checks expected embedded paths. It performs no registration and no power-setting mutation.

- [x] **Step 4: Run integration checks**

Run:

```bash
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaIntegrationTests -configuration Debug -destination 'platform=macOS' test
scripts/check-bundle.sh "$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*Build/Products/Debug/Insomnia.app' -print -quit)"
```

Expected: PASS without an administrator prompt.

- [x] **Step 5: Commit integration checks**

```bash
git add InsomniaIntegrationTests scripts/check-bundle.sh
git commit -m "test: verify helper packaging and signing policy"
```

---

### Task 10: Release, Notarization, Documentation, and Privileged Acceptance

**Files:**
- Create: `scripts/build-release.sh`
- Create: `scripts/notarize.sh`
- Create: `scripts/verify-release.sh`
- Create: `docs/release-checklist.md`
- Create: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: complete app, Developer ID Application identity, full Xcode, and a notarytool Keychain profile named by the caller.
- Produces: `build/release/Insomnia.dmg` and an auditable release checklist.

- [x] **Step 1: Write shell-script smoke tests**

Run each script with missing arguments and assert a nonzero exit plus usage text. Run `bash -n scripts/*.sh` and ShellCheck if installed; do not install ShellCheck solely for this task.

- [x] **Step 2: Implement deterministic release build**

`build-release.sh` must:

1. Require `INSOMNIA_SIGNING_IDENTITY` to be nonempty.
2. Regenerate the Xcode project.
3. Archive Release for `generic/platform=macOS` with `ARCHS="arm64 x86_64"` and `ONLY_ACTIVE_ARCH=NO`.
4. Export/copy the signed app into a fresh `build/release/dmg-root` directory.
5. Create an `Applications` symlink in that directory.
6. Use `hdiutil create -fs HFS+ -volname Insomnia -srcfolder ... build/release/Insomnia.dmg`.
7. Never print certificates, Keychain credentials, or environment secrets.

- [x] **Step 3: Implement notarization and verification**

`notarize.sh` requires the DMG path and a nonempty `INSOMNIA_NOTARY_PROFILE`, then runs:

```bash
xcrun notarytool submit "$dmg" --keychain-profile "$INSOMNIA_NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
```

`verify-release.sh` mounts the DMG read-only in a `mktemp -d` mountpoint, verifies app and nested helper signatures with `codesign`, runs `spctl --assess --type execute`, runs `xcrun stapler validate`, confirms both `arm64` and `x86_64` with `lipo -archs`, then detaches the image in a trap.

- [x] **Step 4: Write README and release checklist**

README sections: scope, requirements, installation, first-run helper approval, On/Off behavior, Launch at Login, safe helper removal, troubleshooting, privacy, development, tests, and release commands. State explicitly that Insomnia changes lid-close sleep only and does not replace Lungo.

The release checklist must include: clean-account install, one-time approval, On/Off without repeated prompts, normal Quit, force Quit, helper kill/relaunch, restart while On, Launch at Login both states, Remove Helper, actual lid-close test On and Off, Gatekeeper test on a Mac that did not build the app, and final `pmset -a disablesleep 0` confirmation.

- [x] **Step 5: Run all nonprivileged verification**

Run:

```bash
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaHelperTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaIntegrationTests -destination 'platform=macOS' test
bash -n scripts/*.sh
```

Expected: PASS.

- [ ] **Step 6: Ask for explicit approval, then run privileged acceptance**

Before registering the helper or changing the real power setting, show Grant the exact commands and explain that the test temporarily changes lid-close sleep. After approval, execute `docs/release-checklist.md` in order. End every attempt, including failures, by restoring:

```bash
sudo /usr/bin/pmset -a disablesleep 0
```

Record pass/fail and macOS/build version in the checklist. Do not notarize until every earlier acceptance item passes.

- [ ] **Step 7: Build, notarize, and verify the release DMG**

Run the three release scripts with the selected Developer ID identity and stored notary profile. Expected: notary status Accepted, stapler validation success, Gatekeeper acceptance, and both architectures present.

- [x] **Step 8: Commit release tooling and docs**

```bash
git add .gitignore README.md docs/release-checklist.md scripts
git commit -m "release: add notarized direct distribution workflow"
```

---

## Final Verification

- [ ] Confirm `git status --short` is empty.
- [ ] Confirm all three test schemes pass from a clean build.
- [ ] Confirm no source or test invokes a shell for helper operations.
- [ ] Confirm repository search finds no network, analytics, updater, or automatic-On behavior.
- [ ] Confirm the recovery marker is created before On and removed only after verified Off.
- [ ] Confirm the final app, helper, and DMG signatures and notarization ticket validate.
- [ ] Confirm the final physical state is `disablesleep 0`.
