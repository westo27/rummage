extends Node
## Headless test: furniture (over Game.tune.max_lift_mass) is dragged and
## tipped by the beam, never lifted clear of the floor or thrown. Light
## things still lift.
## Run: Godot --headless --path . res://tests/check_drag.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_main.get_node("MainRoomCreatures").free()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	_beam.lift_limit = 100.0
	var props: Node = _main.get_node("MainRoomProps")
	await _wait(1.0)

	# --- A crate pulled upward tips on its far edge but never leaves the floor ---
	var crate: Prop = props.get_node("CrateA")
	await _place(crate, Vector3(3.0, 0.3, -0.75))
	_player.global_position = Vector3(3.0, 0.05, 1.45)
	_aim_at(crate.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("the crate can be grabbed", _beam.held == crate, "held=%s" % _beam.held)
	_check("the crate is drag-only", _beam.is_drag_only(crate), "%.1f kg" % crate.mass)
	_aim_at(crate.global_position + Vector3(0.0, 1.5, 0.0))
	var lowest_ever: float = -INF
	for i in 90:
		await get_tree().physics_frame
		lowest_ever = maxf(lowest_ever, _lowest_point(crate))
	_check("pulled up, it never comes clear of the floor", lowest_ever < 0.04, "lowest corner rose to %.3f m" % lowest_ever)
	_release("grab")
	await _wait(1.0)

	# --- Grabbed by its top edge and pulled toward you, it topples ---
	await _place(crate, Vector3(3.0, 0.3, -0.75))
	_aim_at(Vector3(3.0, 0.57, -0.5))
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_aim_at(Vector3(3.0, 0.0, 0.3))
	await _wait(1.5)
	var tilt: float = rad_to_deg(crate.global_basis.y.angle_to(Vector3.UP))
	_check("pulled by its top edge, it topples", tilt > 45.0, "tilt %.0f°" % tilt)
	_release("grab")
	await _wait(0.5)
	_aim_at(crate.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)

	# --- Dragging it along the floor works ---
	_aim_at(crate.global_position)
	await _wait(0.6)
	var before: Vector3 = crate.global_position
	_aim_at(crate.global_position + Vector3(1.2, 0.0, 0.0))
	await _wait(1.0)
	var slid: float = Vector2(crate.global_position.x - before.x, crate.global_position.z - before.z).length()
	_check("it drags across the floor", slid > 0.3, "slid %.2f m" % slid)

	# --- Throwing furniture just lets go ---
	_press("throw")
	await _wait(0.05)
	_check("throw lets go of it", _beam.held == null, "held=%s" % _beam.held)
	_check("and doesn't fling it", crate.linear_velocity.length() < 1.5, "%.2f m/s" % crate.linear_velocity.length())
	_release("grab")
	await _wait(0.5)

	# --- A book still lifts ---
	var book: Prop = props.get_node("FloorPileA_5")
	await _place(book, Vector3(3.0, 0.1, -0.5))
	_aim_at(book.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("a book is not drag-only", not _beam.is_drag_only(book), "%.2f kg" % book.mass)
	_aim_at(book.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.8)
	_check("a book lifts clear", _lowest_point(book) > 0.3, "lowest %.2f m" % _lowest_point(book))
	_release("grab")
	await _wait(0.5)

	# --- The bed tips up by its near edge (the gate: creatures hide under it) ---
	var bed: Prop = props.get_node("Bed")
	_player.global_position = Vector3(2.55, 0.05, 0.6)
	var edge: Vector3 = _edge_toward(bed, _player.global_position)
	_aim_at(edge)
	await _wait(0.1)
	_press("grab")
	await _wait(0.1)
	_check("the bed can be grabbed", _beam.held == bed, "held=%s" % _beam.held)
	_aim_at(edge + Vector3(0.0, 1.5, 0.0))
	var bed_lowest: float = -INF
	for i in 120:
		await get_tree().physics_frame
		bed_lowest = maxf(bed_lowest, _lowest_point(bed))
	var bed_tilt: float = rad_to_deg(bed.global_basis.y.angle_to(Vector3.UP))
	_check("pulled up by its near edge, the bed tips up", bed_tilt > 10.0, "tilt %.0f°" % bed_tilt)
	_check("but never leaves the floor", bed_lowest < 0.04, "lowest corner rose to %.3f m" % bed_lowest)
	_release("grab")

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## The lowest corner of the prop's box collision shapes, in world space.
func _lowest_point(prop: Prop) -> float:
	var lowest: float = INF
	for shape_node in prop.find_children("*", "CollisionShape3D", false, false):
		var box := (shape_node as CollisionShape3D).shape as BoxShape3D
		if box == null:
			continue
		var h: Vector3 = box.size * 0.5
		for corner in 8:
			var local := Vector3(h.x * (1 if corner & 1 else -1), h.y * (1 if corner & 2 else -1), h.z * (1 if corner & 4 else -1))
			lowest = minf(lowest, ((shape_node as Node3D).global_transform * local).y)
	return lowest


## The top of the prop's side facing `from`, a little in from the edge, found
## by casting a ray straight down onto it.
func _edge_toward(prop: Prop, from: Vector3) -> Vector3:
	var to_from := Vector3(from.x - prop.global_position.x, 0.0, from.z - prop.global_position.z)
	var space := get_viewport().world_3d.direct_space_state
	var best := Vector3.ZERO
	for step in 40:
		var spot: Vector3 = prop.global_position + to_from.normalized() * step * 0.05
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot - Vector3.UP)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or hit.collider != prop:
			break
		best = hit.position
	return best


func _place(prop: Prop, at: Vector3) -> void:
	prop.global_position = at
	prop.global_basis = Basis.IDENTITY
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.sleeping = false
	await _wait(0.4)


func _camera_pos() -> Vector3:
	return (_main.get_node("Player/Head") as Node3D).global_position


func _aim_at(target: Vector3) -> void:
	var dir: Vector3 = (target - _camera_pos()).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	(_player.get_node("Head") as Node3D).rotation.x = asin(dir.y)


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
