# Rummage – working notes for Claude

Godot 4.7.2, GDScript (typed), Jolt. A cosy night-time physics hide-and-seek
game. **NOTES.md** is the full design and systems reference: read the relevant
section rather than the whole file.

## How Tom wants to work
- Tom makes the design calls. For real choices, ask with options (short
  descriptions). For small ones, just pick and say so.
- Brief replies. Light code comments (explain Godot concepts, not every line).
- Keep NOTES.md updates short.
- Commit after each finished change; messages end with the Co-Authored-By line.
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
  catch · beam_look · beam_sound · room · lamp
- In tests, wait two `process_frame`s before reading anything drawn per frame.

## Visual checks (need a real window, not --headless)
- `tests/shoot.tscn` (all screens) and `tests/shoot_lamp.tscn` (lamp), PNGs
  in `%APPDATA%/Godot/app_userdata/rummage_prototype/shots`.
- Render at `--resolution 960x540` and look only when the look is the point.
- `tests/bench_gpu.tscn` measures GPU cost per graphics setting.
- `tests/render_knocks.tscn` / `render_clacks.tscn` save sounds as WAVs.

## Parked (do after the playtest unless Tom says otherwise)
- Playtest build: Windows export (Tom downloads export templates first),
  then 3–5 players.
- More life in the creatures (squash/stretch, lean, startled jump).
- First-minute lesson; squeak and ping sound pass; itch page; web build test.
- Trapdoor under the rug opens to a hidden space with something to find (Grace's idea; only the closed trapdoor exists).
- Design question: tip-but-not-lift heavy things (the wardrobe gate would need an exception).
