#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT_SDK="${SWIFT_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/oldlocal-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SWIFT=(/usr/bin/xcrun swiftc -sdk "$SWIFT_SDK" -swift-version 5 -target arm64-apple-macos15.0 -module-cache-path "$TEST_DIR/cache")
S="$ROOT/Sources"
"${SWIFT[@]}" "$S/Coordinates.swift" "$ROOT/Tests/ModelTests.swift" -o "$TEST_DIR/models"
"$TEST_DIR/models" "$TEST_DIR/model-store"
"${SWIFT[@]}" "$S/Coordinates.swift" "$S/IPLocation.swift" "$ROOT/Tests/FeatureTests.swift" -o "$TEST_DIR/features"
"$TEST_DIR/features" "$TEST_DIR/feature-store"
"${SWIFT[@]}" "$S/Coordinates.swift" "$S/GroupOperations.swift" "$ROOT/Tests/GroupTests.swift" -o "$TEST_DIR/groups"
"$TEST_DIR/groups"
"${SWIFT[@]}" -framework Security "$S/helper/HelperProtocol.swift" "$ROOT/Tests/PolicyTests.swift" -o "$TEST_DIR/policy"
"$TEST_DIR/policy"
"${SWIFT[@]}" "$S/ReleaseChannel.swift" "$ROOT/Tests/ReleaseTests.swift" -o "$TEST_DIR/releases"
"$TEST_DIR/releases"
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -m unittest discover -s "$ROOT/Tests" -p 'test_*.py' -v
printf 'All non-privileged checks passed.\n'
