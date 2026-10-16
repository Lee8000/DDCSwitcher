#!/bin/bash
set -euo pipefail
DDC_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DDC_PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$DDC_PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH" .build/configuration .build/security
swift test --cache-path .build/cache --config-path .build/configuration --security-path .build/security --disable-sandbox
clang -Wall -Wextra -Werror -fmodules -I ThirdParty/m1ddc/headers Tests/DDCPacketTests.m ThirdParty/m1ddc/sources/i2c.m -framework Foundation -framework IOKit -o .build/ddc-packet-tests
.build/ddc-packet-tests
if [ "${1:-}" = "--integration" ]; then
  "$DDC_PROJECT_ROOT/dist/DDCSwitcher.app/Contents/MacOS/DDCSwitcher" --self-test
fi
