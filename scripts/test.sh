#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/mouse-circle-clang}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-${TMPDIR:-/tmp}/mouse-circle-swift}"
ARGS=(--build-system native --disable-sandbox --disable-xctest --enable-swift-testing --manifest-cache local)
DEV_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
TEST_FRAMEWORKS="$DEV_DIR/Library/Developer/Frameworks"
if [[ -d "$TEST_FRAMEWORKS/Testing.framework" ]]; then
    # Standalone Command Line Tools place Swift Testing outside SwiftPM's default search path.
    ARGS+=(-Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS")
fi
swift test "${ARGS[@]}" "$@"
