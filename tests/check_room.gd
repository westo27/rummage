extends Node
## Headless check for the room's new parts: the window holds things in, and
## the props are glossy. (How the room looks can only be judged in
## tests/shoot.tscn's pictures.) Not part of the game.
## Run: Godot --headless --path . res://tests/check_room.tscn

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
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

	# --- Props are glossy ---
	var crate_mesh := _main.get_node("MainRoomProps/CrateA").get_child(0) as MeshInstance3D
	var crate_material := crate_mesh.material_override as StandardMaterial3D
	_check("props have the glossy finish",
		is_equal_approx(crate_material.roughness, 0.12) and crate_material.clearcoat_enabled,
		"roughness %.2f, clearcoat %s" % [crate_material.roughness, crate_material.clearcoat_enabled])

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
