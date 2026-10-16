# DDC Switcher

Switch external monitor inputs over **DDC/CI** using configurable global keyboard shortcuts.

**Native macOS menu-bar app · Native Windows tray app · Optional launch at login · MIT**

[中文说明](README.md) · [Latest release](https://github.com/Lee8000/DDCSwitcher/releases/latest) · [Windows guide](windows/README.md) · [MIT license](LICENSE)

## Features

- Record a separate global shortcut for each input action, or trigger actions from the menu bar or tray.
- Save multiple actions and bind monitors by stable device identifiers; disconnected targets are not replaced automatically.
- Choose common HDMI, DisplayPort and USB-C input codes, or enter a custom decimal value from 0 to 65535. The macOS version also offers LG alternate control.
- Keep shortcuts active after closing the settings window, with optional launch at login on both platforms.
- Store configuration locally, preserve it across updates, back up invalid settings, and explore the UI in a demo mode without controlling hardware.

## Download and requirements

Current release: [v1.2.0](https://github.com/Lee8000/DDCSwitcher/releases/tag/v1.2.0), adding launch-at-login controls to both platforms.

| Platform | Requirements | Download | Guide |
| --- | --- | --- | --- |
| macOS | macOS 13+, Apple Silicon (M1 or later) | [macOS arm64 ZIP](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.2.0/DDCSwitcher-v1.2.0-macOS-arm64.zip) | [macOS quick start](#macos-quick-start) |
| Windows | Windows 10/11, x64 | [Windows x64 ZIP](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.2.0/DDCSwitcher-v1.2.0-windows-x64.zip) | [Windows guide](windows/README.md) |

[SHA-256 checksums](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.2.0/DDCSwitcher-v1.2.0-SHA256SUMS.txt) · [All releases](https://github.com/Lee8000/DDCSwitcher/releases)

Both platforms require an external monitor with DDC/CI enabled and a connection that passes DDC commands. Presets are monitor-specific conventions, not guaranteed capabilities. The portable Windows app requires no extra runtime or administrator privileges. The packaged macOS app requires no Homebrew, accessibility permission or screen recording permission. Each platform stores its own configuration.

## Launch at login

Keep the app at a fixed location, then enable **“登录后自动启动”** in settings. The option is off by default and applies immediately to the current user, independently of saving actions. At login, saved shortcuts load and the app runs in the menu bar or tray without automatically switching inputs.

- **macOS:** place the app in Applications or another permanent location. If approval is required, use the adjacent “系统登录项…” button to open system login-item settings and allow it.
- **Windows:** after moving the executable, turn the option off and on to update its path. The checkbox reports whether the Run entry is registered; if disabled in Task Manager, re-enable it in Windows Startup Apps.

Demo mode cannot change startup registration. Disable the option before uninstalling. Actual reboot/login still needs verification on the target computer; see [verification](docs/VERIFICATION.md).

## Windows quick start

1. Extract the Windows ZIP to a permanent folder and run `DDCSwitcher.exe`.
2. Enable DDC/CI in the monitor menu, then refresh the monitor list. Prefer a direct connection and extended display mode.
3. Add an action, select its monitor and input, record a shortcut such as **Ctrl+Alt+1**, then save and enable it.
4. Add other input actions with different shortcuts. Close the window to keep the app in the tray; double-click its tray icon to open settings or right-click to switch inputs or quit.

See the [Windows guide](windows/README.md) for input codes, connection limits, configuration paths and build instructions. The sections below describe macOS.

## macOS quick start

1. Open `DDCSwitcher.app` and enable DDC/CI in the monitor's on-screen menu.
2. Refresh the monitor list and add an action.
3. Select a monitor, control method and input preset, or enter a custom decimal input code.
4. Click the shortcut control and press a combination such as Control–Option–Command–1. Command or Control is required. Escape cancels recording.
5. Save and enable the action. Use **Save and switch** to send the command immediately.

Each action selects a specific input. Actions can also be triggered from the menu bar. Closing the settings window leaves the app running; quitting releases its shortcuts. No input commands or default shortcuts are enabled on first launch.

Standard presets: DP 1 = 15, DP 2 = 16, HDMI 1 = 17, HDMI 2 = 18, USB-C = 27. LG alternate presets: 208, 209, 144, 145 and 210 respectively. **These values are monitor-specific conventions, not guaranteed capabilities.** Custom codes accept 0–65535. Select the control method before selecting its preset.

## Limitations

- After switching to another computer, some monitors disconnect DDC on the inactive input. Switching back may require the monitor's physical controls or software on the other computer.
- Successful command delivery does not verify that the monitor changed inputs.
- Monitor enumeration does not guarantee DDC support through the current connection. A direct USB-C/DisplayPort connection may work when a dock does not.
- Carbon hotkey registration and dispatch are tested; physical keyboard delivery and real input switching require hardware acceptance testing. See [verification](docs/VERIFICATION.md).
- Builds use ad-hoc signing and are not Apple-notarized. Follow the system's standard Privacy & Security flow if macOS blocks a build you trust; do not disable Gatekeeper.
- The bundled helper uses private macOS display interfaces and runs outside App Sandbox. This is not an App Store app.

Settings are stored locally in `~/Library/Application Support/DDCSwitcher/settings.json`. Invalid settings are preserved and can be backed up/reset from the app. Updating the app preserves saved input actions and shortcuts. Disable launch at login before uninstalling.

## Build and test on macOS

Install Xcode or Apple's Command Line Tools. All third-party source is vendored; no Swift package downloads are needed.

```sh
bash scripts/test.sh
bash scripts/build.sh
open dist/DDCSwitcher.app
```

The app and helper target arm64 / macOS 13. Build caches and outputs stay inside the checkout. Unit tests run natively on the build host; the distributed application requires Apple Silicon.

For Carbon integration testing in a logged-in macOS GUI session, after building:

```sh
bash scripts/test.sh --integration
```

This uses a fake DDC backend and does not switch a real monitor. For a safe interactive demo:

```sh
open dist/DDCSwitcher.app --args --demo "$PWD/.build/demo"
```

The demo window is clearly marked and writes isolated settings/logs to the supplied directory. Quit demo mode before opening the app normally.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). DDC Switcher is MIT-licensed and includes [m1ddc](https://github.com/waydabber/m1ddc), also MIT-licensed. Its pinned revision and local fixes are documented in [THIRD_PARTY.md](THIRD_PARTY.md).
