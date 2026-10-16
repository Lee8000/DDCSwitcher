# Third-party software

DDC Switcher includes **m1ddc**, Copyright (c) 2021 waydabber, licensed under MIT.

The m1ddc helper is bundled only with the macOS app. The native Windows app uses Windows system APIs and does not include or run m1ddc. Windows release builds statically link the MSVC runtime; users do not need a separate runtime installation. Both app icons originate from this project's generated icon design.

- Upstream: https://github.com/waydabber/m1ddc
- Pinned commit: `04d949794102eb8df01ad3681afff6464a3eede2`
- Full original license: `ThirdParty/m1ddc/LICENSE`; also bundled as `Contents/Resources/m1ddc-LICENSE.txt`.
- Source is vendored so the app builds without network downloads or Homebrew.

Local changes:

1. `sources/m1ddc.m`: stdout uses `fputs`/`fflush`, preserving all output lines when the process runner captures output in files. The upstream NSString `/dev/stdout` writer can truncate regular files on each line.
2. `sources/ioregistry.m`: reject built-in panels, initialize each display record and check the CoreGraphics enumeration return code. This prevents internal panels from appearing as switchable monitors and avoids uninitialized optional metadata.
3. `sources/i2c.m`: derive transfer length from the DDC frame header instead of trimming zero bytes. This preserves a zero-valued checksum, including standard input 216 and LG alternate input 77. Four mocked IOAV regression cases verify framing without accessing real hardware.

The helper uses private CoreDisplay/IOAVService interfaces. It is intended for local, unsandboxed use on Apple Silicon Macs and is not an App Store build. Future macOS versions may require updates.
