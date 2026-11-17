extends Node
## Records one gameplay clip for social posts: the real player and beam,
## driven by script through one lively moment, with the game's own sound.
## Run under Godot's movie mode (tools/make_clips.sh does this for every clip,
## wide and tall, and cuts them to MP4):
##   Godot --path . --write-movie <out.avi> --fixed-fps 60 --resolution 1920x1080
##     res://tests/record_clip.tscn -- <clip>
## Setting up happens on camera too, so it prints "CLIP <first> <last>": the
## frames worth keeping, for the cut.

const SEED: int = 4
const Drawers := preload("res://scripts/drawers.gd")
## Clips the script knows, in the order make_clips.sh records them.
const CLIPS: Array[String] = ["drawers", "wardrobe", "bookcase", "picture", "bin", "chair", "bin_throw"]

var _main: Node
var _player: CharacterBody3D
var _head: Node3D
var _beam: Beam
## Where the view is pointed, so moves can ease from it.
var _target: Vector3 = Vector3.ZERO
## Holds the player at this crouch (0 stand, 0.5 crouched); < 0 leaves it be.
var _crouch: float = -1.0
var _first_frame: int = 0


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _crouch >= 0.0:
		_player.set("crouch", _crouch)


func _run() -> void:
	DoodleFace.only = DoodleFace.PRESS_FACES
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
	# Late in a game: strong enough for anything that isn't furniture.
	_beam.lift_limit = 40.0
	await _frames(30)
	await call("_clip_" + clip)
	print("CLIP %d %d" % [_first_frame, Engine.get_frames_drawn()])
	get_tree().quit()


# --- Clips -------------------------------------------------------------------

## Crouched at the chest of drawers, yanking them open top to bottom: a
## marble pops out of each and rolls off in an arc, out into the room and
## round under the side of the bed.
func _clip_drawers() -> void:
	var chest := _main.get_node("MainRoomProps/ChestOfDrawers") as Drawers
	var out: Vector3 = chest.global_basis.z
	var side: Vector3 = chest.global_basis.x
	var fronts: Array[Vector3] = []
	for drawer in chest.drawers:
		fronts.append(drawer.global_position + out * 0.23)
	var bed := _main.get_node("MainRoomProps/Bed") as Node3D
	var bed_side: Vector3 = Vector3(bed.global_position.x + 0.5, 0.05, fronts[1].z + 0.35)
	# Out in the room, the chest and the long side of the bed both in view.
	_crouch = 0.4
	await _frames(20)
	await _place(Vector3(2.75, 0.05, -0.35), fronts[1] + Vector3.DOWN * 0.1)
	# Each swings out toward a point in the room, then round under the bed,
	# spaced along it.
	var routes := [["InChestTop", Vector3(3.55, 0, -0.75), Vector3(2.95, 0, -1.8)],
		["InChestMiddle", Vector3(3.35, 0, -0.6), Vector3(2.5, 0, -1.75)],
		["InChestBottom", Vector3(3.6, 0, -0.85), Vector3(2.05, 0, -1.8)]]
	for r: Array in routes:
		_arc(_main.get_node("MainRoomCreatures/" + r[0]) as Creature, r[1], r[2])
	_start()
	await _wait(0.4)
	for i in chest.drawers.size():
		var handle: Vector3 = fronts[i] - side * 0.15
		await _turn_to(handle, 0.3)
		_grab(chest.drawers[i], handle)
		await _reel(-0.38, 0.35)
		await _wait(0.15)
		_let_go()
	# Follow them under the bed.
	await _turn_to(bed_side, 0.8)
	await _wait(1.2)


## The wardrobe doors flung open one after the other, the two hiding inside
## bursting out toward you and peeling off either side.
func _clip_wardrobe() -> void:
	var wardrobe := _main.get_node("MainRoomProps/Wardrobe") as Node3D
	var handles: Array[Vector3] = []
	for door_name in ["DoorA", "DoorB"]:
		var door := wardrobe.get_node(door_name) as Node3D
		handles.append(door.to_global(Vector3(-0.03, 0.05, 0.36)))
	var middle: Vector3 = (handles[0] + handles[1]) * 0.5
	var out: Vector3 = -wardrobe.global_basis.x
	var floor_mid := Vector3(middle.x, 0.0, middle.z)
	_crouch = 0.3
	await _frames(20)
	await _place(floor_mid + out * 1.9, middle + Vector3.DOWN * 0.3)
	for i in 2:
		var away: Vector3 = (handles[i] - middle).normalized()
		_arc(_main.get_node("MainRoomCreatures/InWardrobe%d" % (i + 1)) as Creature,
			floor_mid + out * 0.8 + away * 0.15, floor_mid + out * 1.3 + away * 1.6, true)
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


## The bookcase pulled over from the top: books everywhere, and the four
## hiding behind them run for it.
func _clip_bookcase() -> void:
	var bookcase := _main.get_node("MainRoomProps/Bookcase") as Prop
	var out := Vector3.RIGHT  # it stands against the west wall
	var top: Vector3 = bookcase.global_position + Vector3.UP * 0.8 + out * 0.15
	var foot := Vector3(top.x, 0.0, top.z)
	# Off to the side of the play table, which stands right in front of it.
	await _place(foot + out * 1.5 + Vector3(0.0, 0.0, 1.3), top + Vector3.DOWN * 0.5)
	# The four behind the books scatter out across the floor toward us.
	for i in 4:
		var spread: float = -0.6 + 0.4 * i
		_arc(_main.get_node("MainRoomCreatures/BehindBooks%d" % (i + 1)) as Creature,
			foot + out * 0.9 + Vector3(0.0, 0.0, spread), foot + out * 1.9 + Vector3(0.0, 0.0, spread * 2.5 + 0.6), true)
	_start()
	await _wait(0.4)
	await _turn_to(top, 0.3)
	_grab(bookcase, top)
	# Tip it toward us, then yank it the rest of the way down.
	await _turn_to(top + out * 0.5 + Vector3.DOWN * 0.4, 0.35)
	await _turn_to(foot + out * 1.3 + Vector3.UP * 0.2, 0.2)
	_throw()
	await _turn_to(foot + out * 1.0 + Vector3.UP * 0.1, 0.5)
	await _wait(1.6)


## A picture ripped off the wall and tossed aside; the marble in the hole
## behind it drops out and runs.
func _clip_picture() -> void:
	var picture := _main.get_node("MainRoomProps/PictureWest") as Prop
	var at: Vector3 = picture.global_position
	var out: Vector3 = picture.global_basis.z
	var floor_below := Vector3(at.x, 0.0, at.z)
	# The beanbag under the picture would hide the escape.
	var beanbag := _main.get_node("MainRoomProps/Beanbag") as Prop
	beanbag.global_position = Vector3(-2.9, beanbag.global_position.y, 2.0)
	beanbag.reset_physics_interpolation()
	await _place(floor_below + out * 1.3, at)
	# The one in the hole drops out and rolls toward us.
	_arc(_main.get_node("MainRoomCreatures/BehindPicture") as Creature,
		floor_below + out * 0.45, floor_below + out * 1.1 + Vector3(0.0, 0.0, -0.7), true)
	_start()
	await _wait(0.4)
	_grab(picture, at)
	await _reel(-0.4, 0.3)
	# Flung off to the open side, away from the bookcase.
	await _turn_to(at + out * 0.6 + Vector3(0.0, -0.2, 1.1), 0.3)
	_throw()
	await _turn_to(at + Vector3.DOWN * 0.3, 0.35)
	await _turn_to(floor_below + out * 0.9 + Vector3(0.0, 0.1, -0.3), 0.8)
	await _wait(0.8)


## An upturned bin lifted: the marble under it bolts, and the bin goes
## flying after it.
func _clip_bin() -> void:
	var bin := _main.get_node("MainRoomProps/Bin01") as Prop
	var at: Vector3 = bin.global_position
	var floor_at := Vector3(at.x, 0.0, at.z)
	_crouch = 0.3
	await _frames(20)
	await _place(floor_at + Vector3(-0.85, 0.0, -0.85), at)
	# It shoots out toward us, then swerves off across the floor to the left.
	var away_to: Vector3 = floor_at + Vector3(-1.6, 0.0, 0.15)
	_arc(_main.get_node("MainRoomCreatures/UnderBin01") as Creature,
		floor_at + Vector3(-0.35, 0.0, -0.45), away_to, true)
	_start()
	await _wait(0.4)
	var top: Vector3 = at + Vector3.UP * 0.14
	_grab(bin, top)
	await _turn_to(at + Vector3(-0.1, 0.55, -0.1), 0.35)
	await _wait(0.2)
	# And the bin goes flying after it.
	await _turn_to(away_to + Vector3.UP * 0.4, 0.35)
	_throw()
	await _turn_to(away_to + Vector3(0.3, 0.1, -0.2), 0.5)
	await _wait(1.0)


## A gang of them out on the bedroom floor; the desk chair goes flying into
## the middle of them and they scatter.
func _clip_chair() -> void:
	var gang_at := Vector3(2.8, 0.0, 0.0)
	_gang(gang_at, ["UnderBed1", "UnderBed2", "UnderBed3", "UnderBed4", "InBedsideDrawer", "BehindPlayroomBag"])
	var chair := _main.get_node("MainRoomProps/Chair") as Prop
	var seat: Vector3 = chair.global_position + Vector3.UP * 0.35
	await _place(Vector3(2.4, 0.05, 1.55), gang_at)
	_start()
	await _wait(0.5)
	await _turn_to(seat, 0.4)
	_grab(chair, seat)
	await _turn_to(seat + Vector3(0.3, 0.7, -0.3), 0.4)
	await _turn_to(gang_at + Vector3.UP * 0.55, 0.4)
	_throw()
	await _turn_to(gang_at + Vector3.UP * 0.1, 0.4)
	await _wait(1.8)


## The same in the playroom with a bin, lobbed into a crowd round the rug.
func _clip_bin_throw() -> void:
	var gang_at := Vector3(-2.0, 0.0, 1.45)
	_gang(gang_at, ["UnderBed1", "UnderBed2", "UnderBed3", "UnderBed4", "InBedsideDrawer", "BehindPlayroomBag", "InToyBinA"])
	var bin := _main.get_node("MainRoomProps/Bin09") as Prop
	var top: Vector3 = bin.global_position + Vector3.UP * 0.14
	await _place(Vector3(-0.5, 0.05, -0.3), gang_at)
	_start()
	await _wait(0.5)
	await _turn_to(top, 0.4)
	_grab(bin, top)
	await _turn_to(top + Vector3(0.0, 0.8, -0.2), 0.4)
	await _turn_to(gang_at + Vector3.UP * 0.6, 0.45)
	_throw()
	await _turn_to(gang_at + Vector3.UP * 0.1, 0.4)
	await _wait(1.8)


# --- Directing ---------------------------------------------------------------

## Marks the first frame worth keeping.
func _start() -> void:
	_first_frame = Engine.get_frames_drawn()


## Stands the player at `feet` looking at `target`, and lets it settle.
func _place(feet: Vector3, target: Vector3) -> void:
	_player.global_position = Vector3(feet.x, 0.05, feet.z)
	_player.reset_physics_interpolation()
	await _frames(5)
	_target = target
	_point_at(target)
	await _frames(25)


## Eases the view from where it points now to `target` over `seconds`, a
## physics tick at a time like a mouse turn, so a held thing swings with it.
func _turn_to(target: Vector3, seconds: float) -> void:
	var from: Vector3 = _target
	var ticks: int = maxi(roundi(seconds * Engine.physics_ticks_per_second), 1)
	for i in ticks:
		var t: float = smoothstep(0.0, 1.0, float(i + 1) / ticks)
		_point_at(from.lerp(target, t))
		await get_tree().physics_frame
	_target = target


func _point_at(target: Vector3) -> void:
	var dir: Vector3 = (target - _head.global_position).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	_head.rotation.x = asin(dir.y)


## Grabs `prop` at `point`, as a click on it would.
func _grab(prop: Prop, point: Vector3) -> void:
	_beam._grab_armed = true
	_beam._grab(prop, point)


## Draws the held thing nearer (negative) or pushes it away, like the wheel.
func _reel(by: float, seconds: float) -> void:
	var from: float = _beam._hold_distance
	var ticks: int = maxi(roundi(seconds * Engine.physics_ticks_per_second), 1)
	for i in ticks:
		_beam._hold_distance = from + by * smoothstep(0.0, 1.0, float(i + 1) / ticks)
		await get_tree().physics_frame


func _let_go() -> void:
	_beam._grab_armed = false
	await get_tree().physics_frame


func _throw() -> void:
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


## Brings the named creatures out into the open round `at`, faces to the
## camera's side, ready to scatter at the first knock.
func _gang(at: Vector3, names: Array) -> void:
	for i in names.size():
		var c := _main.get_node("MainRoomCreatures/" + names[i]) as Creature
		var angle: float = TAU * i / names.size() + randf_range(-0.3, 0.3)
		var radius: float = 0.12 if i == 0 else randf_range(0.18, 0.32)
		c.global_position = at + Vector3(cos(angle), 0.0, sin(angle)) * radius + Vector3.UP * 0.054
		c.reset_physics_interpolation()
		c.reveal_on_knock = true
		c.set("_covers", {})
		c.set("_covers_recorded", true)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
