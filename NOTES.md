# Project Rummage – concept prototype notes

Godot 4.7.2, GDScript, Jolt Physics. Open the folder in Godot and press F5; it
boots into `scenes/title.tscn` and Play loads `scenes/main.tscn`. To skip the
menu while working, run the main scene on its own with F6.

**Controls:** You play a child: 1.3 m tall, eyes at 1.15 m. WASD move, Shift run, hold C or Ctrl to crouch (slower; stays down under furniture until there is headroom), mouse look, Esc pauses. Hold left mouse to
grab, release to drop, right mouse or F to throw, mouse wheel to move the held
object nearer/further. Click an exposed creature to catch it. Q pings. R
restarts at any time.

## Scene tree

```
Title  scenes/title.tscn (scripts/title_screen.gd: Play, Settings, Quit)

Main  (scripts/main.gd: game flow, catch count, timer, win, restart)
├─ WorldEnvironment, Moonlight
├─ House           three rooms in a row, west to east (see "The house")
│  ├─ Walls        CSGCombiner3D: walls/ceiling, both doorways, window, cubbies
│  ├─ FloorPlayroom, FloorBedroom, FloorBoxRoom   CSGBox3D
│  ├─ LandingDoor  the landing's door; its Door body swings open after the lesson
│  └─ LampPlayroom, LampMain (bedroom), LampSide (box room), a ReflectionProbe each
├─ Player          scenes/player.tscn  (scripts/player.gd: move, look, kick clutter)
│  ├─ CollisionShape3D  capsule
│  └─ Head              pitch (up/down); the body itself does yaw (left/right)
│     └─ Camera3D       top_level, placed by player.gd every frame (see "Smoothness")
│        └─ Beam        scripts/beam.gd: aim, grab, hold, throw, lift limit, catch
│           └─ BeamMesh the curved beam ribbon, rebuilt each frame
├─ Landing             scenes/landing.tscn: the lesson's box, bin, creature and clutter
├─ MainRoomProps        scenes/main_room_props.tscn: playroom and bedroom props
├─ MainRoomCreatures    scenes/main_room_creatures.tscn: 21 creatures (13 playroom, 8 bedroom)
├─ SideRoomProps        scenes/side_room_props.tscn: the box room
├─ SideRoomCreatures    scenes/side_room_creatures.tscn: 4 creatures
├─ Ping                 scripts/ping.gd
├─ HUD                  scenes/hud.tscn (scripts/hud.gd, scripts/crosshair.gd)
│  └─ MarbleBag         built by hud.gd (scripts/marble_bag.gd, scripts/bag_marble.gd)
├─ PauseMenu            scenes/pause_menu.tscn (scripts/pause_menu.gd)
└─ Tutorial             scripts/tutorial.gd: the landing lesson
```

- Each prop type is its own scene in `scenes/props/` (book, crate, bin, small_box,
  pillow, ball, bookcase, table, bed, bedside_table, bedside_lamp, toy_block, wardrobe,
  and the small household things listed under "The house"): a `RigidBody3D` with
  `scripts/prop.gd` and box/sphere meshes plus matching collision shapes.
- Each creature is an instance of `scenes/creature.tscn` (`scripts/creature.gd`).
- The `*_props.tscn` / `*_creatures.tscn` layout files are ordinary scenes: open
  them and drag things around in the editor. Creatures work out what's covering
  them by themselves half a second after the scene loads, so moving a creature
  under a different object just works.
- `scripts/game.gd` is an autoload called `Game`. It holds the tunables and
  defines the controls.
- `scripts/tones.gd` builds every sound from sine waves and noise. There are no audio files.

## Menus and settings

The menus are built in GDScript, not as .tscn files, because they're the same
few parts repeated: `scenes/title.tscn` and `scenes/pause_menu.tscn` hold only
a root node and a script.

- `scripts/ui_style.gd` is the whole look in one place: the palette, the fonts,
  and the glass text. Change a colour here and every menu and the
  crosshair follow. The one imported asset is the font, Coiny (`fonts/`, OFL), which has a
  single weight. Menu text (UiStyle.label and button labels) uses
  `shaders/marble_text.gdshader`: each letter is a 3D glass marble: smoky
  see-through glass, white edge light, pink/blue/teal swirls (pink becomes the
  button's accent) and tiny bubbles. Dark text stays solid with a dark edge.
  Letter-local coordinates come from VERTEX_ID (one quad per glyph).
  Small text gets less swirl (`detail`, set from the font size).
  Each letter's swirls come from smooth waves of its left edge (`pick`), never
  a floor or hash: those split letters in two. Headings drift via a `MarbleFlow`
  node, not TIME (it resets hourly). `tests/check_marble_text.tscn` guards it.
- **No panels anywhere.** All UI is glass words over the scene: menus, the
  HUD readouts, the lesson hint and the win screen (the room dimmed behind
  it). The old glossy panels, pills, cards and icons were removed.
- `scripts/menu_panel.gd` is the only kind of button: clickable glass words
  (`make_text`, or `make_text_stepper` for − and +). They grow and their
  swirls drift when pointed at, and they chime. Menus are mouse only: words
  can't take keyboard focus (`focus_mode = FOCUS_NONE`), so nothing is
  pre-selected and the arrow keys do nothing. Esc still backs out of menus.
- **The marble bag** (`scripts/marble_bag.gd`, `scripts/bag_marble.gd`) sits
  in the HUD's bottom-right corner. Each catch drops a ball in that
  creature's colour, with eyes, into a clear bag where it rolls and
  piles up. It's a SubViewport with its own 2D physics world, so the balls
  can't touch the 3D game. One function, `_outline()`, gives the bag's shape
  for both drawing and the walls the balls hit, so the two always match.
  The balls are glass marbles like the menu text
  (`shaders/glass_marble.gdshader`: smoky glass, white edge light, a swirl in
  the creature's colour, bubbles), with the eyes drawn plain on top. The bag
  is clear film: faint fill, fine white edges, reflections and creases, a
  gathered neck. No bow, no tag. Balls clack like glass marbles when they land and knock together
  (`Tones.clack`: a bright crack with a very short two-pitch glass ring,
  three takes; you picked it from five in `tests/render_clacks.tscn`).
  **It sways with you**: turning the camera or moving swings it from the
  neck on a damped spring (`_sway`, `SWING_*`), and the marbles slosh: their
  gravity tilts with it and they get the hand's change in speed backwards
  (`SLOSH`). `HAND_PER_TURN`/`HAND_PER_METRE` set how strongly. Marbles
  can't rise fast enough to leave by the open top, and any that slip out
  through a wall are put back.
  Catches made close together queue up and drop 0.16 s apart. The neck
  loosens while balls go in, and the bag squashes a little when each lands.
  To make the bag fuller or emptier at the end, change `BagMarble.RADIUS`
  (21): all 25 currently fill a little over half of it.
- **No number on screen for catches**: the marbles in the bag are the
  counter. The bag still keeps the count for tests (`Hud.caught_text()`).
- **On winning, the bag moves onto the win screen** beside your time.
  `reparent()` carries its whole subtree, physics world included, so any
  balls still queued keep dropping in there.
- **The title's background** is the real house (`scripts/title_backdrop.gd`):
  main.tscn loaded without the player, HUD, menus, lesson, ping or main.gd,
  seen from the bedroom rug toward the bed with a slow drifting camera. A
  stand-in "player" sits at the camera, so the four marbles under the bed
  (turned to face it) peek and glint at you. The menu sits on the left over
  a dark shade (`UiStyle.title_shade`); the whole room dims under Settings.
  `tests/shoot_title.tscn` shoots four points along the drift.
- **The mouse pointer** is the normal system arrow (the custom hand was removed).
- `scripts/settings_menu.gd` is the settings page, shared by the title screen
  and the pause menu, in three sections: Controls, Sound and Graphics. Each
  setting is a −/+ stepper rather than a slider, so
  every control is the same panel and nothing needs dragging. The page
  shrinks to fit a shorter screen (`SettingsMenu._fit`).
- `scripts/pause_menu.gd` owns the Esc key: it pauses the tree, frees the
  cursor and hides the HUD. Its node's process mode is Always, so it keeps
  running while everything else is frozen.
- `scripts/settings.gd` holds what the player chose (look sensitivity, invert
  Y, volume, lighting quality) in `user://settings.cfg`, reachable as `Game.settings`. The
  `mouse_sensitivity` tunable is now only the default for a brand-new player.
- Sizes are in the project's 2560x1440 design space (Project Settings >
  Display), which the window scales to fit, so the numbers in the UI scripts
  are about twice what they look on a 1080p screen.

`tests/shoot.tscn` renders the title, settings, game, pause and win screens,
plus close-ups of the marble bag part-full and full, to PNGs in `user://shots` so they can be checked without playing. It needs a real
window, so run it without `--headless`:

```
"C:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe" --path . --resolution 1600x900 res://tests/shoot.tscn
```

## The grab beam holds the spot you clicked

The beam grabs the exact point under the crosshair (`Beam._grab_local`, kept
in the object's own coordinates so it moves with it). Each physics tick it
works out the one push, applied at that point, that moves the point towards
the hold point in front of the camera. This is the same maths a physics
engine uses for a pin joint (`_push_point_to_velocity` in beam.gd). The rest
of the object turns about that point on its own:

- grab the middle of something and it lifts level
- grab a corner and it hangs tilted from that corner
- grab the top of the bookcase and pull down, and it topples over

Wheel distance, throwing, the too-heavy latch and the lift limit are
unchanged. The beam ribbon now ends at the grab point rather than the
object's middle. `held_spin_damping` still applies: it's what makes a
dangling object settle after a swing or two instead of swinging on. Lower it
for floppier, more pendulum-like handling.

## Impact sounds

Your choices: real knocks, a sound per material, placed in 3D, and quieter
than the creature squeaks.

- **Materials.** Each prop scene sets `impact_material` (Prop's export):
  paper (books, small boxes), wood (crates, bookcase, table, wardrobe; the
  default), soft (pillows, bed), rubber (balls), plastic (bins).
- **The sounds** are recipes in `Tones.KNOCK_RECIPES`, with no steady
  musical tones (an earlier version had them, and a pile of things falling
  played a tune). Each knock is a contact click, a scuff of filtered noise,
  noise through a few wide resonances (the wooden "toc" or plastic "clack"),
  and for weighty things a very short thud that drops in pitch like a kick
  drum. `Tones.resonance` sets how much the resonances ring: you picked 1.0
  ("woody") over 0.5 ("dry"). Above about 1.5 they start to turn into notes. There are three slightly different takes of each, so
  repeated hits don't sound copy-pasted. To change how a material sounds,
  edit its recipe. `tests/render_knocks.tscn` saves every prop's knock to
  WAV files in `user://knocks` (dry and woody sets) so you can listen
  without playing.
- **Heavier is lower.** Each material is tuned for one mass
  (`ImpactAudio.REFERENCE_MASS`). Heavier props play it slower and lower, so
  the pillow's thump becomes the bed's thud.
- **Detecting a hit** (`Prop._integrate_forces`): Jolt reports how hard each
  contact pushed this tick. A hit is a sudden jump in that push, so resting,
  rolling and being dragged along the floor make no sound. The push over the
  next three ticks is added up and played as one knock, because big things
  land leg by leg. Divided by mass, it's on the same scale for a book and a
  wardrobe.
- **Where and how loud.** `scripts/impact_audio.gd` (`Game.impacts`) is a pool
  of 14 3D speakers, so a whole shelf falling is a clatter, not a wall of
  noise. Loudness tunables are under Impacts: `impact_min_speed` (0.8 m/s:
  softer hits are silent), `impact_full_speed` (7 m/s: full volume) and
  `impact_max_db` (-10, kept below the squeaks' -4).
- Nothing knocks for the first 1.2 s after the room loads, while it settles.

## The landing lesson

Every run starts on the **landing** (x -4.4..-0.8, z 2.65..5.85), south of
the playroom, behind a shut door. `scripts/tutorial.gd` shows one hint at a
time in glass words just above the crosshair (`Hud.show_hint`): grab
the box, throw it, ping, lift what squeaked, catch it. Each goes once done
(via `Beam.grabbed`/`thrown`, `Ping.pinged`, the creature's state and
`captured`); doing a later thing early skips ahead. The catch swings the
door (an AnimatableBody3D, origin at the hinge) 100° into the playroom and
the last hint fades after 4 s. The lesson creature counts like any other
(26 in all), so its lift arrives before the house. The timer runs from the
start. A ping from the landing can reach a couple of playroom creatures
through the wall.

## The catch

Your choices: the creature is sucked into the beam, with sparkles, a suction
slurp. (Three styles were built and compared in
play; the other two, flying into the bag and popping on the spot, were
removed.)

- **Sucked into the beam** (`Creature.capture`): it turns to face your hand
  and stretches toward it as it's pulled in, speeding up as it goes. Then a
  ball in its colour drops into the bag.
- **The catch beam** (`Beam._draw_catch_beam`): at the click the beam shoots
  out (over 0.06 s) and latches onto the creature in the creature's own
  colour, then reels it in, shortening as it comes. It's gone the moment the
  creature reaches the hand.
- **Sparkles** (`scripts/catch_sparkles.gd`): about 26 star glints that pop
  out white, tint to the creature's colour, spin and twinkle away. The star
  shape is drawn in code. They remove themselves when done.
- **Slurp** (`Tones.slurp()`): noise through a resonance sweeping upward,
  with a bubbly wobble, ending in a little plop. `tests/render_knocks.tscn`
  also saves it as `catch_slurp.wav`.

## The beam's look and the bloom

Your direction: an energy beam that glows and pulses like a live wire, casts
its light onto the room, and a cosy bloom over everything.

- **The beam** is drawn by `shaders/beam.gdshader` on the ribbon beam.gd
  builds: a white-hot core inside a soft coloured halo, bright pulses sliding
  from your hand to the object, and a restless flicker. It's brighter than
  white, which is what the bloom picks up. A second, thin ribbon (the
  filament) takes a new jagged shape 30 times a second around the core, like
  a spark. Colours: cyan holding, red straining, the creature's colour when
  catching. Straining also makes it "agitated": faster pulses, more flicker
  and a wilder filament.
- **The aura**: whatever the beam holds glows with a soft blob of light in
  the beam's colour (cyan holding, red straining) behind and around it,
  wobbling and pulsing (`shaders/beam_aura.gdshader`). It's an ellipsoid
  fitted round the object (`Prop._make_aura`, sized by `AURA_GROWTH` and
  `AURA_PADDING`) with only its far side drawn, so the object hides its
  middle and a halo shows round the edge.
- **The beam starts below the bottom of the screen** (`BEAM_ORIGIN_LOCAL`),
  so it runs in from off the bottom edge; caught creatures are pulled down
  there too.
- **The beam's sound** (your choices: a warm whirr that reacts to swinging,
  and crackle and fizz when straining). `Tones.whirr()` is a rounded 140 Hz
  tone with soft harmonics and a gentle sway, a seamless one-second loop.
  While you hold something it plays at -18 dB; swing it and it rises up to
  60% higher and swells to about -10 dB, then settles when you hold still
  (`HUM_*` and `SWING_FULL_SPEED` at the top of beam.gd). Straining plays
  `Tones.strain_crackle()`: a strained, wavering hum with irregular pops,
  at -13 dB. Both fade in and out, and come from your hand rather than the
  object. `tests/render_knocks.tscn` saves them as WAVs too.
- **Light on the room:** two lights travel with the beam, a stronger one
  just off the grab point and a softer one halfway along, both in the
  beam's colour and flickering with it, so it tints the object, the floor
  and nearby walls. There's also a glowing dot where the beam meets the
  object (`shaders/glow_dot.gdshader`).
- **Knobs** are constants at the top of beam.gd (`GLOW_HALF_WIDTH`,
  `FILAMENT_JITTER`, `CRACKLES_PER_SECOND`, `END_LIGHT_ENERGY`,
  `MID_LIGHT_ENERGY`, the two colours) and uniforms at the top of the shader
  (`intensity`, pulse speed and spacing in `fragment()`).
- **Bloom** is on the main scene's WorldEnvironment (select it in main.tscn
  and look under Glow): soft, wide glow levels and the Screen blend, which
  lightens rather than burns out. Only things brighter than white glow (the
  beam, the lamp's hotspot, creature glows, sparkles). The tone curve is
  Filmic at exposure 0.9, so the ceiling hotspot rolls off softly instead of
  clipping. Your first look was too bright, so it was toned down: Glow >
  Intensity 0.8 to 0.5, Glow > Bloom (a haze over everything) 0.08 to 0,
  and the beam, its contact glow and its lights to about two thirds.

## The house

Three real-size rooms (the old 12 × 10 m room didn't read
as a real room). Ceilings stay 3 m. Plan: `tests/shoot_rooms.tscn` renders
each room (needs a window).
- **Playroom** (x -5.1..-0.1, 5 × 4.5 m), through the landing door: toy-box crates (a stacked pair in the north-west
  corner), the bookcase on the west wall, a beanbag, the play table on the
  rug over the trapdoor, a small box stack, two bins. Planks.
- **Bedroom** (x 0.1..5.1, 5 × 4.2 m), through a doorway at z=0: the bed
  under the window, bedside table, chest of drawers, the wardrobe in front
  of the box-room door, a desk and chair, a laundry bin. Teal carpet.
- **Box room** (x 5.3..8.3, 3 × 2.8 m) behind the wardrobe.
- The "main room" layout files hold the playroom and bedroom together; the
  "side room" ones are the box room.
- New props: `desk.tscn` (10 kg), `chair.tscn` (3 kg), `chest_of_drawers.tscn`
  (20 kg, three sliding drawers), `beanbag.tscn` (2 kg).
- Small household things, all clutter (0.15–1.8 kg, liftable from the start).
  Playroom: teddy bear, toy car, stacking rings (table), toy drum, floor
  cushion, shape sorter, toy dinosaur. Bedroom: alarm clock (bedside table),
  globe, pencil pot and mug (desk), two slippers by the bed (felt toe, fleece
  cuff; a spare `bunny_slipper.tscn` is kept for later), school bag, two
  stacked shoe boxes, folded jumpers and a piggy bank (chest). Their meshes
  are only partly matched by collision shapes (fine detail like wheels and
  pencils is visual only). `check_room` checks they settle where they're put.

## The room's look: cosy, up past bedtime

Your direction: the bright colours and bloom of mid-2000s console games,
warm cream and citrus, lamp light, and above all cosy, "as if you're a
child up past your bedtime". So it's night.

- **The bedroom.** The bed under the window took the
  sofa's place and its job (60 kg gate, four creatures underneath), with
  two pillows and a bedside table. The table's lamp is its own 1.2 kg
  prop (`bedside_lamp.tscn`, a shadowless glow). The table's drawer is a
  1 kg prop of its own on a `Generic6DOFJoint3D` (DrawerRunner) that only
  lets it slide 0.26 m in and out, so it moves by physics: a sudden stop or
  a forward tip slides it out, the reverse slides it home, and the beam can
  pull it by its front. Runner friction is a zero-speed joint motor. Four
  toy blocks (`toy_block.tscn`, 0.1 kg) sit inside and can fall out.
- **Drawers** (`scripts/drawers.gd`) are shared by the bedside table and the
  chest of drawers: every child Prop named "Drawer..." slides on a joint
  named after it plus "Runner". `drawer_travel` and `runner_friction` are
  exports: table 0.26 m / 2.5 N, chest 0.34 m / 5 N. The chest is hollow
  with three 2 kg drawers; pull one with the beam and the others stay shut.
  Shoved hard, the 20 kg chest tips forward a little and its bottom drawer
  can catch on the floor.
- **Parts can't lift their furniture.** Drawers and wardrobe doors know their
  furniture (`Prop.part_of`). While the beam holds one and the furniture is
  over the lift limit, the furniture is frozen in place (`Prop.plant()`), so
  you can pull a drawer open but not drag, tip or lift the table by it.

- **Light** (main.tscn): the pendant lamps are turned down to a warm orange
  glow (their shades block light upward, which is the darker band at the
  top of the walls). Moonlight is a cool
  spotlight outside the window (Moonlight), shining down through it; the
  wall's shadow limits it to the window's shape, so the frame's cross shows
  on the floor. The rest of the room is lit only by a dim, cool blue fill
  (the environment's ambient light, 0.08), which is what reads as night. Soft
  shadowing in corners and under furniture comes from SSAO (intensity 2.4,
  power 1.8, detail 2.0 for tight contact shading under props, light affect
  0.25 so it still shows inside lamp pools).
  Darker, moodier pass: lamps 0.55 with steeper falloff (attenuation 1.7) so
  they make pools of light, dimmer shade and bulb glow, moonlight 1.8 with
  blurred edges, exposure 0.85, wider shadow softness (light size 0.3, 0.45
  on High), saturation back to 1.0.
- **Bloom** catches only things brighter than white: the lamp bulbs and
  shades, the moon, the creatures (whose glow was raised to 0.8 so they're
  little lights in the dark), the beam and the sparkles.
- **Surfaces** are drawn by shaders, in metres in the world:
  `shaders/wallpaper.gdshader` (cream paper with gold stars, white skirting, plain
  ceiling), `shaders/plank_floor.gdshader` (oak planks, each a slightly
  different shade), `shaders/rug.gdshader` (the rounded rug), and
  `shaders/sky.gdshader` (the night sky panel outside the window: stars that
  twinkle, a moon, clouds drifting past lit silver near the moon). The side
  room has a teal carpet.
- **Props** are warm cream and citrus: a honey-wood bed with a raspberry duvet, raspberry books, lime
  bins, toy-box crates in mixed colours, orange boxes and balls, honey-wood
  furniture. Each is one `albedo_color` line in its scene.
- **Finish** (`Main._apply_prop_finish`) follows each prop's impact
  material: matte wood (roughness 0.72), flat fabric and paper, soft satin
  on plastic and rubber; no clearcoat. (The earlier all-glossy finish read
  as too plastic.) The pendant shade is unshaded with a gentle glow, so the
  bulb 10 cm away can't blow it out; the ceiling paint is a dim warm grey.
- **The lamps swing** (`scenes/pendant_lamp.tscn`, `scripts/pendant_lamp.gd`,
  one per room as LampMain and LampSide). Each is a 1.5 kg RigidBody3D
  hanging 0.73 m below its ceiling fixing on a PinJoint3D, which keeps that
  one point fixed and lets it swing freely. The shade, bulb and light ride
  on it, so a hit sends the light and its shadows sweeping around the room.
  The cord is redrawn every frame between the fixing and the shade. It sits
  on the props layer so thrown and held props hit it, but it isn't a Prop,
  so the beam can't grab it. Damping (on the Lamp body) settles a big swing
  in about five seconds; lower it for longer swinging. Each lamp's
  brightness and reach are exports on the instance.
- **Lamp shadows.** The shade is open at the top as well as the bottom, like
  a real one, so a soft circle of light sits on the ceiling above it, and a
  tilted shade throws a wedge of light up one side. The light has a size
  (`light_size` 0.25), so its shadows soften with distance. A second, weak
  light with no shadows (GlowThroughShade, 20% of the lamp's brightness) is
  the glow through the fabric: without it, whatever the shade blocks gets
  no lamp light and the shadow ends in a hard line on the walls.
  How soft and how costly is the player's choice (below).
- **Settings > Graphics > Lighting: High / Medium / Low** (`Settings.apply_lighting`).
  The lamps' soft shadows are most of the GPU's work per frame, so this
  is the one quality setting. Each lamp casts shadows only while the camera
  is in its room or within 0.8 m of it (`room_half_size` on each lamp in
  main.tscn); its light stays on. Measured on an RTX 5080 at 1080p from the
  bedroom with the lamps swinging (`tests/bench_gpu.tscn` re-measures):
  | Level | GPU per frame | What it does |
  |---|---|---|
  | High | 2.3 ms | lamp size 0.45 so shadows soften with distance; Ultra filtering; TAA; SSAO High, full res; shadow atlas 4096 |
  | Medium (default) | 1.2 ms | lamp size 0.3, Medium filtering, TAA, SSAO Medium half res, atlas 4096 |
  | Low | 0.56 ms | no lamp size, a plain even shadow blur, no SSAO, FXAA instead of TAA, atlas 4096 |
  It applies straight away, including from the pause menu, and is saved
  with the other settings. New players start on Medium; your own saved
  settings will also start on Medium, so switch to High if you prefer it.
  `tests/shoot_lamp.tscn` renders the ceiling
  around the lamp, still and mid-swing, for checking.
- **Settings > Graphics > Pixel filter (On/Off) and Pixel size (1–8)**: the
  chunky low-res look. `scripts/pixel_filter.gd` is a CanvasLayer at layer
  −100 under the Game autoload; its shader (`shaders/pixel_filter.gdshader`)
  point-samples the screen in whole-pixel blocks, so only the 3D is
  pixelated and the HUD and menus stay crisp. Size n makes the screen
  1080/(n+1) blocks tall (default 3 = 270). Off by default. It's a look, not
  a saving: the 3D still renders at full resolution.
  **Graphics > Dither** (off by default) adds the old colour limit: 16 shades
  per channel with a 4x4 Bayer dither (`shaders/dither.gdshaderinc`), on the
  3D. Off, there's no colour limit.
  While it's on, the wallpaper, floor, rug and pictures snap to a texel grid
  (`Settings.PIXEL_TEXELS_PER_METRE`, 32; the wallpaper uses twice that) via
  the `pixel_texels` shader global (Project Settings > Shader Globals) and
  `shaders/pixel_art.gdshaderinc`.
  The marble bag is not pixelated (you asked for it to stay smooth).
  The bag is shown at 0.75 size (`MarbleBag.DISPLAY_SIZE`; drawn and
  simulated in `VIEW_SIZE` coordinates via `size_2d_override`) with no
  shadow under it.
  Menus, buttons and the in-game HUD stay crisp (they're on higher layers).
  `tests/shoot_pixel.tscn` renders it off and at a few sizes.
- **The window** is a hole cut in the wall with a pane of invisible
  collision in it, so nothing can be thrown out.
- **Readability**: a darker room makes props and creatures harder to spot,
  which changes the hunt. Worth watching in play. The quickest lever is the
  ambient light energy (0.2) on the WorldEnvironment.

## Tunables

Everything you're likely to tweak is in **`config/tunables.tres`**. Click it in
the FileSystem dock and edit it in the Inspector, grouped as World, Player, Beam,
Lift, Creatures and Ping. The defaults and a comment for each value are in
`config/tunables.gd`. Once you change a value in the Inspector, the `.tres` copy
wins over the default in the `.gd` file.

A few visual constants stay as `const` at the top of their scripts, because
they're look rather than feel: the shudder amount (prop.gd), the beam ribbon
width (beam.gd), the catch lock-on (`CATCH_ASSIST_DEGREES` 10°, or within
`CATCH_ASSIST_RADIUS` 0.3 m of the aim line, in beam.gd: nearest the crosshair wins).

**You start weak: 4 kg, plus 4 kg per catch** (Grace's playtest: work up to
it). At first only books, balls, bins, pillows and small boxes lift. 15
creatures are catchable before the bed, 19 before the wardrobe:
- crates, the table and the bedside table unlock at **1** catch (8 kg), the
  bookcase at **2** (12 kg)
- the 60 kg **bed** unlocks at **14** catches (exactly 60 kg)
- the 80 kg **wardrobe** (was 115) unlocks at **19** catches (exactly 80 kg)

**Furniture is drag and tip only** (over `max_lift_mass`, 3 kg), so throwing
it about can't heap up the room. The beam's upward pull on it is capped at
`drag_lift_share` (0.7) of its weight: pulled by an edge it tips on the far
edge, but it never leaves the floor, and Throw just lets go. The lift limit
above still decides which furniture you can grab at all.

The beam reaches **4 m** (was 7), for grabbing and catching, so you have to
walk up to things.

Nothing announces an unlock: you find out by trying. If you move creatures between rooms or
change `lift_per_capture`, redo this sum (`tests/check_stage3.gd` checks it).

## Collision layers

Named in Project Settings > Layer Names > 3D Physics. A layer's bit value is
2^(layer − 1), which is the number you see in the code.

| Layer | Value | What's on it | Notes |
|---|---|---|---|
| 1 world | 1 | walls, floors (CSG) | |
| 2 player | 2 | the player capsule | |
| 3 props | 4 | props over 3 kg: crates, table, bedside table, bookcase, bed, wardrobe | block the player |
| 4 creatures | 8 | creature bodies; exposed creatures' PickZone areas | marks it catchable (the beam aims with a lock-on cone) |
| 5 clutter | 16 | props of 3 kg or less: books, balls, pillows, bins, small boxes, the bedside lamp, toy blocks | the player walks through them and kicks them |
| 6 rug | 32 | the rug | meets only the floor; the beam can aim at it |

`prop.gd` picks props or clutter by mass when it loads, overriding the layer
saved in the `.tscn`. Two bodies collide if *either* one's mask includes the
other's layer.

- **Player** (mask world + props): blocked by walls and heavy props, never by
  clutter or creatures.
- **Creatures** (mask world + props + creatures + clutter, set in creature.gd).
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
| check_stage4 | ping range and cooldown, both gates, wardrobe off the doorway, side room, win, timer, marble bag (one ball per catch, none escape), restart |
| check_drag | furniture tips and drags but never leaves the floor or gets thrown; books still lift; the bed tips up |
| check_floor_clutter | the player wades through clutter and is blocked by crates |
| check_smoothness | even movement per frame at 157 fps |
| check_bump | a creature rolling into another collides and clacks, once |
| check_hiding | uncovered creatures cower somewhere the player can't see from where they stand |
| check_menus | title panels; settings sections, steppers and saving; Graphics > Lighting levels, clamping and applying live from the pause menu; Pixel filter toggle and size; pause/resume, restart, quit to title |
| check_grab_point | a crate lifted by its middle stays level, by a corner hangs tilted; the bookcase pulled down by its top falls over; the beam ends at the grab point |
| check_tutorial | you start on the landing behind a door that holds you in; hints follow grab, throw, ping, find, catch; the catch opens the door and you can walk through |
| check_catch | sucked into the hand and stretched; the beam shows in its colour, reaches it and goes after; sparkles and slurp; one ball in the bag; sparkles clean up |
| check_beam_look | the beam's glow, filament, contact glow and lights come on with it, take its colour, sit at the grab point, go red and agitated when straining, and all go when it does |
| check_room | a ball thrown hard at the window stays in the room; wooden props are matte; the bedside lamp stands on its table; the drawer rests shut, slides out when the table stops suddenly and home when shoved back, and can be grabbed |
| check_lamp | the lamp hangs still; a thrown book swings it and its light; it stays on its cord; it settles; the beam can't grab it |
| check_beam_sound | silent when idle; the whirr fades in on grabbing, rises and swells when swung, settles, fades out on letting go; crackle only while straining; both loop; quieter than squeaks |
| check_impacts | the room settles silently; a dropped crate knocks as wood from where it landed; gentle set-downs and resting are silent; books, the bed and balls get their materials; the bed thuds lower than a pillow; knocks stay below squeak volume |

They're scenes, not `--script` runs, so that the `Game` autoload loads first.

## What isn't verified

The tests prove the systems do what they're meant to in a simulation. They can't
tell whether any of it is fun or readable. Not verified:

- **Feel:** whether holding, throwing, kicking clutter, the gate pacing and the
  hunt are enjoyable. Nothing has been checked by eye.
- **Sound:** headless runs use a dummy audio driver. I only know a squeak
  *started*, not whether it's audible, pleasant, or easy to locate in 3D.
- **Visuals:** the glow, the cover rattle, the hop, the tremble, the crosshair
  shapes and the lighting are all unseen. (The title, settings,
  pause, win screen and in-game HUD *have* been looked at, as still images
  from `tests/shoot.tscn`. The hover lift, glow and press animations have
  not, because a still image can't show movement.)
- **Menu sound:** the hover and select chimes have only been checked as "a
  sound started", the same as the creature squeaks.
- **check_hiding is slightly flaky** and slow, so it's left out of routine
  runs. Books on the bookcase's bottom shelf used to count as cover, sending
  creatures somewhere unreachable; props now only count if the floor is
  directly under them. That fix hasn't been re-checked with this test.
- **Clue quality:** whether tells and ping really let you follow clues instead
  of checking every bin.
- **Smoothness on a real display:** the numbers are perfect headless, but
  V-Sync and frame pacing on your machine could still add judder.
- **Edge cases:** wedging things into the doorway, stacking props to climb,
  creatures cornered behind heavy furniture, and a held wardrobe swept through a
  room full of clutter. None of these were tried.

## The wardrobe

A hollow cupboard (`scripts/wardrobe.gd`) with two 3.5 kg doors, each a
Prop on a `HingeJoint3D` that swings outward up to 110°. Grab a door and
pull. Two creatures (InWardrobe1/2) hide inside; opening a door reveals
them. Door damping (`HINGE_DAMP`) stands in for stiff hinges, because a
hinge motor locks a Jolt hinge solid. The wardrobe is frozen (static) until
the beam first lifts it (`Prop.frozen_until_grabbed`), so pulling a door
can't drag it off the doorway before its gate.

## Pictures

Three framed pictures (`picture.tscn`, `shaders/picture.gdshader`, `art`
0-2) hang frozen on the walls (playroom west and north, bedroom south) until the beam takes them down.
Two cover cubby holes cut in the wall (CubbyWest / CubbySouth, CSG
subtractions in main.tscn): one hides a creature (BehindPicture, moved from
under a bin, so the count is unchanged), the other two toy blocks. A hidden
creature has no gravity, so it waits in the hole until revealed.

## The rug and the trapdoor

The rug is cloth: a 1.8 m square `SoftBody3D` (`rug.tscn`, `scripts/rug.gd`)
under the table, and both sit over a closed trapdoor (House/Trapdoor in
main.tscn, meshes only; it doesn't open yet).
- The beam only holds Props, so the rug has an invisible Prop, its Grip
  (`scripts/rug_grip.gd`). Aiming at the cloth offers the grip; just before
  the grab (`Prop.prepare_grab`) it jumps to that spot and pins the cloth
  points within 0.3 m to it. While held, rug.gd moves those points with the
  grip each tick (`soft_body_move_point`: Jolt ignores pin attachments).
- It can't be lifted while anything of 5 kg or more stands on it
  (`PIN_DOWN_MASS`): the crosshair says "SOMETHING'S ON IT" and the beam
  strains (`Prop.why_stuck`). Move the table off first.
- A flat rug is level with the floor, so the beam takes the rug when a
  rug-only ray hits within 5 cm of where the floor was hit.
- The rug's own physics layer (6) meets only the floor, so things on it stay
  put and a lifted rug passes through furniture.

## How creatures move

They roll like marbles, eyes and all: each tick the ball turns about the
axis sideways to its travel, by distance over its radius (`_move` in
creature.gd). Once cowering, they roll back upright to look at you and bob
in a happy bounce instead of the old shiver, which looked sad (Grace's
playtest). `BOUNCE_*`, `SETTLE_RATE` and `ROLL_RADIUS` are at the top of
creature.gd.

They bump into each other, walls, props and clutter (`MASK_BODY`), and a
fresh bump faster than `CLACK_SPEED` plays the bag's marble clack from where
it hit (`_react_to_bumps`). A CharacterBody3D can't push rigid bodies, so it
knocks clutter along with an impulse (`KNOCK_MASS`).

They're 11 cm across (radius 0.054)
and run at `flee_speed` 2.2 m/s, so they fit in drawers. Four hide in
drawers (`drawer_furniture` / `drawer_index` on the creature): three in the
chest, one in the bedside table. They ride the drawer as it's pulled and pop
out over its front once it's out `DRAWER_REVEAL_OUT` (0.2 m), heading
straight out for 0.6 s before steering away from you. Knocks don't reveal
them.

## The creatures' eyes

The creatures are cheeky and playful, and all of it is in the eyes
(`scripts/creature_eyes.gd`, on Visual/Eyes). The body is a glass marble
matching its marble in the bag (`shaders/creature_marble.gdshader`: smoky
glass, swirl in its colour seen through the ball, bubbles, edge light), and
the eyes are painted flat on it by the same shader, which creature_eyes.gd
feeds each tick: blink, widen, squint, where the pupils look (up to 42° off
straight ahead), happy arcs, glint. `tests/shoot_creature.tscn` renders a
close-up row of moods.
- Always: blinks every 2-5 s; catchlights on the pupils; the whites glow
  faintly so they read as white at night.
- Hidden: every 3-8 s it peeks at you for a second; its giveaway (and a
  ping) makes the eyes glint, bright enough for bloom.
- Found: wide eyes for 0.35 s, then a cheeky squint as it bolts.
- Running and cowering: it keeps its eyes on you, and winks now and then
  while it waits.
- Caught: happy ^ ^ arcs as it's pulled into the beam.
Timings are constants at the top of creature_eyes.gd and creature.gd.

A cover lifted by the beam (an upturned crate) used to be able to scoop its
creature up inside it as it popped out. The creature now passes through a
lifted cover for a second as it escapes.

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

- You can only catch a creature you can see: its middle or its top must be
  in clear view past walls and furniture. One cowering behind a box or a
  wardrobe door can't be caught through it, and the click grabs the box.
- The player pushes clutter like a snowplough: anything dead ahead gets shoved
  until it reaches a wall.
- Creatures under the bed ignore jolts and things flying past (so the gate
  can't be skipped by pelting the bed), but a book slid *under* the bed can
  still startle them.
- The bed and wardrobe can't tip over until they've been lifted once.
- If a creature falls out of the world it reappears in the playroom–bedroom doorway.
