#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
TAG="${1:?Usage: bash scripts/release.sh vX.Y.Z}"
test "$TAG" = "v$VERSION" || { printf 'Tag must match source version v%s\n' "$VERSION"; exit 1; }
test -z "$(git status --porcelain)" || { printf 'Commit source changes before publishing.\n'; exit 1; }
test -f dist/OldLocal-macOS-arm64.zip
(cd dist && shasum -a 256 -c SHA256SUMS)
python3 - "$VERSION" <<'PY'
import plistlib, sys, zipfile
with zipfile.ZipFile('dist/OldLocal-macOS-arm64.zip') as package:
    assert package.testzip() is None
    version = plistlib.loads(package.read('OldLocal.app/Contents/Info.plist'))['CFBundleShortVersionString']
    assert version == sys.argv[1], 'Build package before publishing this version'
PY
git diff --quiet HEAD origin/main || { printf 'Push this commit to origin/main first.\n'; exit 1; }
gh release create "$TAG" dist/OldLocal-macOS-arm64.zip dist/SHA256SUMS --repo Oldleeo/OldLocal --target "$(git rev-parse HEAD)" --title "OldLocal $VERSION" --notes-file CHANGELOG.md --latest
