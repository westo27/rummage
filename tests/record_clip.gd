extends Node
## Records one gameplay clip for social posts: the real player and beam,
## driven by script through one lively moment, with the game's own sound.
## Run under Godot's movie mode (tools/make_clips.sh does this for every clip,
## wide and tall, and cuts them to MP4):
##   Godot --path . --write-movie <out.avi> --fixed-fps 60 --resolution 1920x1080
##     res://tests/record_clip.tscn -- <clip>
## Setting up happens on camera too, so it prints "CLIP <first> <last>": the
## frames worth keeping, for the cut.

const PressLook = preload("res://tests/press_look.gd")
const SEED: int = 4
const Drawers := preload("res://scripts/drawers.gd")
const CreatureScene: PackedScene = preload("res://scenes/creature.tscn")
## Clips the script knows, in the order make_clips.sh records them.
const CLIPS: Array[String] = ["drawers", "wardrobe", "bookcase", "picture", "bin", "chair", "bin_throw", "mitosis"]

var _main: Node
var _player: CharacterBody3D
var _head: Node3D
var _beam: Beam
## The camera rig: the script moves an aim point (`_aim`, eased from one
## spot to the next by _turn_to), and the view chases it on a spring each
## physics tick, so it lags a touch, settles, and overshoots a quick flick,
## like a hand on a mouse. A slow sway and a slight creep forward on top.
## Every turn, pull and pause in the clips takes this many times as long as
## written: one knob for the pace of the lot.
const PACE: float = 1.6
const SPRING_HZ: float = 1.9
## Below 1 overshoots a little.
const SPRING_DAMPING: float = 0.75
## Handheld sway, in radians, and how fast it wanders.
const SWAY: float = 0.008
const SWAY_SPEED: float = 0.35
## How fast the player edges toward what it's looking at, metres a second.
const CREEP: float = 0.05
## Once marbles are out, how far the view leans from where the script points
## it toward the middle of them (0 none, 1 all the way). Not while holding
## something: the throw goes where the script aims.
const FOLLOW: float = 0.5
## A marble this far (metres) from the scripted aim pulls about a third as
## hard: one that breaks away from the rest doesn't drag the view off.
const FOLLOW_FALLOFF: float = 1.2

## The spot the last _turn_to was heading for, so the next eases from it.
var _target: Vector3 = Vector3.ZERO
var _aim: Vector3 = Vector3.ZERO
var _rig_on: bool = false
## The view's yaw and pitch, and how fast each is turning.
var _view := Vector2.ZERO
var _view_speed := Vector2.ZERO
var _sway := FastNoiseLite.new()
var _clock: float = 0.0
## Holds the player at this crouch (0 stand, 0.5 crouched); < 0 leaves it be.
var _crouch: float = -1.0
var _first_frame: int = 0
## Every creature in the house; clips take named ones or borrow spares.
var _pool: Array[Creature] = []
## The ones in this clip: the view follows them once they're out.
var _cast: Array[Creature] = []
## How fast the player edges forward (negative: backs away).
var _creep: float = CREEP
## The mitosis gag: while on, every marble that's out splits in two each time
## it bumps into something.
var _mitosis: bool = false
## When each marble may next split, so one bump is one split.
var _split_ready: Dictionary = {}
var _splits: int = 0
var _follow_now: float = 0.0
var _group_mid := Vector3.ZERO


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _crouch >= 0.0:
		_player.set("crouch", _crouch)


func _physics_process(delta: float) -> void:
	if not _rig_on:
		return
	_clock += delta
	var wanted: Vector2 = _angles_to(_followed_aim(delta))
	# A damped spring: pulled toward where it's wanted, slowed by its speed.
	var w: float = TAU * SPRING_HZ
	_view_speed += ((wanted - _view) * w * w - _view_speed * 2.0 * SPRING_DAMPING * w) * delta
	_view += _view_speed * delta
	var sway := Vector2(_sway.get_noise_1d(_clock * SWAY_SPEED * 100.0),
		_sway.get_noise_1d(_clock * SWAY_SPEED * 100.0 + 500.0)) * SWAY
	_player.rotation.y = _view.x + sway.x
	_head.rotation.x = _view.y + sway.y
	var ahead := Vector3(-sin(_view.x), 0.0, -cos(_view.x))
	_player.global_position += ahead * _creep * delta
	if _mitosis:
		_divide()


func _run() -> void:
	DoodleFace.only = DoodleFace.PRESS_FACES
	PressLook.use()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var clip: String = args[0] if not args.is_empty() else CLIPS[0]
	seed(SEED)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main.get_node("Player") as CharacterBody3D
	_head = _player.get_node("Head") as Node3D
	_beam = _main.get_node("Player/Head/Camera3D/Beam") as Beam
	# Only the script steers: no mouse, no keys.
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_beam.set_process_unhandled_input(false)
	_main.get_node("Tutorial").queue_free()
	(_main.get_node("HUD") as CanvasLayer).visible = false
	# The side room's first, as spares: no clip happens there.
	for group in ["SideRoomCreatures", "MainRoomCreatures"]:
		for c in _main.get_node(group).get_children():
			if c is Creature:
				_pool.append(c as Creature)
	# Late in a game: strong enough for anything that isn't furniture.
	_beam.lift_limit = 40.0
	await _frames(30)
	await call("_clip_" + clip)
	print("CLIP %d %d" % [_first_frame, Engine.get_frames_drawn()])
	get_tree().quit()


# --- Clips -------------------------------------------------------------------

## Crouched at the chest of drawers, yanking them open top to bottom: two
## marbles pop out of each and roll off in arcs, out into the room and round
## under the side of the bed.
func _clip_drawers() -> void:
	var chest := _main.get_node("MainRoomProps/ChestOfDrawers") as Drawers
	var out: Vector3 = chest.global_basis.z
	var side: Vector3 = chest.global_basis.x
	var fronts: Array[Vector3] = []
	for drawer in chest.drawers:
		fronts.append(drawer.global_position + out * 0.23)
	var bed := _main.get_node("MainRoomProps/Bed") as Node3D
	var bed_side: Vector3 = Vector3(bed.global_position.x + 0.5, 0.05, fronts[1].z + 0.35)
	# A second in each drawer, the two side by side.
	var riders: Array[Creature] = []
	for name in ["InChestTop", "InChestMiddle", "InChestBottom"]:
		riders.append(_take(name))
	for i in 3:
		var extra: Creature = _spare()
		extra.drawer_furniture = extra.get_path_to(chest)
		extra.drawer_index = i
		extra.call("_settle_in_drawer")
		_shift_in_drawer(riders[i], -0.12)
		_shift_in_drawer(extra, 0.12)
		riders.append(extra)
	# Out in the room, the chest and the long side of the bed both in view.
	_crouch = 0.4
	await _frames(20)
	await _place(Vector3(2.75, 0.05, -0.35), fronts[1] + Vector3.DOWN * 0.1)
	# Each swings out toward a point in the room, then round under the bed,
	# spaced along it.
	for i in riders.size():
		var k: float = float(i) / (riders.size() - 1)
		_arc(riders[i], Vector3(lerpf(3.65, 3.25, k), 0.0, lerpf(-0.95, -0.55, fmod(k * 3.0, 1.0))),
			Vector3(lerpf(3.1, 1.9, k), 0.0, -1.8 + 0.08 * (i % 2)))
	_start()
	await _wait(0.4)
	for i in chest.drawers.size():
		var handle: Vector3 = fronts[i] - side * 0.15
		await _turn_to(handle, 0.3)
		_grab(chest.drawers[i], handle)
		await _reel(-0.38, 0.35)
		await _wait(0.15)
		_let_go()
	await _turn_to(bed_side, 0.8)
	await _wait(1.2)


## The wardrobe doors flung open one after the other, the six hiding inside
## bursting out toward you and peeling off either side.
func _clip_wardrobe() -> void:
	var wardrobe := _main.get_node("MainRoomProps/Wardrobe") as Node3D
	var handles: Array[Vector3] = []
	for door_name in ["DoorA", "DoorB"]:
		var door := wardrobe.get_node(door_name) as Node3D
		handles.append(door.to_global(Vector3(-0.03, 0.05, 0.36)))
	var middle: Vector3 = (handles[0] + handles[1]) * 0.5
	var out: Vector3 = -wardrobe.global_basis.x
	var across: Vector3 = wardrobe.global_basis.z
	_back_on(wardrobe)
	var floor_mid := Vector3(middle.x, 0.0, middle.z)
	# Six in a row along the floor inside, the two that live there among them.
	var inside: Array[Creature] = [_take("InWardrobe1"), _take("InWardrobe2")]
	for i in 4:
		inside.append(_spare())
	for i in inside.size():
		var along: float = -0.72 + 0.288 * i
		_hide_at(inside[i], wardrobe.to_global(Vector3(0.08, -0.964, along)))
	_crouch = 0.3
	await _frames(20)
	await _place(floor_mid + out * 1.9, middle + Vector3.DOWN * 0.3)
	for i in inside.size():
		var along: float = -0.72 + 0.288 * i
		var spread: float = signf(along) * (0.9 + absf(along) * 1.4)
		_arc(inside[i], floor_mid + out * (0.7 + 0.1 * (i % 2)) + across * along * 0.6,
			floor_mid + out * (1.2 + 0.25 * (i % 3)) + across * spread, true)
	_start()
	await _wait(0.4)
	for i in 2:
		var away: Vector3 = (handles[i] - middle).normalized()
		await _turn_to(handles[i], 0.25)
		_grab(wardrobe.get_node(["DoorA", "DoorB"][i]) as Prop, handles[i])
		# Pulled in toward us and a little to its side: the door swings open.
		_reel(-0.5, 0.4)
		await _turn_to(handles[i] + away * 0.35, 0.4)
		_let_go()
	await _turn_to(floor_mid + out * 0.7 + Vector3.UP * 0.4, 0.5)
	await _wait(1.2)


## The bookcase pulled over from the top: books everywhere, and the eight
## hiding behind them run for it.
func _clip_bookcase() -> void:
	var bookcase := _main.get_node("MainRoomProps/Bookcase") as Prop
	var out := Vector3.RIGHT  # it stands against the west wall
	var top: Vector3 = bookcase.global_position + Vector3.UP * 0.8 + out * 0.15
	var foot := Vector3(top.x, 0.0, top.z)
	var hiders: Array[Creature] = []
	for i in 4:
		hiders.append(_take("BehindBooks%d" % (i + 1)))
	# Four more behind the books on the other shelves.
	for spot in [Vector3(-4.96, 0.096, -0.02), Vector3(-4.96, 0.696, 0.419),
			Vector3(-4.96, 0.696, -0.02), Vector3(-4.96, 1.296, 0.419)]:
		var c: Creature = _spare()
		_hide_at(c, spot)
		hiders.append(c)
	# Off to the side of the play table, which stands right in front of it.
	await _place(foot + out * 1.5 + Vector3(0.0, 0.0, 1.3), top + Vector3.DOWN * 0.5)
	# They scatter out across the floor toward us.
	for i in hiders.size():
		var spread: float = -0.75 + 1.5 * float(i) / (hiders.size() - 1)
		_arc(hiders[i], foot + out * (0.8 + 0.15 * (i % 2)) + Vector3(0.0, 0.0, spread),
			foot + out * (1.7 + 0.3 * (i % 3)) + Vector3(0.0, 0.0, spread * 2.2 + 0.6), true)
	_start()
	await _wait(0.4)
	await _turn_to(top, 0.3)
	_grab(bookcase, top)
	# Tip it toward us, then yank it the rest of the way down.
	await _turn_to(top + out * 0.5 + Vector3.DOWN * 0.4, 0.35)
	await _turn_to(foot + out * 1.3 + Vector3.UP * 0.2, 0.2)
	await _throw()
	await _turn_to(foot + out * 1.0 + Vector3.UP * 0.1, 0.5)
	await _wait(1.6)


## A picture ripped off the wall and tossed aside; the two in the hole behind
## it drop out and run.
func _clip_picture() -> void:
	var picture := _main.get_node("MainRoomProps/PictureWest") as Prop
	var at: Vector3 = picture.global_position
	var out: Vector3 = picture.global_basis.z
	var floor_below := Vector3(at.x, 0.0, at.z)
	# The beanbag under the picture would hide the escape.
	var beanbag := _main.get_node("MainRoomProps/Beanbag") as Prop
	beanbag.global_position = Vector3(-2.9, beanbag.global_position.y, 2.0)
	beanbag.reset_physics_interpolation()
	# Side by side in the hole.
	var pair: Array[Creature] = [_take("BehindPicture"), _spare()]
	_hide_at(pair[0], Vector3(-5.21, 1.386, 1.44))
	_hide_at(pair[1], Vector3(-5.21, 1.386, 1.56))
	await _place(floor_below + out * 1.3, at)
	_arc(pair[0], floor_below + out * 0.45 + Vector3(0.0, 0.0, -0.1),
		floor_below + out * 1.1 + Vector3(0.0, 0.0, -0.8), true)
	_arc(pair[1], floor_below + out * 0.55 + Vector3(0.0, 0.0, 0.15),
		floor_below + out * 1.2 + Vector3(0.0, 0.0, 0.7), true)
	_start()
	await _wait(0.4)
	_grab(picture, at)
	await _reel(-0.4, 0.3)
	# Flung off to the open side, away from the bookcase.
	await _turn_to(at + out * 0.6 + Vector3(0.0, -0.2, 1.1), 0.3)
	await _throw()
	await _turn_to(at + Vector3.DOWN * 0.3, 0.35)
	await _turn_to(floor_below + out * 0.9 + Vector3(0.0, 0.1, -0.3), 0.8)
	await _wait(0.8)


## An upturned bin lifted: the three under it bolt, and the bin goes flying
## after them.
func _clip_bin() -> void:
	var bin := _main.get_node("MainRoomProps/Bin01") as Prop
	var at: Vector3 = bin.global_position
	var floor_at := Vector3(at.x, 0.0, at.z)
	var under: Array[Creature] = [_take("UnderBin01"), _spare(), _spare()]
	for i in under.size():
		var angle: float = TAU * i / under.size()
		_hide_at(under[i], floor_at + Vector3(cos(angle), 0.0, sin(angle)) * 0.07 + Vector3.UP * 0.054)
	_crouch = 0.3
	await _frames(20)
	await _place(floor_at + Vector3(-0.85, 0.0, -0.85), at)
	# They shoot out toward us, then swerve off across the floor, fanning out.
	var away_to: Vector3 = floor_at + Vector3(-1.6, 0.0, 0.15)
	for i in under.size():
		var fan := Vector3(0.25 * (i - 1), 0.0, -0.3 * (i - 1))
		_arc(under[i], floor_at + Vector3(-0.35, 0.0, -0.45) + fan * 0.5, away_to + fan, true)
	_start()
	await _wait(0.4)
	var top: Vector3 = at + Vector3.UP * 0.14
	_grab(bin, top)
	await _turn_to(at + Vector3(-0.1, 0.55, -0.1), 0.35)
	await _wait(0.2)
	# And the bin goes flying after them.
	await _turn_to(away_to + Vector3.UP * 0.4, 0.35)
	await _throw()
	await _turn_to(away_to + Vector3(0.3, 0.1, -0.2), 0.5)
	await _wait(1.0)


## A crowd of ten out on the bedroom floor; the desk chair goes flying into
## the middle of them and they scatter.
func _clip_chair() -> void:
	var gang_at := Vector3(2.8, 0.0, 0.0)
	_gang(gang_at, 10)
	var chair := _main.get_node("MainRoomProps/Chair") as Prop
	var seat: Vector3 = chair.global_position + Vector3.UP * 0.35
	await _place(Vector3(2.4, 0.05, 1.55), gang_at)
	_start()
	await _wait(0.5)
	await _turn_to(seat, 0.4)
	_grab(chair, seat)
	await _turn_to(seat + Vector3(0.3, 0.7, -0.3), 0.4)
	await _turn_to(gang_at + Vector3.UP * 0.55, 0.4)
	await _throw()
	await _turn_to(gang_at + Vector3.UP * 0.1, 0.4)
	await _wait(1.8)


## The same in the playroom with a bin, lobbed into a crowd of ten.
func _clip_bin_throw() -> void:
	var gang_at := Vector3(-2.0, 0.0, 1.45)
	_gang(gang_at, 10)
	var bin := _main.get_node("MainRoomProps/Bin09") as Prop
	var top: Vector3 = bin.global_position + Vector3.UP * 0.14
	await _place(Vector3(-0.5, 0.05, -0.3), gang_at)
	_start()
	await _wait(0.5)
	await _turn_to(top, 0.4)
	_grab(bin, top)
	await _turn_to(top + Vector3(0.0, 0.8, -0.2), 0.4)
	await _turn_to(gang_at + Vector3.UP * 0.6, 0.45)
	await _throw()
	await _turn_to(gang_at + Vector3.UP * 0.1, 0.4)
	await _wait(1.8)


## For a "changed one variable" post: a single marble pops out of a drawer
## and every bump splits it in two. You stand and back away as the room fills.
func _clip_mitosis() -> void:
	var chest := _main.get_node("MainRoomProps/ChestOfDrawers") as Drawers
	var out: Vector3 = chest.global_basis.z
	var side: Vector3 = chest.global_basis.x
	var front: Vector3 = chest.drawers[1].global_position + out * 0.23
	_take("InChestMiddle")
	_crouch = 0.4
	await _frames(20)
	await _place(Vector3(2.75, 0.05, -0.35), front + Vector3.DOWN * 0.1)
	_mitosis = true
	_start()
	await _wait(0.3)
	var handle: Vector3 = front - side * 0.15
	_grab(chest.drawers[1], handle)
	await _reel(-0.5, 0.35)
	await _wait(0.2)
	_let_go()
	await _wait(1.6)
	# Standing up and backing off as it gets out of hand.
	_creep = -0.25
	for i in 90:
		_crouch = lerpf(0.4, 0.0, smoothstep(0.0, 1.0, (i + 1) / 90.0))
		await get_tree().physics_frame
	await _turn_to(Vector3(3.0, 0.1, -1.0), 1.0)
	_creep = -0.12
	await _wait(4.0)
	print("MITOSIS %d marbles, %d splits, first %s at %s, drawer out %.2f" % [_cast.size(), _splits, _cast[0].state, _cast[0].global_position, chest.drawer_out(1)])


## Splits every marble that's out and has just bumped into something (a wall,
## furniture or another marble; not the floor): a new one rolls off the other
## way, and both wait a moment before they can split again.
func _divide() -> void:
	const CAP: int = 700
	const GAP: float = 0.55
	for c in _cast.duplicate():
		if not is_instance_valid(c) or c.state == Creature.State.HIDDEN:
			continue
		# Kept running: one that settled down would stop bumping.
		c.set("_state_left", 5.0)
		if _cast.size() >= CAP or _clock < float(_split_ready.get(c, 0.0)):
			continue
		var bump := Vector3.ZERO
		for i in c.get_slide_collision_count():
			var normal: Vector3 = c.get_slide_collision(i).get_normal()
			if normal.y < 0.5:
				bump = normal
		if bump == Vector3.ZERO:
			continue
		bump = Vector3(bump.x, 0.0, bump.z).normalized()
		var along: Vector3 = bump.cross(Vector3.UP)
		var twin := CreatureScene.instantiate() as Creature
		_main.get_node("MainRoomCreatures").add_child(twin)
		twin.global_position = c.global_position + along * 0.115 + bump * 0.02
		twin.reset_physics_interpolation()
		twin.call("_reveal")
		# Off in opposite directions, both away from what they hit.
		c.set("_flee_dir", (bump + along * 0.8).normalized())
		twin.set("_flee_dir", (bump - along * 0.8).normalized())
		_cast.append(twin)
		_split_ready[c] = _clock + GAP
		_split_ready[twin] = _clock + GAP
		_splits += 1
		# A squeak for each of the first few; then only now and then, or it's
		# just noise.
		if _splits < 24 or randf() < 0.08:
			twin.squeak(randf_range(0.9, 1.3))


# --- Directing ---------------------------------------------------------------

## Marks the first frame worth keeping.
func _start() -> void:
	_first_frame = Engine.get_frames_drawn()


## Stands the player at `feet` looking at `target`, and lets it settle.
func _place(feet: Vector3, target: Vector3) -> void:
	_rig_on = false
	_player.global_position = Vector3(feet.x, 0.05, feet.z)
	_player.reset_physics_interpolation()
	await _frames(5)
	_target = target
	_aim = target
	_view = _angles_to(target)
	_view_speed = Vector2.ZERO
	_sway.seed = randi()
	_sway.frequency = 0.01
	_rig_on = true
	await _frames(25)


## Eases the aim from where it was last sent to `target` over `seconds`; the
## view follows on its spring, so a held thing swings with it.
func _turn_to(target: Vector3, seconds: float) -> void:
	var from: Vector3 = _target
	var ticks: int = maxi(roundi(seconds * PACE * Engine.physics_ticks_per_second), 1)
	for i in ticks:
		_aim = from.lerp(target, smoothstep(0.0, 1.0, float(i + 1) / ticks))
		await get_tree().physics_frame
	_target = target


## Yaw and pitch that look from the eye at `target`; the yaw is kept within
## half a turn of the view's, so the spring never goes the long way round.
func _angles_to(target: Vector3) -> Vector2:
	var dir: Vector3 = (target - _head.global_position).normalized()
	var yaw: float = atan2(-dir.x, -dir.z)
	yaw = _view.x + wrapf(yaw - _view.x, -PI, PI)
	return Vector2(yaw, asin(dir.y))


## Grabs `prop` at `point`, as a click on it would.
func _grab(prop: Prop, point: Vector3) -> void:
	_beam._grab_armed = true
	_beam._grab(prop, point)


## Draws the held thing nearer (negative) or pushes it away, like the wheel.
func _reel(by: float, seconds: float) -> void:
	var from: float = _beam._hold_distance
	var ticks: int = maxi(roundi(seconds * PACE * Engine.physics_ticks_per_second), 1)
	for i in ticks:
		_beam._hold_distance = from + by * smoothstep(0.0, 1.0, float(i + 1) / ticks)
		await get_tree().physics_frame


func _let_go() -> void:
	_beam._grab_armed = false
	await get_tree().physics_frame


## Throws where the view points, so first lets the spring catch up with the
## aim (briefly: a player's throw comes at the end of the swing).
func _throw() -> void:
	for i in 12:
		if (_angles_to(_aim) - _view).length() < 0.03:
			break
		await get_tree().physics_frame
	if _beam.held != null:
		_beam._throw()
	_beam._grab_armed = false


## Once `c` is out and fleeing, steers it by hand: it keeps up its first
## dash (no turning away from you) but bends toward `via`, then on round to
## `to`, so it rolls a curve. `snap` points it straight at `via` first, for
## one that would otherwise bolt the wrong way. Runs alongside the clip.
func _arc(c: Creature, via: Vector3, to: Vector3, snap: bool = false) -> void:
	while c.state != Creature.State.FLEEING:
		await get_tree().physics_frame
	if snap:
		var start: Vector3 = via - c.global_position
		c.set("_flee_dir", Vector3(start.x, 0.0, start.z).normalized())
	var aim: Vector3 = via
	for i in 3 * Engine.physics_ticks_per_second:
		var flat := Vector3(c.global_position.x, 0.0, c.global_position.z)
		if aim == via and flat.distance_to(via) < 0.35:
			aim = to
		if aim == to and flat.distance_to(to) < 0.1:
			break
		var dir: Vector3 = c.get("_flee_dir")
		dir = dir.lerp((aim - flat).normalized(), 5.0 / Engine.physics_ticks_per_second)
		c.set("_flee_dir", Vector3(dir.x, 0.0, dir.z).normalized())
		c.set("_escape_left", 1.0)
		await get_tree().physics_frame
	c.set("_escape_left", 0.0)


## Gives the wardrobe a back, in its own wood. It really has none: it's the
## way through to the box room, which the clips keep as a surprise.
func _back_on(wardrobe: Node3D) -> void:
	const SIZE := Vector3(0.02, 2.04, 1.74)
	var wood: Material = null
	for m in wardrobe.find_children("*", "MeshInstance3D", true, false):
		wood = (m as MeshInstance3D).get_active_material(0)
		if wood != null:
			break
	var back := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = SIZE
	back.add_child(shape)
	var panel := MeshInstance3D.new()
	panel.mesh = BoxMesh.new()
	(panel.mesh as BoxMesh).size = SIZE
	panel.material_override = wood
	back.add_child(panel)
	wardrobe.add_child(back)
	# Just inside the side walls, behind the two hiding there.
	back.position = Vector3(0.28, 0.0, 0.0)


## `count` creatures out in the open round `at`, not touching, ready to
## scatter at the first knock.
func _gang(at: Vector3, count: int) -> void:
	var spots: Array[Vector3] = []
	while spots.size() < count:
		var angle: float = randf() * TAU
		var spot: Vector3 = at + Vector3(cos(angle), 0.0, sin(angle)) * sqrt(randf()) * 0.4
		if spots.all(func(o: Vector3) -> bool: return o.distance_to(spot) > 0.13):
			spots.append(spot)
	for spot in spots:
		var c: Creature = _spare()
		_hide_at(c, spot + Vector3.UP * 0.054)
		# Out in the open there's nothing over them: knocks are what count.
		c.set("_covers_recorded", true)


## The named creature, for this clip.
func _take(creature_name: String) -> Creature:
	var c := _main.get_node("MainRoomCreatures/" + creature_name) as Creature
	_pool.erase(c)
	_cast.append(c)
	return c


## Any creature not yet in the clip, borrowed from elsewhere in the house.
func _spare() -> Creature:
	var c: Creature = _pool.pop_front()
	_cast.append(c)
	return c


## Moves `c` to hide at `spot`: out of any drawer, and noting afresh what's
## covering it there, so lifting or opening that is what gives it away.
func _hide_at(c: Creature, spot: Vector3) -> void:
	c.set("_drawer", null)
	c.drawer_furniture = NodePath()
	c.global_position = spot
	c.reset_physics_interpolation()
	c.reveal_on_knock = true
	c.set("_covers", {})
	c.set("_covers_recorded", false)


## Slides a drawer rider `by` metres along the drawer, so two sit side by side.
func _shift_in_drawer(c: Creature, by: float) -> void:
	var spot: Transform3D = c.get("_drawer_spot")
	spot.origin.x += by
	c.set("_drawer_spot", spot)


## Where the view should look this tick: the scripted aim, leaning toward the
## middle of the marbles that are out (each pulling less the further it is
## from the aim). The lean eases in and out rather than snapping.
func _followed_aim(delta: float) -> Vector3:
	var sum := Vector3.ZERO
	var weight: float = 0.0
	for c in _cast:
		if not is_instance_valid(c) or c.state == Creature.State.HIDDEN:
			continue
		var w: float = exp(-c.global_position.distance_to(_aim) / FOLLOW_FALLOFF)
		sum += c.global_position * w
		weight += w
	var wanted: float = FOLLOW if weight > 0.0 and _beam.held == null else 0.0
	_follow_now = move_toward(_follow_now, wanted, delta * 1.2)
	if weight > 0.0:
		var mid: Vector3 = sum / weight + Vector3.UP * 0.05
		_group_mid = mid if _group_mid == Vector3.ZERO else _group_mid.lerp(mid, minf(delta * 4.0, 1.0))
	return _aim.lerp(_group_mid, _follow_now)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * PACE, true, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
