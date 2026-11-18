#!/usr/bin/env bash
# Records the social clips (tests/record_clip.gd) in Godot's movie mode, wide
# (1920x1080) and tall (1080x1920), and cuts each to an MP4 in press/clips/.
# Usage: tools/make_clips.sh [clip ...]   (no names: every clip;
# SHAPES=wide for just the wide ones)
# Needs ffmpeg (winget install Gyan.FFmpeg).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"
FFMPEG="$(command -v ffmpeg || ls /c/Users/*/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe | head -1)"
RAW="${TEMP:-/tmp}/rummage_clips"
OUT="press/clips"
mkdir -p "$RAW" "$OUT"

clips=("$@")
if [ ${#clips[@]} -eq 0 ]; then
	clips=($(grep -o 'const CLIPS.*' tests/record_clip.gd | grep -o '"[a-z_]*"' | tr -d '"'))
fi

# The game opens fullscreen at the screen's size; override.cfg (read by Godot
# on top of project.godot) sets the window each recording needs. Always
# removed afterwards, so the game itself is never affected.
trap 'rm -f override.cfg' EXIT

for clip in "${clips[@]}"; do
	for shape in ${SHAPES:-wide tall}; do
		if [ "$shape" = wide ]; then w=1920; h=1080; name="$clip"; else w=1080; h=1920; name="${clip}_tall"; fi
		printf '[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/mode=0\n' "$w" "$h" > override.cfg
		line=$(timeout 300 "$GODOT" --path . --write-movie "$RAW/$name.avi" --fixed-fps 60 \
			res://tests/record_clip.tscn -- "$clip" hands_off 2>&1 | grep -E '^CLIP ' || true)
		rm -f override.cfg
		if [ -z "$line" ]; then echo "FAIL $name: no CLIP line"; continue; fi
		read -r _ first last <<< "$line"
		start=$(awk "BEGIN { printf \"%.4f\", $first / 60 }")
		length=$(awk "BEGIN { printf \"%.4f\", ($last - $first) / 60 }")
		"$FFMPEG" -v error -y -ss "$start" -t "$length" -i "$RAW/$name.avi" \
			-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
			-af "afade=t=in:d=0.1,afade=t=out:st=$(awk "BEGIN { print $length - 0.3 }"):d=0.3" \
			-c:a aac -b:a 192k -movflags +faststart "$OUT/$name.mp4"
		rm -f "$RAW/$name.avi"
		echo "RESULT $OUT/$name.mp4 ($length s)"
	done
done

# The montage, once the whole set has been made.
if [ $# -eq 0 ]; then
	"/c/Program Files (x86)/Python313-32/python.exe" -I tools/make_montage.py "$FFMPEG"
fi
