extends Node
## Records the itch GIF's frames: lying by the bed, a ping lights up the
## creatures hiding under it, the beam catches one and it drops into the bag.
## Writes raw RGB frames to user://shots/gif_frames.raw; tools/make_gif.py
## turns them into press/lost_marbles.gif. Needs a real window.
## Run: Godot --path . --resolution 960x540 --fixed-fps 15 res://tests/shoot_gif.tscn

const PressLook = preload("res://tests/press_look.gd")
const OUT: String = "user://shots"
const SIZE := Vector2i(640, 360)
const SEED: int = 2
const UNDER_BED := Vector3(2.5, 0.1, -1.6)
const CATCH_SPOT := Vector3(2.45, 0.1, -1.3)
## Seconds of game time for each beat (--fixed-fps makes these exact).
const HOLD_BEFORE_PING: float = 0.8
const PING_GLOW: float = 1.6
const AFTER_CATCH: float = 2.2

var _main: Node
var _file: FileAccess
var _frames_written: int = 0
var _recording: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Press images show the chosen faces.
	DoodleFace.only = DoodleFace.PRESS_FACES
	# The game opens fullscreen; at the screen's size each frame costs more
	# and a non-16:9 screen would squash the GIF.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = SIZE * 3 / 2
	PressLook.use()
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(SEED)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	var player := _main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	_main.get_node("Tutorial").queue_free()

	var hud := _main.get_node("HUD") as Hud
	for i in 9:
		hud.add_to_bag(Creature.BODY_COLORS[i % Creature.BODY_COLORS.size()], DoodleFace.random())
	hud.set_caught(9, 25)
	# Lesson prompts and aim prompts both use this label: keep it out of shot.
	(hud.get_node("Hint") as CanvasItem).self_modulate.a = 0.0
	var creature: Creature = null
	for c in _main.get_node("MainRoomCreatures").get_children():
		if c is Creature and (c as Creature).body_color == Creature.BODY_COLORS[1]:
			creature = c as Creature
	creature.global_position = UNDER_BED
	creature.reset_physics_interpolation()

	# Lie down by the bed before aiming (mid-crouch the aim tilts at the floor).
	Input.action_press("prone")
	await _wait(1.5)
	player.global_position = Vector3(2.4, 0.05, 0.5)
	player.reset_physics_interpolation()
	await _wait(0.2)
	var dir: Vector3 = (Vector3(2.5, 0.55, -1.6) - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	await _wait(3.0)  # let the bag settle
	# Put the one to catch back just under the bed's edge, in the middle of shot.
	creature.global_position = CATCH_SPOT
	creature.reset_physics_interpolation()
	# Paused, so it waits there instead of scuttling off before the catch.
	creature.process_mode = Node.PROCESS_MODE_DISABLED

	_file = FileAccess.open("%s/gif_frames.raw" % OUT, FileAccess.WRITE)
	_recording = true
	await _wait(HOLD_BEFORE_PING)
	(_main.get_node("Ping") as Ping)._ping()
	await _wait(PING_GLOW)
	creature.process_mode = Node.PROCESS_MODE_INHERIT
	(_main.get_node("Player/Head/Camera3D/Beam") as Beam)._capture(creature)
	await _wait(AFTER_CATCH)
	_recording = false
	_file.close()
	Input.action_release("prone")
	print("RESULT %d frames %dx%d in %s" % [_frames_written, SIZE.x, SIZE.y, ProjectSettings.globalize_path(OUT)])
	get_tree().quit()


func _process(_delta: float) -> void:
	if not _recording:
		return
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)
	_file.store_buffer(image.get_data())
	_frames_written += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
