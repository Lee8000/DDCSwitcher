# Contributing

Bug reports, monitor compatibility reports and focused pull requests are welcome.

Windows development and tests are documented in [windows/README.md](windows/README.md). The C++ core tests can run on macOS/Linux; Windows-native tests run on Windows CI. Keep Windows driver calls out of the UI thread and do not weaken unique-device mapping checks when topology is incomplete.

For a monitor issue, include the Mac chip, macOS version, monitor model, direct/dock connection, selected control method/input code, and whether the same action works from the menu bar. Do not include credentials or monitor serial numbers in diagnostic logs.

## Development

```sh
bash scripts/test.sh
bash scripts/build.sh
```

The unit tests and mocked IOAV packet tests do not issue hardware commands. `bash scripts/test.sh --integration` additionally needs a logged-in GUI session and exercises Carbon registration/dispatch against a fake backend. Test real monitor switching only when you can recover using the monitor's physical controls.

Keep validation, persistence and subprocess handling in `DDCSwitcherCore`; AppKit and Carbon belong in the executable target. Test regressions in command framing, shortcut transactions and settings preservation. Preserve all third-party license notices and document changes to vendored code in `THIRD_PARTY.md`.

Submit a pull request describing the observed problem, resulting behavior and validation performed. Note whether testing was mocked, read-only hardware discovery, or actual input switching. Contributions are provided under this repository's MIT license.
