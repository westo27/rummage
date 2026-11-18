extends Node
## Renders the itch.io page screenshots: five staged moments of play with the
## HUD showing. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1920x1080 res://tests/shoot_itch.tscn
## In the game's default look (Soft filter); add `-- pixel` for the
## pixel-filter set, saved as itch_*_pixel.png.

const PressLook = preload("res://tests/press_look.gd")
const OUT: String = "user://shots"
const SEED: int = 2
const Drawers := preload("res://scripts/drawers.gd")
## Shot 3: where the under-bed marbles sit, and the eye lying flat facing them.
const UNDER_BED_ROW: Array[Vector3] = [
	Vector3(2.05, 0.056, -1.75), Vector3(2.4, 0.056, -1.55),
	Vector3(2.75, 0.056, -1.8), Vector3(3.1, 0.056, -1.6),
]
const PRONE_EYE := Vector3(2.6, 0.05, -0.55)
const PRONE_TARGET := Vector3(2.6, 0.08, -1.7)
## Shot 4: frames after the drawer marble starts its pop.
const DRAWER_POP_FRAMES: int = 20

var _main: Node
var _player: CharacterBody3D
var _head: Node3D
var _beam: Beam
## Hidden creatures that stare at you for the shot (normally they only
## glance now and then).
var _peekers: Array[Creature] = []
## Holds the player at this crouch (0 stand, 0.5 crouched); < 0 leaves it be.
var _crouch: float = -1.0
## Added to each file name ("_pixel" for the pixel-filter set).
var _suffix: String = ""


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	for c in _peekers:
		c._peek_left = 1.0
		c._peek_next = 1.0
	if _crouch >= 0.0:
		_player.set("crouch", _crouch)


func _run() -> void:
	# Press images show the chosen faces, in the default look unless asked for
	# the pixel look (`-- pixel`: filter at its finest).
	DoodleFace.only = DoodleFace.PRESS_FACES
	# The game opens fullscreen, which would save at the screen's size.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	var pixel: bool = "pixel" in OS.get_cmdline_user_args()
	_suffix = "_pixel" if pixel else ""
	PressLook.use(pixel)
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(SEED)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main.get_node("Player") as CharacterBody3D
	_head = _player.get_node("Head") as Node3D
	_beam = _main.get_node("Player/Head/Camera3D/Beam") as Beam
	_player.set_process_unhandled_input(false)
	# No lesson prompts over the shots.
	_main.get_node("Tutorial").queue_free()

	# A game partway through: some marbles in the bag.
	var hud := _main.get_node("HUD") as Hud
	for i in 9:
		hud.add_to_bag(Creature.BODY_COLORS[i % Creature.BODY_COLORS.size()], DoodleFace.random())
	hud.set_caught(9, 25)
	hud.set_time(204.0)
	await get_tree().create_timer(4.0).timeout
	hud.hide_hint()
	await get_tree().create_timer(1.0).timeout

	# 1. The bedroom by lamplight.
	await _stand(Vector3(4.2, 0.05, 1.3), Vector3(1.0, 0.7, -1.8))
	_shoot("itch_1_bedroom")

	# 2. The beam lifting the school bag in the playroom.
	var bag := _main.get_node("MainRoomProps/PlayroomBag") as Prop
	var at: Vector3 = bag.global_position
	await _stand(at + Vector3(-1.1, 0.0, 1.6), at + Vector3(0.0, 0.3, 0.0))
	_beam._grab_armed = true
	_beam._grab(bag, bag.global_position + Vector3(0.0, 0.1, 0.0))
	_look(at + Vector3(0.0, 0.9, 0.0))
	await get_tree().create_timer(0.9).timeout
	_shoot("itch_2_beam")
	if _beam.held != null:
		_beam._release()
	_beam._grab_armed = false
	await get_tree().create_timer(0.8).timeout

	# 3. Lying flat by the bed: the marbles hiding under it peer back at you.
	var under_bed: Array[Creature] = []
	for c in _main.get_node("MainRoomCreatures").get_children():
		if c is Creature and c.name.begins_with("UnderBed"):
			under_bed.append(c as Creature)
	for i in under_bed.size():
		var c: Creature = under_bed[i]
		c.reveal_when_spotted = false
		c.global_position = UNDER_BED_ROW[i]
		c.reset_physics_interpolation()
	_peekers = under_bed
	var startle: float = Game.tune.startle_distance
	Game.tune.startle_distance = 0.0
	# Get right down first: aiming mid-crouch would tilt the view at the carpet.
	Input.action_press("prone")
	await _frames(60)
	await _stand(PRONE_EYE, PRONE_TARGET, 40)
	# Hidden ones keep whatever way they were facing; turn the faces to us.
	var cam := get_viewport().get_camera_3d()
	for c in under_bed:
		var visual := c.get_node("Visual") as Node3D
		visual.basis = Basis()
		visual.look_at(cam.global_position, Vector3.UP)
		visual.basis = visual.basis * Basis(Vector3.UP, randf_range(-0.25, 0.25)) \
			* Basis(Vector3.BACK, randf_range(-0.3, 0.3))
		c.reset_physics_interpolation()
	await _frames(4)
	_shoot("itch_3_under_bed")
	_peekers = []
	Input.action_release("prone")
	Game.tune.startle_distance = startle
	await _frames(30)

	# 4. Pulling open a drawer: the marble hiding in it pops out.
	var chest := _main.get_node("MainRoomProps/ChestOfDrawers") as Drawers
	var drawer: Prop = chest.drawers[0]
	var out_dir: Vector3 = chest.global_basis.z
	var front: Vector3 = drawer.global_position + out_dir * 0.23
	_crouch = 0.5
	await _frames(20)
	await _stand(front + out_dir * 1.35 + Vector3(0.0, 0.0, 0.55), front + Vector3(0.0, 0.08, 0.0))
	# Held off-centre, so the beam's glow isn't right on the marble.
	var handle: Vector3 = front - chest.global_basis.x * 0.28
	_beam._grab_armed = true
	_beam._grab(drawer, handle)
	while chest.drawer_out(0) < Creature.DRAWER_REVEAL_OUT:
		_beam._hold_distance -= 0.01
		await get_tree().physics_frame
	await _frames(DRAWER_POP_FRAMES)
	_shoot("itch_4_drawer")
	_beam._release()
	_beam._grab_armed = false
	_crouch = -1.0
	await get_tree().create_timer(1.0).timeout

	# 5. The playroom by lamplight.
	await _stand(Vector3(-0.6, 0.05, -1.6), Vector3(-4.5, 0.4, 1.4))
	_shoot("itch_5_playroom")

	print("RESULT itch shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _stand(eye: Vector3, target: Vector3, settle: int = 25) -> void:
	_player.global_position = eye
	_player.reset_physics_interpolation()
	await _frames(5)
	_look(target)
	await _frames(settle)


func _shoot(shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [OUT, shot_name, _suffix])


func _look(target: Vector3) -> void:
	var dir: Vector3 = (target - _head.global_position).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	_head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
