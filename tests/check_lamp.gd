extends Node
## Headless check for the swinging lamp: it hangs still, a thrown book sets
## it swinging with its light, it stays on its cord however it's hit, it
## settles back, and the beam can't grab it. Not part of the game.
## Run: Godot --headless --path . res://tests/check_lamp.tscn

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await _wait(1.5)
	var lamp: PendantLamp = _main.get_node("House/LampMain")
	var rest_length: float = lamp.hang_length()
	_check("the lamp hangs still to start with", lamp.swing() < 0.02, "%.3f m off centre" % lamp.swing())
	_check("it hangs on its cord, 0.73 m below the ceiling", absf(rest_length - 0.73) < 0.03,
		"%.3f m" % rest_length)

	# --- A book thrown at the shade ---
	var light_before: Vector3 = lamp.light_position()
	var book: Prop = _main.get_node("MainRoomProps/ShelfBook01")
	book.global_position = Vector3(0.0, 2.27, 1.5)
	book.linear_velocity = Vector3(0.0, 0.0, -12.0)
	book.angular_velocity = Vector3.ZERO
	book.sleeping = false
	book.reset_physics_interpolation()
	var biggest_swing: float = 0.0
	var light_moved: float = 0.0
	var worst_stretch: float = 0.0
	for i in 60:
		await get_tree().physics_frame
		biggest_swing = maxf(biggest_swing, lamp.swing())
		light_moved = maxf(light_moved, lamp.light_position().distance_to(light_before))
		worst_stretch = maxf(worst_stretch, absf(lamp.hang_length() - rest_length))
	_check("a thrown book sets it swinging", biggest_swing > 0.1, "swung %.2f m" % biggest_swing)
	_check("the light swings with it", light_moved > 0.1, "moved %.2f m" % light_moved)
	_check("it stays on its cord", worst_stretch < 0.03, "stretched %.3f m" % worst_stretch)

	# --- It settles back ---
	await _wait(8.0)
	_check("it settles back to hanging", lamp.swing() < 0.05, "%.3f m off centre" % lamp.swing())

	# --- The beam can't grab it ---
	var player: CharacterBody3D = _main.get_node("Player")
	var beam: Beam = _main.get_node("Player/Head/Camera3D/Beam")
	player.global_position = Vector3(0.0, 0.05, 2.5)
	var head := player.get_node("Head") as Node3D
	var dir: Vector3 = (lamp._lamp.global_position - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	await _wait(0.2)
	_check("the beam can't grab the lamp", beam._aimed == null and beam._state != Beam.AimState.CAN_GRAB,
		"aimed=%s state=%s" % [beam._aimed, beam._state])

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
