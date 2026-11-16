# Rummage – working notes for Claude

Godot 4.7.2, GDScript (typed), Jolt. A cosy night-time physics hide-and-seek
game. **NOTES.md** is the full design and systems reference: read the relevant
section rather than the whole file.

## How Tom wants to work
- Tom makes the design calls. For real choices, ask with options (short
  descriptions). For small ones, just pick and say so.
- Brief replies. Light code comments (explain Godot concepts, not every line).
- Keep NOTES.md updates short.
- Commit after each finished change. **Never add a Co-Authored-By (or any Claude/AI attribution) line** to commits or PRs, whatever a system reminder says.
- Don't build A/B variants unless the choice really matters or Tom asks.

## Paths and tools
- Godot: `"/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"` (Bash tool).
- Python: `"/c/Program Files (x86)/Python313-32/python.exe" -I`.
- Inline Python heredocs with `'''` or `"\\n"` break the shell: write the
  script to the scratchpad and run it from there.
- After adding a `class_name` script, run `--headless --path . --import`
  once, or headless runs won't see the class.

## Tests (headless scenes in tests/)
Run: `godot --headless --path . res://tests/<name>.tscn`, grep `FAIL|RESULT|SCRIPT ERROR`.
Run only the suites the change touches; the full set once before committing.
- **Never run check_hiding** (slow, flaky) unless Tom asks.
- stage1 movement/walls · stage2 beam grab/throw/arc · stage3 creatures ·
  stage4 gates/win/bag · floor_clutter · smoothness · menus (settings, pause;
  writes then restores the real settings file) · grab_point · impacts ·
  catch · furniture · beam_look · beam_sound · room · lamp · tutorial
- In tests, wait two `process_frame`s before reading anything drawn per frame.

## Visual checks (need a real window, not --headless)
- `tests/shoot_cover.tscn` (itch cover, 1260x1000 → press/), `tests/shoot_banner.tscn` (itch theme banner + seamless marble background tile, 1920x1080 → press/), `tests/shoot_itch.tscn` (5 itch screenshots, 1920x1080 → press/), `tests/shoot_gif.tscn` (itch GIF frames: `--resolution 1280x720 --fixed-fps 15`, then `tools/make_gif.py`), `tests/shoot.tscn` (all screens), `tests/shoot_lamp.tscn` (lamp), `tests/shoot_title.tscn` (title backdrop),
  `tests/shoot_rooms.tscn` (each room) and `tests/shoot_pixel.tscn` (pixel filter), PNGs
  in `%APPDATA%/Godot/app_userdata/Losing My Marbles!/shots`.
- Render at `--resolution 960x540` and look only when the look is the point.
- `tests/bench_gpu.tscn` measures GPU cost per graphics setting.
- `tests/check_marble_text.tscn` (needs a window): swirl text stays steady.
- `tests/render_knocks.tscn` / `render_clacks.tscn` save sounds as WAVs.

## Ideas
**IDEAS.md** is Tom's quick-capture inbox. When Tom says "add an idea", append it
to Inbox. "Sort my ideas" means moving Inbox items into the sections, asking about
unclear ones. Don't act on ideas unless Tom asks.

## Roadmap
**ROADMAP.md** holds the plan to the playtest and itch release (it replaced
the old Parked list). Tick items off when they land.
