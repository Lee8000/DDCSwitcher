# Launch at Login Implementation Plan

> **For Codex:** Use executing-plans to implement this plan task by task. The user approved implementation and publication in this session.

**Goal:** Add an optional current-user login startup control to both applications and publish v1.2.0.

**Architecture:** Keep startup registration independent of action configuration. macOS uses SMAppService.mainApp through a testable state controller. Windows uses a focused registry adapter and quoted executable command; test the adapter under an isolated HKCU key. UI refreshes actual OS state and reports errors locally.

**Tech Stack:** Swift/AppKit/ServiceManagement, C++17/Win32/registry, Swift XCTest, Windows native self-test, GitHub Actions.

### Task 1: Baseline and startup behavior tests
1. Run scripts/test.sh and native-host CMake core tests; require a clean baseline.
2. Add Swift tests for default state, register/unregister, pending approval, failure readback, and demo isolation; run to observe missing feature failure.
3. Add Windows native self-tests for absent startup value, Unicode/space paths, exact command parsing, overlong path preserving prior entry, disable preserving siblings, and failed writes; compile to observe missing API failure.

Files: Tests/DDCSwitcherCoreTests/LoginItemTests.swift, windows/tests/platform_tests.cpp.

### Task 2: macOS adapter and checkbox
1. Implement LoginItemState/Controller in Sources/DDCSwitcherCore/LoginItem.swift with injected status/register/unregister functions; reject demo writes and read status after changes, including errors.
2. Add Sources/DDCSwitcher/LoginItemService.swift wrapping ServiceManagement.mainApp with truthful status mapping.
3. Wire independent startup checkbox/status/system settings button in SettingsWindow.swift and AppDelegate.swift. Refresh on window focus; never invoke switch or persist action drafts during startup changes.
4. Run Swift tests, build signed app, run integration self-test.

### Task 3: Windows adapter and checkbox
1. Add windows/include/startup.hpp and windows/src/startup.cpp. Production Run key is fixed; native tests use a separate HKCU key. Use RAII, strict registry type/size validation, correctly quoted full executable path and 260-character bound. Never write StartupApproved.
2. Wire checkbox plus startup message in app.cpp outside per-action editor. Read on activation/show, disable in demo, catch writes then reread actual state.
3. Link advapi32 and new source in CMakeLists.txt. Cross-build locally and run native Windows tests in CI.

### Task 4: Review, documentation, release
1. Update README.md/windows README, version resources/CMake/plist to 1.2.0.
2. Apply requesting-code-review to request an independent review; address material findings and verify again.
3. Commit/push feature, confirm both CI jobs pass, fast-forward main and confirm final CI.
4. Download final CI artifacts, normalize Windows ZIP separators, package release source and checksums. Publish v1.2.0 in the existing public repository under prior authorization; verify public assets and hashes.
5. Copy release artifacts and concise usage notes into outputs, then clean the feature worktree with finishing-a-development-branch.

## Acceptance
Both checkboxes default off on an unregistered installation, affect only current-user startup, survive window close/reopen through OS state, leave existing shortcut files compatible, expose errors without claiming success, and perform no automatic DDC switching. macOS tests do not change the real login item. Windows registry tests never write the production Run key. Real reboot/login and physical monitor switching remain explicitly untested here.
