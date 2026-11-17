#!/usr/bin/env bash
# The "changed one variable" post: the mock code card (tests/record_code_card)
# hard-cut into the mitosis clip (tests/record_clip.gd -- mitosis), wide and
# tall, as press/clips/mitosis_post.mp4 and mitosis_post_tall.mp4.
# Usage: tools/make_mitosis_post.sh   (needs ffmpeg, like make_clips.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"
FFMPEG="$(command -v ffmpeg || ls /c/Users/*/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe | head -1)"
RAW="${TEMP:-/tmp}/rummage_clips"
OUT="press/clips"
mkdir -p "$RAW" "$OUT"
trap 'rm -f override.cfg' EXIT

bash tools/make_clips.sh mitosis

# The card. A window can't be taller than the screen, so the tall one is
# drawn square and padded out in the editor's background colour.
for shape in wide tall; do
	if [ "$shape" = wide ]; then w=1920; h=1080; else w=1080; h=1080; fi
	printf '[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/mode=0\n' "$w" "$h" > override.cfg
	timeout 120 "$GODOT" --path . --write-movie "$RAW/card_$shape.avi" --fixed-fps 60 \
		res://tests/record_code_card.tscn > /dev/null 2>&1 || true
	rm -f override.cfg
done

for shape in wide tall; do
	if [ "$shape" = wide ]; then
		suffix=""; card="scale=1920:1080"
	else
		suffix="_tall"; card="pad=1080:1920:0:(oh-ih)/2:color=0x1d2229"
	fi
	# Card (silent) then a hard cut to the clip with its sound.
	"$FFMPEG" -v error -y -i "$RAW/card_$shape.avi" -i "$OUT/mitosis$suffix.mp4" \
		-f lavfi -t 10 -i anullsrc=r=48000:cl=stereo -filter_complex \
		"[0:v]$card,fps=60,settb=AVTB,setpts=PTS-STARTPTS,format=yuv420p,trim=0:2.55,setpts=PTS-STARTPTS[c];\
[2:a]atrim=0:2.55[ca];\
[1:v]fps=60,settb=AVTB,setpts=PTS-STARTPTS,format=yuv420p[m];[1:a]aresample=48000[ma];\
[c][ca][m][ma]concat=n=2:v=1:a=1[v][a]" \
		-map "[v]" -map "[a]" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
		-c:a aac -b:a 192k -movflags +faststart "$OUT/mitosis_post$suffix.mp4"
	echo "RESULT $OUT/mitosis_post$suffix.mp4"
done
rm -f "$RAW"/card_*.avi
