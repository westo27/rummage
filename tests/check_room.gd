extends Node
## Headless check for the room's new parts: the window holds things in, the
## props are glossy, the bedside lamp stands on its table, and the table's
## drawer opens when thrown. (How the room looks can only be judged in
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

	# --- The bedside lamp is its own object, standing on the table ---
	var lamp: Prop = _main.get_node("MainRoomProps/BedsideLamp")
	_check("the lamp stands on the bedside table",
		absf(lamp.global_position.y - 0.652) < 0.03 and lamp.global_basis.y.y > 0.99,
		"y = %.3f, upright %.2f" % [lamp.global_position.y, lamp.global_basis.y.y])

	# --- The bedside table's drawer: shut on a drop, open on a throw ---
	var beam: Beam = _main.get_node("Player/Head/Camera3D/Beam")
	var table: Prop = _main.get_node("MainRoomProps/BedsideTable")
	var drawer := table.get_node("DrawerFront") as Node3D
	var shut_z: float = drawer.position.z
	beam._grab_armed = true
	beam._grab(table, table.global_position)
	await _wait(0.3)
	beam._release()
	await _wait(0.5)
	_check("dropping the table leaves the drawer shut", is_equal_approx(drawer.position.z, shut_z),
		"moved %.3f m" % (drawer.position.z - shut_z))
	beam._grab(table, table.global_position)
	await _wait(0.3)
	beam._throw()
	await _wait(0.5)
	_check("throwing the table slides the drawer open", drawer.position.z - shut_z > 0.25,
		"moved %.3f m" % (drawer.position.z - shut_z))
	_check("the drawer's collision moves with it",
		is_equal_approx((table.get_node("DrawerFrontShape") as Node3D).position.z, drawer.position.z), "")
	beam._grab_armed = true
	beam._grab(table, table.global_position)
	await _wait(0.5)
	_check("picking it up again slides the drawer shut", is_equal_approx(drawer.position.z, shut_z),
		"moved %.3f m" % (drawer.position.z - shut_z))
	beam._release()

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
