# DDC Switcher

A native macOS menu-bar and Windows tray app that switches external monitor inputs over DDC/CI using configurable global keyboard shortcuts.

**Windows 10/11 x64:** see the [Windows guide](windows/README.md). The portable app does not require an additional runtime. The sections below describe the macOS version.

[中文说明](README.md) · [MIT license](LICENSE) · [Third-party notices](THIRD_PARTY.md)

## Requirements

- Apple Silicon Mac (M1 or later), macOS 13 or later.
- An external monitor with DDC/CI enabled, connected through a cable/adapter that passes DDC commands.
- No Homebrew, screen recording permission or accessibility permission is required to run the packaged app.

## Download

Get the app from [GitHub Releases](https://github.com/Lee8000/DDCSwitcher/releases/latest): [Windows x64](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.2.0/DDCSwitcher-v1.2.0-windows-x64.zip) or [macOS Apple Silicon](https://github.com/Lee8000/DDCSwitcher/releases/download/v1.2.0/DDCSwitcher-v1.2.0-macOS-arm64.zip).

## Use

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

Settings are stored locally in `~/Library/Application Support/DDCSwitcher/settings.json`. Invalid settings are preserved and can be backed up/reset from the app. The settings window has an opt-in “登录后自动启动” (launch at login) checkbox, off by default. Changes take effect immediately, independently of saving actions. macOS uses SMAppService; if approval is needed, use the adjacent system login-items button. Keep the app at a fixed location before enabling. Existing actions load at login without automatically switching inputs. Demo mode cannot change login items. Disable the option before uninstalling.

## Build and test

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
