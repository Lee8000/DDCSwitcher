#!/bin/bash
set -euo pipefail
DDC_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DDC_PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$DDC_PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH" .build/configuration .build/security
swift build -c release --arch arm64 --cache-path .build/cache --config-path .build/configuration --security-path .build/security --disable-sandbox
MACOSX_DEPLOYMENT_TARGET=13.0 make -B -C ThirdParty/m1ddc CC="clang -arch arm64"
DDC_APP="$DDC_PROJECT_ROOT/dist/DDCSwitcher.app"
mkdir -p "$DDC_APP/Contents/MacOS" "$DDC_APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/DDCSwitcher "$DDC_APP/Contents/MacOS/"
cp ThirdParty/m1ddc/m1ddc "$DDC_APP/Contents/MacOS/"
cp Resources/Info.plist "$DDC_APP/Contents/"
cp ThirdParty/m1ddc/LICENSE "$DDC_APP/Contents/Resources/m1ddc-LICENSE.txt"
cp THIRD_PARTY.md "$DDC_APP/Contents/Resources/"
cp README.md "$DDC_APP/Contents/Resources/"
swift scripts/generate-icon.swift "$DDC_PROJECT_ROOT/.build/AppIcon.iconset"
iconutil -c icns .build/AppIcon.iconset -o "$DDC_APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --timestamp=none "$DDC_APP/Contents/MacOS/m1ddc"
codesign --force --sign - --timestamp=none "$DDC_APP"
codesign --verify --deep --strict "$DDC_APP"
printf 'Built %s\n' "$DDC_APP"
