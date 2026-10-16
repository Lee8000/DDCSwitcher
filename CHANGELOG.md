# Changelog

## 1.1.0 — 2026-10-16

- Add a portable native Windows 10/11 x64 tray application with monitor selection, input presets/custom values, shortcut recording and local settings.
- Use stable Windows device paths and reject incomplete or ambiguous display mappings.
- Isolate Windows DDC driver calls in bounded worker processes with job cleanup; preserve settings and hotkey registrations when saving fails.
- Add portable C++ checks and Windows-native persistence/worker/hotkey self-tests, Windows CI, Chinese/English instructions and downloadable x64 builds.
- Preserve the macOS app functionality and tests. Both platforms require physical keyboard and monitor switching acceptance tests on target hardware.

## 1.0.0 — 2026-10-16

- Native macOS menu-bar app with per-monitor input actions.
- Configurable global shortcuts with recording, duplicate detection and transactional registration.
- Standard DDC/CI, LG alternate addressing and custom input codes.
- Stable monitor identifiers, disconnected-device checks, bounded subprocess execution and trigger suppression.
- Local JSON settings with invalid-file preservation and explicit backup/reset recovery.
- Bundled, MIT-licensed m1ddc source and arm64 build scripts.
- Fixes for zero-valued DDC checksums and startup registration errors being hidden by discovery status.
- Thirteen Swift tests, four mocked DDC packet cases and a Carbon integration self-test.

Real input switching and physical keyboard delivery require acceptance testing on target hardware. Builds are ad-hoc signed and not notarized.
