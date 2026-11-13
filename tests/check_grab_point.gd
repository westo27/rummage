extends Node
## Headless check: the beam holds the spot you grabbed, so where you grab
## changes how an object behaves. Not part of the game.
## Run: Godot --headless --path . res://tests/check_grab_point.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# --- A crate grabbed at the middle of its top lifts level ---
	await _load()
	var crate: Prop = _main.get_node("MainRoomProps/CrateA")  # 0.6 m box at (2.5, 0.3, -1.5)
	_player.global_position = Vector3(2.5, 0.05, -0.6)
	_aim_at(Vector3(2.5, 0.6, -1.5))
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("grabbed the crate on its top", _beam.held == crate and _beam._grab_local.y > 0.25,
		"held=%s local=%s" % [_beam.held, _beam._grab_local])
	var start_y: float = crate.global_position.y
	_aim_at(Vector3(2.5, 1.6, -1.5))
	await _wait(1.5)
	_check("lifted by its middle, it rises", crate.global_position.y > start_y + 0.4,
		"%.2f -> %.2f" % [start_y, crate.global_position.y])
	_check("lifted by its middle, it stays level", crate.global_basis.y.dot(Vector3.UP) > 0.9,
		"up·Y %.2f" % crate.global_basis.y.dot(Vector3.UP))
	_release("grab")

	# --- The same crate grabbed by a top corner hangs from that corner ---
	await _load()
	crate = _main.get_node("MainRoomProps/CrateA")
	_player.global_position = Vector3(2.5, 0.05, -0.6)
	_aim_at(Vector3(2.5 + 0.26, 0.6, -1.5 + 0.26))
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("grabbed the crate near a corner",
		_beam.held == crate and absf(_beam._grab_local.x) > 0.2 and absf(_beam._grab_local.z) > 0.2,
		"local=%s" % _beam._grab_local)
	_aim_at(Vector3(2.5, 1.6, -1.5))
	await _wait(2.5)
	_check("lifted by a corner, it hangs tilted", crate.global_basis.y.dot(Vector3.UP) < 0.8,
		"up·Y %.2f" % crate.global_basis.y.dot(Vector3.UP))
	_release("grab")

	# --- Grab the bookcase near its top and pull down: it topples ---
	await _load()
	var bookcase: Prop = _main.get_node("MainRoomProps/Bookcase")  # against the west wall
	_player.global_position = Vector3(-3.6, 0.05, -1.5)
	_aim_at(Vector3(-5.6, 1.78, -1.5))
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("grabbed the bookcase near its top", _beam.held == bookcase and _beam._grab_local.y > 0.6,
		"held=%s local=%s" % [_beam.held, _beam._grab_local])
	_check("the beam ends at the grab point, not the middle",
		_beam_end().distance_to(_beam.grab_point()) < 0.05,
		"%.3f m away" % _beam_end().distance_to(_beam.grab_point()))
	_aim_at(Vector3(-4.2, 0.0, -1.5))  # pull the top down towards the floor
	await _wait(2.5)
	_release("grab")
	await _wait(1.0)
	_check("pulled down by its top, the bookcase falls over",
		bookcase.global_basis.y.dot(Vector3.UP) < 0.5,
		"up·Y %.2f" % bookcase.global_basis.y.dot(Vector3.UP))

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## A fresh copy of the main scene each time, so each part starts clean.
func _load() -> void:
	if _main != null:
		_main.queue_free()
		await get_tree().process_frame
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	# Every prop liftable, so this test doesn't depend on the gate sums.
	_beam.lift_limit = 1000.0
	await _wait(1.0)


## The last point of the beam ribbon, where it meets the object.
func _beam_end() -> Vector3:
	var arrays: Array = (_beam._beam_mesh.mesh as ImmediateMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return (verts[verts.size() - 1] + verts[verts.size() - 2]) * 0.5


func _aim_at(target: Vector3) -> void:
	var head := _player.get_node("Head") as Node3D
	var dir: Vector3 = (target - head.global_position).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _release(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
