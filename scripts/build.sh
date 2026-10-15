#!/usr/bin/env bash
# One-shot cross-build of TrayIconGuard.exe (static, stripped).
set -e
cd "$(dirname "$0")/.."
mkdir -p build dist
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=cmake/mingw-w64-x86_64.cmake -DCMAKE_BUILD_TYPE=Release > build/cmake.log 2>&1 || { tail -30 build/cmake.log; exit 1; }
cmake --build build -j"$(nproc)" 2>&1 | tail -20
python3 - <<'PY'
import re, sys, xml.dom.minidom as md
data = open('resources/app.manifest','rb').read()
md.parseString(data)  # well-formed or raise
ids = re.findall(rb'supportedOS Id="([^"]+)"', data)
assert len(ids) == len(set(ids)), "duplicate supportedOS GUIDs break Win11 SxS validation"
assert b'manifestVersion="1.0"' in data and b'Microsoft.Windows.Common-Controls' in data
print("manifest gate: OK (well-formed, unique supportedOS)")
PY
ls -la dist/TrayIconGuard.exe
x86_64-w64-mingw32-objdump -p dist/TrayIconGuard.exe | grep -E "DLL Name" | sort
