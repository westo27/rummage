extends Node
## Renders the itch.io page screenshots, staged in the real house: eyes under
## the bed, the beam holding the teddy, the wardrobe open, the rug pulled up,
## two wide room shots and a catch with the bag. Needs a real window (no
## --headless). PNGs go to user://shots/itch_*.png.
## Run: Godot --path . --resolution 1920x1080 res://tests/shoot_itch.tscn

const OUT: String = "user://shots"
const SIZE := Vector2i(1920, 1080)

var _main: Node
var _player: CharacterBody3D
var _head: Node3D
var _cam: Camera3D
var _beam: Beam
var _hud: Hud
## Creatures held still for a shot: Creature -> {mood, wink, glint}. Their own
## physics (and AI) is off, so this script drives their eyes each frame.
var _posed: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _process(delta: float) -> void:
	for creature: Creature in _posed:
		if not is_instance_valid(creature):
			continue
		var pose: Dictionary = _posed[creature]
		var eyes := creature.get_node("Visual/Eyes") as CreatureEyes
		eyes.mood = pose.mood
		eyes._blink_left = 0.0
		eyes._next_blink = 99.0
		if pose.wink:
			# Held at the shut-most point of a wink, as in shoot_cover.
			eyes._wink_eye = 1
			eyes._wink_left = CreatureEyes.WINK_SECONDS * 0.5
		if pose.glint:
			eyes._white_glow = CreatureEyes.GLINT_ENERGY
		# Turn the face (-Z of its Visual) to the camera, level.
		var visual := creature.get_node("Visual") as Node3D
		var to_cam: Vector3 = _cam.global_position - visual.global_position
		to_cam.y = 0.0
		visual.global_basis = Basis.looking_at(to_cam.normalized(), Vector3.UP)
		eyes.look_target = _cam.global_position
		eyes.step(delta)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main.get_node("Player") as CharacterBody3D
	_head = _player.get_node("Head") as Node3D
	_cam = _head.get_node("Camera3D") as Camera3D
	_beam = _cam.get_node("Beam") as Beam
	_hud = _main.get_node("HUD") as Hud
	_player.set_process_unhandled_input(false)  # the real mouse can't swing the view
	# Skip the lesson and keep the HUD out of the pictures.
	(_main.get_node("Tutorial") as Tutorial).step = Tutorial.Step.DONE
	_hud.hide_hint()
	_hud.visible = false
	await _frames(30)

	# Wide shots first, before the others move things about.
	await _wide("itch_bedroom", Vector3(0.6, 0.05, 1.6), Vector3(3.4, 0.9, -1.9))
	await _wide("itch_playroom", Vector3(-0.6, 0.05, 1.7), Vector3(-4.0, 0.6, -1.4))
	await _under_bed()
	await _beam_teddy()
	await _catch()
	await _wardrobe()
	await _rug()  # last: it moves the table

	print("RESULT itch shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## Lying flat by the bed, four pairs of eyes looking back; one glints.
func _under_bed() -> void:
	var names := ["UnderBed1", "UnderBed2", "UnderBed3", "UnderBed4"]
	for i in names.size():
		var mood: CreatureEyes.Mood = CreatureEyes.Mood.SQUINT if i == 2 else CreatureEyes.Mood.NORMAL
		_pose(names[i], mood, false, i == 1)
	Input.action_press("crouch")
	_place(Vector3(2.55, 0.05, -0.45), Vector3(2.55, 0.1, -1.75))
	await _frames(40)
	_look(Vector3(2.55, 0.08, -1.75))
	await _frames(20)
	_shoot("itch_under_bed")
	Input.action_release("crouch")
	await _frames(30)
	_unpose()


## The beam holding the teddy up in the playroom.
func _beam_teddy() -> void:
	var teddy := _main.get_node("MainRoomProps/Teddy") as Prop
	_place(Vector3(-0.7, 0.05, 1.5), teddy.global_position)
	await _frames(3)
	_beam._grab_armed = true
	_beam._grab(teddy, teddy.global_position + Vector3(0.0, 0.1, 0.0))
	_look(Vector3(-3.0, 1.2, -1.2))  # up over the table, the room behind
	_beam._hold_distance = 1.5  # nearer, so the teddy reads
	await get_tree().create_timer(0.9).timeout
	_shoot("itch_beam_teddy")
	_beam._grab_armed = false
	_beam._release()
	await _frames(10)


## Both wardrobe doors swung wide; two creatures inside, one winking.
func _wardrobe() -> void:
	_pose("InWardrobe1", CreatureEyes.Mood.HAPPY, true, false)
	_pose("InWardrobe2", CreatureEyes.Mood.WIDE, false, false)
	var wardrobe := _main.get_node("MainRoomProps/Wardrobe")
	for door_name: String in ["DoorA", "DoorB"]:
		await _swing_open(wardrobe, door_name)
	await get_tree().create_timer(0.6).timeout
	_place(Vector3(1.7, 0.05, 0.7), Vector3(4.7, 0.5, 0.0))
	await _frames(20)
	_shoot("itch_wardrobe")
	_unpose()


## Spins a door outward until it's near fully open. The hinge's limit stops
## the wrong way, so if one way doesn't move it, the other does.
func _swing_open(wardrobe: Node, door_name: String) -> void:
	var door := wardrobe.get_node(door_name) as RigidBody3D
	var spin: float = 3.0
	for i in 180:
		if wardrobe.door_angle(door_name) > deg_to_rad(100.0):
			break
		if i == 15 and wardrobe.door_angle(door_name) < 0.05:
			spin = -spin
		door.sleeping = false
		door.angular_velocity = Vector3(0.0, spin, 0.0)
		await get_tree().physics_frame
	door.angular_velocity = Vector3.ZERO


## The table moved off and the rug dragged half back, lifted, the trapdoor showing.
func _rug() -> void:
	var table := _main.get_node("MainRoomProps/Table") as RigidBody3D
	# Slide the table (and what's on it) west, off the rug, and let it settle.
	for prop: Node in _main.get_node("MainRoomProps").get_children():
		if prop is RigidBody3D and prop != table and _over(prop as Node3D, table):
			(prop as Node3D).global_position.x -= 1.4
			(prop as RigidBody3D).reset_physics_interpolation()
	table.global_position.x -= 1.4
	table.reset_physics_interpolation()
	table.sleeping = false
	await get_tree().create_timer(2.5).timeout
	var rug: Node = _main.get_node("MainRoomProps/Rug")
	var edge := Vector3(-1.6, 0.006, -0.05)
	_place(Vector3(0.1, 0.05, -0.05), edge)
	await _frames(6)
	_beam._grab_armed = true
	_beam._grab(rug.grip, edge)
	for i in 45:  # back off, dragging it off the trapdoor
		_player.global_position.x += 0.03
		await get_tree().physics_frame
	_beam._grab_armed = false
	_beam._release()
	await get_tree().create_timer(1.5).timeout
	# From inside the playroom, lift the rug's near edge, the trapdoor beside it.
	var lift_at: Vector3 = rug.centre() + Vector3(-0.75, 0.0, 0.3)
	_place(Vector3(-0.9, 0.05, 1.7), lift_at)
	await _frames(6)
	_beam._grab_armed = true
	_beam._grab(rug.grip, lift_at)
	_look(lift_at + Vector3(0.0, 0.55, 0.0))
	await get_tree().create_timer(0.7).timeout
	_look(Vector3(-2.1, 0.3, -0.3))
	await get_tree().create_timer(0.12).timeout
	_shoot("itch_rug")
	_beam._grab_armed = false
	_beam._release()
	await get_tree().create_timer(1.0).timeout


## Whether `prop` sits on top of `table` (within its top, above it).
func _over(prop: Node3D, table: Node3D) -> bool:
	var d: Vector3 = prop.global_position - table.global_position
	return absf(d.x) < 0.7 and absf(d.z) < 0.5 and d.y > 0.2


func _wide(shot_name: String, at: Vector3, target: Vector3) -> void:
	_place(at, target)
	await _frames(20)
	_shoot(shot_name)


## A creature caught in front of the camera, sparkling, with the bag filling.
func _catch() -> void:
	_hud.visible = true
	_hud.hide_hint()
	for i in 14:
		_hud.add_to_bag(Creature.BODY_COLORS[i % Creature.BODY_COLORS.size()])
	_hud.set_caught(14, 25)
	_place(Vector3(3.0, 0.05, 1.5), Vector3(2.7, 0.5, -1.2))
	await get_tree().create_timer(4.0).timeout  # the bag's pile settles
	var creature := _main.get_node("MainRoomCreatures/BehindBeanbag") as Creature
	creature.global_position = Vector3(2.9, 0.1, 0.1)
	creature.reset_physics_interpolation()
	await _frames(3)
	_beam._capture(creature)
	await get_tree().create_timer(0.12).timeout
	_shoot("itch_catch")
	_hud.visible = false
	await get_tree().create_timer(1.0).timeout


## Holds a creature still with the given look (it won't flee when uncovered).
func _pose(creature_name: String, mood: CreatureEyes.Mood, wink: bool, glint: bool) -> void:
	var creature := _main.get_node("MainRoomCreatures/" + creature_name) as Creature
	creature.set_physics_process(false)
	_posed[creature] = {"mood": mood, "wink": wink, "glint": glint}


## Lets posed creatures go back to normal (they're hidden again, out of the way).
func _unpose() -> void:
	for creature: Creature in _posed:
		if is_instance_valid(creature):
			creature.set_physics_process(true)
	_posed.clear()


func _place(at: Vector3, target: Vector3) -> void:
	_player.global_position = at
	_player.reset_physics_interpolation()
	_look(target)


func _look(target: Vector3) -> void:
	var dir: Vector3 = (target - _head.global_position).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	_head.rotation.x = asin(dir.y)


func _shoot(shot_name: String) -> void:
	# macOS stops drawing a covered-up window, which would save a stale frame.
	RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != SIZE:
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/%s.png" % [OUT, shot_name])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
