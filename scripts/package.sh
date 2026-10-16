#!/usr/bin/env bash
# Package dist/TrayIconGuard.exe into a release zip + SHA256SUMS.
set -e
cd "$(dirname "$0")/.."
VER=8.6.0
ZIP="dist/TrayIconGuard-${VER}-win-x64.zip"
STAGE=$(mktemp -d)
mkdir -p "$STAGE/TrayIconGuard"
cp dist/TrayIconGuard.exe "$STAGE/TrayIconGuard/"
cp README.md README.ru.md LICENSE CHANGELOG.md "$STAGE/TrayIconGuard/"
cp -r docs "$STAGE/TrayIconGuard/"
cp -r installer "$STAGE/TrayIconGuard/"
rm -f "$STAGE/TrayIconGuard/installer/TrayIconGuard.iss.bak" 2>/dev/null || true
( cd "$STAGE" && zip -qr9 "$OLDPWD/$ZIP" TrayIconGuard )
( cd dist && sha256sum TrayIconGuard.exe "$(basename "$ZIP")" > SHA256SUMS )
rm -rf "$STAGE"
ls -la dist/
cat dist/SHA256SUMS
