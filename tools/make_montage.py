"""Cuts the social clips in press/clips/ into one montage, wide and tall.

Each clip loses its still lead-in and tail, they run from the small reveals up
to the big throw, joined by short dissolves (the sound crossfades too), with a
fade in from black, and to finish the last frame holds, softens and darkens
under the logo.

Usage: python make_montage.py <ffmpeg.exe>   (run from the project folder)
"""

import json
import os
import subprocess
import sys

FFMPEG = sys.argv[1]
FFPROBE = os.path.join(os.path.dirname(FFMPEG), "ffprobe" + os.path.splitext(FFMPEG)[1])
CLIPS = "press/clips"
LOGO = "press/banner.png"
# Building up: one marble, then a few, then furniture, then the chaos.
ORDER = ["picture", "drawers", "wardrobe", "bin", "bookcase", "bin_throw", "chair"]
# Seconds cut from the start (the still lead-in) and the end of each clip.
TRIM_IN = 0.35
TRIM_OUT = 0.2
# The last one keeps its tail: the scatter is the payoff.
KEEP_LAST_TAIL = True
DISSOLVE = 0.35
FADE_IN = 0.6
CARD = 3.2


def duration(path):
    out = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration",
                          "-of", "json", path], capture_output=True, text=True, check=True)
    return float(json.loads(out.stdout)["format"]["duration"])


def build(suffix, width, height):
    clips = [c for c in ORDER if os.path.exists(f"{CLIPS}/{c}{suffix}.mp4")]
    args = [FFMPEG, "-v", "error", "-y"]
    lengths = []
    for i, clip in enumerate(clips):
        path = f"{CLIPS}/{clip}{suffix}.mp4"
        last = i == len(clips) - 1
        length = duration(path) - TRIM_IN - (0.0 if last and KEEP_LAST_TAIL else TRIM_OUT)
        lengths.append(length)
        args += ["-ss", f"{TRIM_IN:.3f}", "-t", f"{length:.3f}", "-i", path]
    args += ["-loop", "1", "-t", f"{CARD}", "-i", LOGO]
    logo = len(clips)

    parts = []
    last = len(clips) - 1
    for i in range(len(clips)):
        label = f"v{i}" if i != last else "vlast"
        parts.append(f"[{i}:v]fps=60,settb=AVTB,setpts=PTS-STARTPTS,format=yuv420p[{label}]")
        parts.append(f"[{i}:a]aresample=48000,asetpts=PTS-STARTPTS[a{i}]")
    # The end card: the last clip's final frame held, blurred and darkened,
    # with the logo (70% of the frame's width) fading up over it.
    parts.append(f"[vlast]split[v{last}][vhold]")
    parts.append(f"[vhold]tpad=stop_mode=clone:stop_duration={CARD},trim=start={lengths[last]:.3f},"
                 f"setpts=PTS-STARTPTS,boxblur=18:2,eq=brightness=-0.18:saturation=0.85[bg]")
    parts.append(f"[{logo}:v]scale={int(width * 0.7)}:-1,format=rgba,"
                 f"fade=t=in:st=0.15:d=0.5:alpha=1[lg]")
    parts.append(f"[bg][lg]overlay=(W-w)/2:(H-h)/2:shortest=1,fps=60,settb=AVTB,format=yuv420p[vcard]")
    parts.append(f"anullsrc=r=48000:cl=stereo,atrim=0:{CARD}[acard]")
    lengths.append(CARD)
    names_v = [f"v{i}" for i in range(len(clips))] + ["vcard"]
    names_a = [f"a{i}" for i in range(len(clips))] + ["acard"]

    # Dissolve each into the next; offsets are where each dissolve starts.
    v, a, at = names_v[0], names_a[0], lengths[0]
    for i in range(1, len(names_v)):
        fade = 0.45 if i == len(names_v) - 1 else DISSOLVE
        offset = at - fade
        parts.append(f"[{v}][{names_v[i]}]xfade=transition=fade:duration={fade}:offset={offset:.3f}[xv{i}]")
        parts.append(f"[{a}][{names_a[i]}]acrossfade=d={fade}[xa{i}]")
        v, a = f"xv{i}", f"xa{i}"
        at = offset + lengths[i]
    parts.append(f"[{v}]fade=t=in:st=0:d={FADE_IN},fade=t=out:st={at - 0.4:.3f}:d=0.4[vout]")
    parts.append(f"[{a}]afade=t=in:st=0:d=0.15[aout]")

    out = f"{CLIPS}/montage{suffix}.mp4"
    args += ["-filter_complex", ";".join(parts), "-map", "[vout]", "-map", "[aout]",
             "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out]
    subprocess.run(args, check=True)
    print(f"RESULT {out} ({len(clips)} clips, {at:.1f} s)")


build("", 1920, 1080)
build("_tall", 1080, 1920)
