#!/bin/sh
# Exports the Windows build and pushes it to itch with butler.
# Usage: tools/release.sh <version>      e.g. tools/release.sh 0.1.0
set -e
cd "$(dirname "$0")/.."

VERSION="$1"
GODOT="/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"
PATH="/c/Tools/butler:$PATH"
ITCH_TARGET="westo27/losing-my-marbles"
[ -n "$VERSION" ] || { echo "usage: tools/release.sh <version>"; exit 1; }

rm -rf build/windows
mkdir -p build/windows
"$GODOT" --headless --path . --export-release "Windows" build/windows/ImLosingMyMarbles.exe \
	2>&1 | grep -E 'ERROR|WARNING' || true
[ -f build/windows/ImLosingMyMarbles.exe ] || { echo "export failed"; exit 1; }
cp fonts/OFL.txt build/windows/font-licence.txt

butler push build/windows "$ITCH_TARGET:windows" --userversion "$VERSION"
butler status "$ITCH_TARGET:windows" || true
