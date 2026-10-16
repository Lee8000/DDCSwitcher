# Changelog

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
