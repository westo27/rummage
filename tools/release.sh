#!/bin/sh
# Exports Windows, Linux, macOS and web builds and pushes each to its own itch
# channel with butler. butler only uploads what changed since the last push.
# Usage: tools/release.sh <version>      e.g. tools/release.sh 0.1.1
set -e
cd "$(dirname "$0")/.."

VERSION="$1"
GODOT="/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"
PATH="/c/Tools/butler:$PATH"
ITCH_TARGET="westo27/losing-my-marbles"
echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "usage: tools/release.sh <x.y.z>"; exit 1; }

# Stamp the version into the presets (the exe's file info and the Mac app's).
sed -i -E "s/(application\/(file|product)_version=)\"[^\"]*\"/\1\"$VERSION.0\"/; \
	s/(application\/(short_)?version=)\"[^\"]*\"/\1\"$VERSION\"/" export_presets.cfg

# preset name | itch channel | output file
for line in "Windows|windows|ImLosingMyMarbles.exe" "Linux|linux|ImLosingMyMarbles.x86_64" \
		"macOS|mac|ImLosingMyMarbles.zip" "Web|web|index.html"; do
	preset=${line%%|*}; rest=${line#*|}; channel=${rest%%|*}; file=${rest#*|}
	dir="build/$channel"
	rm -rf "$dir"; mkdir -p "$dir"
	echo "== $preset"
	"$GODOT" --headless --path . --export-release "$preset" "$dir/$file" \
		2>&1 | grep -E 'ERROR|WARNING' || true
	[ -f "$dir/$file" ] || { echo "$preset export failed"; exit 1; }
	[ "$channel" = web ] || [ "$channel" = mac ] || cp fonts/OFL.txt "$dir/font-licence.txt"
done

for channel in windows linux mac web; do
	src="build/$channel"
	# The Mac export is a zip holding the .app; butler unpacks it on itch's side.
	[ "$channel" = mac ] && src="build/mac/ImLosingMyMarbles.zip"
	butler push "$src" "$ITCH_TARGET:$channel" --userversion "$VERSION"
done
butler status "$ITCH_TARGET" || true
