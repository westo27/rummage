# Project Rummage – concept prototype notes

Godot 4.7.2, GDScript, Jolt Physics. Open the folder in Godot and press F5; the
main scene is `scenes/main.tscn`.

**Controls:** WASD move, Shift run, mouse look, Esc releases the cursor (click to
recapture). Hold left mouse to grab, release to drop, right mouse or F to throw,
mouse wheel to move the held object nearer/further. Click an exposed creature to
catch it. Q pings. R restarts at any time.

## Scene tree

```
Main  (scripts/main.gd: game flow, catch count, timer, gate toasts, win, restart)
├─ WorldEnvironment, LightMain, LightSide
├─ House
│  ├─ Walls        CSGCombiner3D: both rooms' walls/ceiling and the doorway hole
│  ├─ FloorMain    CSGBox3D
│  └─ FloorSide    CSGBox3D
├─ Player          scenes/player.tscn  (scripts/player.gd: move, look, kick clutter)
│  ├─ CollisionShape3D  capsule
│  └─ Head              pitch (up/down); the body itself does yaw (left/right)
│     └─ Camera3D       top_level, placed by player.gd every frame (see "Smoothness")
│        └─ Beam        scripts/beam.gd: aim, grab, hold, throw, lift limit, catch
│           └─ BeamMesh the curved beam ribbon, rebuilt each frame
├─ MainRoomProps        scenes/main_room_props.tscn: positions of every prop
├─ MainRoomCreatures    scenes/main_room_creatures.tscn: 21 creatures
├─ SideRoomProps        scenes/side_room_props.tscn
├─ SideRoomCreatures    scenes/side_room_creatures.tscn: 4 creatures
├─ Ping                 scripts/ping.gd
└─ HUD                  scenes/hud.tscn (scripts/hud.gd, scripts/crosshair.gd)
```

- Each prop type is its own scene in `scenes/props/` (book, crate, bin, small_box,
  cushion, ball, bookcase, table, sofa, wardrobe): a `RigidBody3D` with
  `scripts/prop.gd` and box/sphere meshes plus matching collision shapes.
- Each creature is an instance of `scenes/creature.tscn` (`scripts/creature.gd`).
- The `*_props.tscn` / `*_creatures.tscn` layout files are ordinary scenes: open
  them and drag things around in the editor. Creatures work out what's covering
  them by themselves half a second after the scene loads, so moving a creature
  under a different object just works.
- `scripts/game.gd` is an autoload called `Game`. It holds the tunables and
  defines the controls.
- `scripts/tones.gd` builds every sound from sine waves. There are no audio files.

## Tunables

Everything you're likely to tweak is in **`config/tunables.tres`**. Click it in
the FileSystem dock and edit it in the Inspector, grouped as World, Player, Beam,
Lift, Creatures and Ping. The defaults and a comment for each value are in
`config/tunables.gd`. Once you change a value in the Inspector, the `.tres` copy
wins over the default in the `.gd` file.

A few visual constants stay as `const` at the top of their scripts, because
they're look rather than feel: the shudder amount (prop.gd), the beam ribbon
width (beam.gd), the creature pick radius (`PickZone` in creature.tscn, 0.25 m).

**Lift per catch is 7 kg.** There are 21 creatures in the main room and the
starting limit is 10 kg, so:
- the 60 kg **sofa** unlocks at **8** catches (66 kg; 7 catches give 59 kg)
- the 115 kg **wardrobe** unlocks at **15** catches (exactly 115 kg)

The HUD announces each one as it unlocks. If you move creatures between rooms or
change `lift_per_capture`, redo this sum (`tests/check_stage3.gd` checks it).

## Collision layers

Named in Project Settings > Layer Names > 3D Physics. A layer's bit value is
2^(layer − 1), which is the number you see in the code.

| Layer | Value | What's on it | Notes |
|---|---|---|---|
| 1 world | 1 | walls, floors (CSG) | |
| 2 player | 2 | the player capsule | |
| 3 props | 4 | props over 3 kg: crates, table, bookcase, sofa, wardrobe | block the player |
| 4 creatures | 8 | creature bodies; exposed creatures' PickZone areas | the beam's first ray hits only this layer |
| 5 clutter | 16 | props of 3 kg or less: books, balls, cushions, bins, small boxes | the player walks through them and kicks them |

`prop.gd` picks props or clutter by mass when it loads, overriding the layer
saved in the `.tscn`. Two bodies collide if *either* one's mask includes the
other's layer.

- **Player** (mask world + props): blocked by walls and heavy props, never by
  clutter or creatures.
- **Held objects** pass through the player through collision exceptions (prop.gd),
  which are removed once the object is clear of the player after you let go.
- **Creatures** (mask world + props): run around heavy props and straight through
  clutter, so they don't snag on books.
- **Beam:** first an Area-only ray on layer 4 (creatures). If that misses, a ray
  on world + props + clutter. The creature ray's line-of-sight check only counts
  walls and floors, so furniture never blocks a creature that's next to it.

## Smoothness (physics interpolation)

Physics runs at 60 Hz. Physics interpolation is on (Project Settings > Physics >
Common), so bodies are drawn between their last two physics positions and move
smoothly at any frame rate. The camera opts out: it's `top_level` with
interpolation off, and `player.gd` places it every frame, using the head's
interpolated position and the mouse rotation as it is right now. Because of
this, anything that moves a visual node is done in `_physics_process` or a
physics-mode tween, and teleports call `reset_physics_interpolation()`.

## Tests

The headless checks live in `tests/`, one scene each. Run one with:

```
"C:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe" --headless --path . res://tests/check_stage4.tscn
```

| Test | Checks |
|---|---|
| check_stage1 | movement speeds, walls, doorway, gravity 14, fall reset |
| check_stage2 | settling, grab, hold, throw speeds, walls stop held objects, swing-fling, beam arc, too-heavy latch |
| check_stage3 | hiding, tells, reveal by lifting, knocking or pulling books, fleeing, cowering, catching, aim priority, gate sums |
| check_stage4 | ping range and cooldown, both gates, wardrobe off the doorway, side room, win, timer, restart |
| check_floor_clutter | the player wades through clutter and is blocked by crates |
| check_smoothness | even movement per frame at 157 fps |
| check_hiding | uncovered creatures cower somewhere the player can't see from where they stand |

They're scenes, not `--script` runs, so that the `Game` autoload loads first.

## What isn't verified

The tests prove the systems do what they're meant to in a simulation. They can't
tell whether any of it is fun or readable. Not verified:

- **Feel:** whether holding, throwing, kicking clutter, the gate pacing and the
  hunt are enjoyable. Nothing has been checked by eye.
- **Sound:** headless runs use a dummy audio driver. I only know a squeak
  *started*, not whether it's audible, pleasant, or easy to locate in 3D.
- **Visuals:** the glow, the cover rattle, the hop, the tremble, the crosshair
  shapes, the toast and win panel layout, and the lighting are all unseen.
- **Clue quality:** whether tells and ping really let you follow clues instead
  of checking every bin.
- **Smoothness on a real display:** the numbers are perfect headless, but
  V-Sync and frame pacing on your machine could still add judder.
- **Edge cases:** wedging things into the doorway, stacking props to climb,
  creatures cornered behind heavy furniture, and a held wardrobe swept through a
  room full of clutter. None of these were tried.

## Where creatures hide after fleeing

When a creature stops fleeing it looks at every floor prop within 5 m and
picks the nearest spot on the far side of one, as seen from the player's head.
Spots the player can see, spots against a wall, and spots within startle range
of the player all lose. "Can see" means a ray from the head to the creature's
middle and top is blocked by a wall, prop or clutter, so a flat book doesn't
count as cover but a bin or crate does. The spot is re-aimed every tick while
it runs, so if you move, it heads for the new far side. The constants are at
the top of `creature.gd` (`HIDE_SEARCH_RADIUS`, `HIDE_GAP`).

## Known quirks (deliberate or tolerated)

- A cowering creature doesn't move again when you walk round to see it, so
  you can still catch it. It only picks a hiding spot while it's seeking.
- "Behind" means hidden from where you stand. Which way you're facing doesn't
  matter. If no prop within 5 m can hide it, a creature takes the nearest spot
  anyway, and if the seek time runs out first it cowers wherever it is. Either
  way it can end up in plain view.

- Furniture doesn't block catching an exposed creature, only walls do, so a
  creature half behind a crate can still be caught. I chose generous over exact.
- The player pushes clutter like a snowplough: anything dead ahead gets shoved
  until it reaches a wall.
- Creatures under the sofa ignore jolts and things flying past (so the gate
  can't be skipped by pelting the sofa), but a book slid *under* the sofa can
  still startle them.
- The sofa and wardrobe can't tip over until they've been lifted once.
- If a creature falls out of the world it reappears in the middle of the main room.
