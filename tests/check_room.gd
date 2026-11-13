extends Node
## Headless check for the room's new parts: the window holds things in, and
## keys 1-3 switch every prop between glossy, satin and matte. (How the room
## looks can only be judged in tests/shoot.tscn's pictures.) Not part of the
## game. Run: Godot --headless --path . res://tests/check_room.tscn

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var finish_before: Game.PropFinish = Game.prop_finish
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await _wait(1.0)

	# --- A ball flung at the window stays in the room ---
	var ball: Prop = _main.get_node("MainRoomProps/BallFloor")
	ball.global_position = Vector3(0.0, 1.75, -3.5)
	ball.linear_velocity = Vector3(0.0, 0.0, -15.0)  # straight at the window, hard
	ball.sleeping = false
	ball.reset_physics_interpolation()
	await _wait(1.5)
	_check("a ball thrown at the window bounces back into the room",
		ball.global_position.z > -5.0, "z = %.2f (wall at -5)" % ball.global_position.z)

	# --- Keys 1-3 switch the props' shine ---
	var crate_material := (_main.get_node("MainRoomProps/CrateA").get_child(0) as MeshInstance3D) \
		.material_override as StandardMaterial3D
	var expected: Array = [[0.12, true], [0.45, false], [1.0, false]]
	for i in 3:
		_press("finish_%d" % (i + 1))
		await _wait(0.1)
		_check("key %d: %s" % [i + 1, Game.PROP_FINISH_NAMES[i]],
			is_equal_approx(crate_material.roughness, expected[i][0])
			and crate_material.clearcoat_enabled == expected[i][1],
			"roughness %.2f, clearcoat %s" % [crate_material.roughness, crate_material.clearcoat_enabled])
	_check("a toast names the finish",
		(_main.get_node("HUD/ToastLabel") as Label).text.contains(Game.PROP_FINISH_NAMES[2]), "")

	Game.prop_finish = finish_before
	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
