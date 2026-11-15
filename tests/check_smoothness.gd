extends Node
## Measures how evenly the camera and a held object move per rendered frame at
## 157 fps while walking. With 60 Hz physics and no interpolation, movement
## comes in steps (some frames move a lot, some not at all): that's the stutter.
## Not part of the game.
## Run: Godot --headless --path . res://tests/check_smoothness.tscn

const FPS: int = 157

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _camera: Camera3D
var _recording: bool = false
var _held: Prop = null
var _cam_last: Vector3
var _obj_last: Vector3
var _cam_steps: Array[float] = []
var _obj_steps: Array[float] = []


func _ready() -> void:
	Engine.max_fps = FPS
	# Run this node's _process after everything else's (higher = later), so we
	# read the camera after player.gd has placed it for this frame, which is
	# what the renderer sees.
	process_priority = 1000
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# An empty bedroom with one crate in it: room to strafe across.
	_main.get_node("MainRoomCreatures").free()
	_main.get_node("MainRoomProps").free()
	get_tree().root.add_child(_main)
	var crate := (load("res://tests/fixtures/crate.tscn") as PackedScene).instantiate() as Prop
	_main.add_child(crate)
	crate.global_position = Vector3(4.6, 0.3, -0.9)
	_player = _main.get_node("Player")
	_camera = _main.get_node("Player/Head/Camera3D")
	var beam: Beam = _main.get_node("Player/Head/Camera3D/Beam")
	await _wait_physics(0.5)

	# Grab a crate so we can watch a held object too.
	_player.global_position = Vector3(4.6, 0.05, 1.3)
	_player.rotation.y = 0.0
	(_player.get_node("Head") as Node3D).rotation.x = -0.45
	await _wait_physics(0.1)
	_press("grab")
	await _wait_physics(0.5)
	_held = beam.held
	_check("holding a crate for the test", _held == crate, "held=%s" % _held)

	# Walk sideways (strafe) while recording every rendered frame.
	Input.action_press("move_left")
	await _wait_physics(0.2)
	_cam_last = _rendered_camera_pos()
	_obj_last = _rendered_object_pos()
	_recording = true
	await _wait_physics(0.6)
	_recording = false
	Input.action_release("move_left")

	_report("camera", _cam_steps)
	_report("held crate", _obj_steps)
	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _process(_delta: float) -> void:
	if not _recording:
		return
	var c: Vector3 = _rendered_camera_pos()
	var o: Vector3 = _rendered_object_pos()
	_cam_steps.append(c.distance_to(_cam_last))
	_obj_steps.append(o.distance_to(_obj_last))
	_cam_last = c
	_obj_last = o


## Where the renderer draws the camera/object this frame. The camera has
## interpolation switched off and is placed by hand each frame (player.gd), so
## its plain global position is what's drawn. (get_global_transform_interpolated
## on a non-interpolated node returns the raw physics-tick position instead.)
func _rendered_camera_pos() -> Vector3:
	return _camera.global_position


func _rendered_object_pos() -> Vector3:
	return _held.get_global_transform_interpolated().origin


## Evenness = how many frames moved less than a third of the average step.
## Smooth motion: ~0%. Stepped 60 Hz motion at 157 fps: ~60% of frames frozen.
func _report(label: String, steps: Array[float]) -> void:
	var total: float = 0.0
	for s in steps:
		total += s
	var mean: float = total / steps.size()
	var frozen: int = 0
	var biggest: float = 0.0
	for s in steps:
		if s < mean / 3.0:
			frozen += 1
		biggest = maxf(biggest, s)
	var frozen_pct: float = 100.0 * frozen / steps.size()
	var ok: bool = frozen_pct < 10.0
	if not ok:
		_failures += 1
	print("%s  %s moves evenly: %d frames, %.0f%% frozen, mean step %.4f m, biggest %.4f m" % [
		"PASS" if ok else "FAIL", label, steps.size(), frozen_pct, mean, biggest])


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _wait_physics(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
