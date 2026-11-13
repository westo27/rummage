extends Node
## Headless smoke test for stage 2 (grab, hold, throw, lift limit). Not part of the game.
## Run: Godot --headless --path . res://tests/check_stage2.tscn
## (A scene rather than --script, so the Game autoload is loaded first.)

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Stage 2 tests the beam on props alone. Creatures would (correctly) take aim
	# priority when one flees in front of a target, so take them out.
	_main.get_node("MainRoomCreatures").free()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	# These checks grab 7 kg crates, heavier than the 4 kg start.
	_beam.lift_limit = 10.0
	var props: Node = _main.get_node("MainRoomProps")

	# --- Everything settles where it was placed (no exploding stacks) ---
	var start_positions: Dictionary = {}
	for p: Prop in props.get_children():
		start_positions[p] = p.global_position
	await _wait(3.0)
	var worst: float = 0.0
	var worst_name: String = ""
	var asleep: int = 0
	for p: Prop in props.get_children():
		var moved: float = p.global_position.distance_to(start_positions[p])
		if moved > worst:
			worst = moved
			worst_name = p.name
		if p.sleeping:
			asleep += 1
	_check("all %d props settle in place" % start_positions.size(), worst < 0.05,
		"largest drift %.3f m (%s)" % [worst, worst_name])
	_check("props fall asleep when still", asleep > start_positions.size() * 0.8,
		"%d of %d asleep" % [asleep, start_positions.size()])

	# --- Grab a crate ---
	var crate: Prop = props.get_node("CrateA")  # at (2.5, 0.3, -1.5)
	_player.global_position = Vector3(2.5, 0.05, 1.0)
	_aim_at(crate.global_position)
	await _wait(0.1)
	_check("aiming at crate shows CAN_GRAB", _beam._state == Beam.AimState.CAN_GRAB, "state=%s" % _beam._state)
	_press("grab")
	await _wait(0.1)
	_check("grab picks up the crate", _beam.held == crate, "held=%s" % _beam.held)
	_check("held crate ignores the player", _player.get_collision_exceptions().has(crate), "")

	# Look up a bit and check it follows to the hold point.
	_aim_at(crate.global_position + Vector3(0, 1.0, 0))
	await _wait(0.8)
	# The spot that was grabbed is what's held at the hold point, not the
	# crate's centre.
	var hold_point: Vector3 = _camera_pos() + _forward() * _beam._hold_distance
	_check("held crate's grab point follows the hold point", _beam.grab_point().distance_to(hold_point) < 0.15,
		"off by %.3f m" % _beam.grab_point().distance_to(hold_point))
	await get_tree().process_frame
	var steady_bend: float = _arc_bend()
	_check("beam arc is nearly straight when object keeps up", steady_bend < 0.06, "bend %.3f m" % steady_bend)

	# --- Throw: speed = 16 / (1 + 7/6) = 7.38 m/s ---
	_aim_at(Vector3(2.5, 1.5, -4.0))
	await _wait(0.5)
	_press("throw")
	await _wait(0.02)
	var throw_speed: float = crate.linear_velocity.length()
	_check("crate throw speed about 7.4 m/s", absf(throw_speed - 7.38) < 0.6, "%.2f m/s" % throw_speed)
	await _wait(0.2)
	_check("still holding grab button does not re-grab thrown crate", _beam.held == null, "held=%s" % _beam.held)
	_release("grab")
	await _wait(1.5)
	_check("thrown crate stays inside the room", absf(crate.global_position.z) < 5.0 and crate.global_position.y > -0.1,
		"pos=%s" % crate.global_position)

	# --- Walls stop held objects: hold a crate far beyond the north wall ---
	var crate2: Prop = props.get_node("CrateF")  # at (3.8, 0.3, 0.8)
	_player.global_position = Vector3(3.8, 0.05, 2.8)
	_aim_at(crate2.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("grab second crate", _beam.held == crate2, "held=%s" % _beam.held)
	# Walk (not teleport, which would snap the beam) to x=4.8, z=-2 facing north.
	# x=4.8 is a clear lane between the box pyramid and the wardrobe.
	var from: Vector3 = _player.global_position
	var to := Vector3(4.8, 0.05, -2.0)
	_player.rotation.y = 0.0
	(_player.get_node("Head") as Node3D).rotation.x = -0.15
	for i in 80:
		_player.global_position = from.lerp(to, (i + 1) / 80.0)
		await get_tree().physics_frame
	await _wait(0.5)
	_check("crate still held after walking", _beam.held == crate2, "held=%s" % _beam.held)
	_beam._hold_distance = 4.5  # hold point now ~1.4 m beyond the north wall
	await _wait(1.5)
	var cz: float = crate2.global_position.z
	_check("held crate is pushed up to the wall but not through it", cz > -5.0 and cz < -4.6,
		"z=%.2f (wall face at -5, crate half-width 0.3)" % cz)
	_check("beam keeps hold while pressing into the wall", _beam.held == crate2, "held=%s" % _beam.held)
	_beam._hold_distance = 7.0  # now > 3 m (beam_break_distance) from the stuck crate
	await _wait(0.1)
	_check("beam lets go once the hold point is too far away", _beam.held == null, "held=%s" % _beam.held)
	_release("grab")
	await _wait(0.3)

	# --- Swing and release flings a book ---
	var book: Prop = props.get_node("FloorPileA_5")  # top of pile at (2.0, ~0.2, 1.5)
	_player.global_position = Vector3(2.0, 0.05, 3.3)
	_aim_at(book.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.4)
	_check("grab a book", _beam.held == book, "held=%s" % _beam.held)
	for i in 8:
		_player.rotation.y += 0.06
		await get_tree().physics_frame
	await get_tree().process_frame
	var swing_bend: float = _arc_bend()
	_check("beam arc bends while the object lags a swing", swing_bend > 0.1, "bend %.3f m" % swing_bend)
	_check("arc bows toward the aim direction", _arc_bows_toward_aim(), "")
	_release("grab")
	await get_tree().physics_frame
	_check("release keeps swing velocity", book.linear_velocity.length() > 3.0,
		"%.2f m/s" % book.linear_velocity.length())
	await _wait(1.0)

	# --- Too heavy: the bed (60 kg) against a 10 kg limit ---
	var bed: Prop = props.get_node("Bed")
	var bed_start: Vector3 = bed.global_position
	_player.global_position = Vector3(0, 0.05, -2.0)
	_aim_at(bed.global_position)
	await _wait(0.1)
	_check("aiming at bed shows TOO_HEAVY", _beam._state == Beam.AimState.TOO_HEAVY, "detail='%s'" % _beam._detail)
	_press("grab")
	await _wait(0.05)
	_check("bed is not grabbed", _beam.held == null, "held=%s" % _beam.held)
	_check("bed shudders", bed._shudder_left > 0.0, "")
	_check("red reject beam is shown", _beam._beam_mesh.visible, "")
	await _wait(0.8)
	_check("red beam stays latched while button held", _beam._beam_mesh.visible and _beam._rejected == bed, "")
	_check("bed keeps shuddering while button held", bed._shudder_left > 0.0, "")
	# Look away to a crate while still holding: must stay latched, not grab the crate.
	_aim_at(props.get_node("CrateD").global_position)
	await _wait(0.2)
	_check("looking away keeps the latch (no sweep-grab)", _beam.held == null and _beam._rejected == bed,
		"held=%s" % _beam.held)
	_check("crosshair stays TOO_HEAVY while latched", _beam._state == Beam.AimState.TOO_HEAVY, "state=%s" % _beam._state)
	_release("grab")
	await _wait(0.05)
	await get_tree().process_frame
	_check("releasing the button drops the red beam", not _beam._beam_mesh.visible and _beam._rejected == null, "")
	_aim_at(bed.global_position)
	await _wait(0.05)
	_check("shudder does not move the bed body", bed.global_position.distance_to(bed_start) < 0.01,
		"moved %.3f" % bed.global_position.distance_to(bed_start))

	# --- Raising the lift limit lets the bed be grabbed ---
	_beam.add_lift(55.0)
	await _wait(0.05)
	_press("grab")
	await _wait(0.1)
	_check("with 65 kg lift the bed can be grabbed", _beam.held == bed, "held=%s" % _beam.held)
	_release("grab")
	await _wait(0.5)

	# --- The wardrobe physically blocks the doorway to the side room ---
	_player.global_position = Vector3(4.5, 0.05, 0.0)
	_player.rotation.y = -PI / 2.0  # face +X
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_check("wardrobe blocks the doorway", _player.global_position.x < 5.4,
		"x=%.2f (wardrobe front at 5.38)" % _player.global_position.x)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _camera_pos() -> Vector3:
	# The head, not the camera: the camera is top_level and only catches up with
	# a teleported player on the next tick, while the head moves instantly.
	return (_main.get_node("Player/Head") as Node3D).global_position


func _forward() -> Vector3:
	return -(_main.get_node("Player/Head/Camera3D") as Camera3D).global_transform.basis.z


## Returns [start, middle, end] of the drawn beam ribbon (each = average of a vertex pair).
func _arc_points() -> Array[Vector3]:
	var mesh := _beam._beam_mesh.mesh as ImmediateMesh
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mid: int = (v.size() / 2) / 2 * 2  # first vertex of the middle pair
	return [(v[0] + v[1]) * 0.5, (v[mid] + v[mid + 1]) * 0.5, (v[v.size() - 2] + v[v.size() - 1]) * 0.5]


## How far the ribbon's middle sits from the straight line between its ends.
func _arc_bend() -> float:
	var p: Array[Vector3] = _arc_points()
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(p[1], p[0], p[2])
	return p[1].distance_to(closest)


## True if the curve's middle is closer to the aim ray than the straight chord's middle is.
func _arc_bows_toward_aim() -> bool:
	var p: Array[Vector3] = _arc_points()
	var eye: Vector3 = _camera_pos()
	var ray_end: Vector3 = eye + _forward() * 20.0
	var chord_mid: Vector3 = (p[0] + p[2]) * 0.5
	var d_curve: float = p[1].distance_to(Geometry3D.get_closest_point_to_segment(p[1], eye, ray_end))
	var d_chord: float = chord_mid.distance_to(Geometry3D.get_closest_point_to_segment(chord_mid, eye, ray_end))
	return d_curve < d_chord


## Turns the player body (yaw) and head (pitch) to look at a world point.
func _aim_at(target: Vector3) -> void:
	var dir: Vector3 = (target - _camera_pos()).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	(_player.get_node("Head") as Node3D).rotation.x = asin(dir.y)


## Sends a real input event through the input pipeline, as a key press would.
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
