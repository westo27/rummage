extends Node
## Headless test: lidded boxes (shoe boxes, shape sorter) are hollow, their
## lids sit on and lift off, and a creature hidden inside pops out when the
## lid leaves a gap it fits through (tipping alone keeps it shut in).
## Run: Godot --headless --path . res://tests/check_boxes.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	var props: Node = _main.get_node("MainRoomProps")
	await _wait(1.5)

	var sorter := props.get_node("ShapeSorter") as LiddedBox
	var low := props.get_node("ShoeBoxLow") as LiddedBox
	var high := props.get_node("ShoeBoxHigh") as LiddedBox
	var in_sorter := _main.get_node("MainRoomCreatures/InShapeSorter") as Creature
	var in_shoe := _main.get_node("MainRoomCreatures/InShoeBox") as Creature

	# --- Settled: lids on, creatures inside and hidden ---
	for box: LiddedBox in [sorter, low, high]:
		_check("%s lid sits on" % box.name, box.lid_on(),
			"%.3f m off" % box.to_local(box.lid.global_position).distance_to(box._lid_seat))
	for pair: Array in [[in_sorter, sorter], [in_shoe, low]]:
		var creature: Creature = pair[0]
		var box: LiddedBox = pair[1]
		var local: Vector3 = box.to_local(creature.global_position)
		_check("%s is inside its box" % creature.name,
			absf(local.x) < 0.05 and absf(local.z) < 0.05 and local.y < 0.0, "local %s" % local)
		_check("%s is hidden" % creature.name, creature.state == Creature.State.HIDDEN, "state=%s" % creature.state)

	# --- Lift the shape sorter's lid off with the beam ---
	_player.global_position = Vector3(-0.55, 0.05, -0.6)
	_player.reset_physics_interpolation()
	var top: Vector3 = sorter.lid.global_position + Vector3(0.0, 0.01, 0.0)
	_aim_at(top)
	await _wait(0.1)
	_beam._grab_armed = true
	_beam._grab(sorter.lid, top)
	_check("the beam holds the lid, not the box", _beam.held == sorter.lid, "")
	var sorter_at: Vector3 = sorter.global_position
	for i in 30:
		_lift_to(top + Vector3(0.0, 0.02 * i, 0.0))
		await get_tree().physics_frame
	await _wait(0.3)
	_check("lid lifted off", not sorter.lid_on(), "")
	_check("the box stays on the floor", absf(sorter.global_position.y - sorter_at.y) < 0.02, "moved %s" % (sorter.global_position - sorter_at))
	_check("lifting the lid lets its creature out", in_sorter.state != Creature.State.HIDDEN,
		"state=%s" % in_sorter.state)
	_beam._release()
	_beam._grab_armed = false
	await _wait(2.0)
	var away: float = Vector2(in_sorter.global_position.x - sorter.global_position.x,
		in_sorter.global_position.z - sorter.global_position.z).length()
	_check("it got out of the box", away > 0.15, "%.2f m from the box" % away)

	# --- A bin: grab its lid by the handle and lift it off ---
	var bin := props.get_node("Bin01") as LiddedBox
	var in_bin := _main.get_node("MainRoomCreatures/UnderBin01") as Creature
	var bin_local: Vector3 = bin.to_local(in_bin.global_position)
	_check("bin is upright with its lid on", bin.lid_on() and bin.global_basis.y.dot(Vector3.UP) > 0.99, "")
	_check("bin creature hides inside it", in_bin.state == Creature.State.HIDDEN
		and absf(bin_local.x) < 0.05 and absf(bin_local.z) < 0.05 and bin_local.y < 0.0, "local %s" % bin_local)
	_player.global_position = bin.global_position + Vector3(0.0, -0.13, -1.2)
	_player.reset_physics_interpolation()
	var handle: Vector3 = (bin.lid.get_node("HandleBar") as Node3D).global_position
	_aim_at(handle)
	await _wait(0.1)
	_beam._grab_armed = true
	_beam._grab(bin.lid, handle)
	var bin_at: Vector3 = bin.global_position
	for i in 30:
		_lift_to(handle + Vector3(0.0, 0.02 * i, 0.0))
		await get_tree().physics_frame
	await _wait(0.3)
	_check("bin lid lifted off by its handle", not bin.lid_on(), "")
	_check("the bin stays on the floor", absf(bin.global_position.y - bin_at.y) < 0.02, "")
	_check("its creature pops out", in_bin.state != Creature.State.HIDDEN, "state=%s" % in_bin.state)
	_beam._release()
	_beam._grab_armed = false
	await _wait(2.0)
	var bin_away: float = Vector2(in_bin.global_position.x - bin.global_position.x,
		in_bin.global_position.z - bin.global_position.z).length()
	_check("it climbs out of the bin", bin_away > 0.25, "%.2f m from the bin" % bin_away)

	# --- Tip the lower shoe box over (lid still on): its creature gets out ---
	high.global_position += Vector3(0.0, 0.0, -0.8)
	high.lid.global_position += Vector3(0.0, 0.0, -0.8)
	await _wait(0.5)
	_check("shoe box creature still hidden with the lid on", in_shoe.state == Creature.State.HIDDEN,
		"state=%s" % in_shoe.state)
	# Tip it with the lid on (the lid tipped along with it, still seated).
	var lid_rel: Transform3D = low.global_transform.affine_inverse() * low.lid.global_transform
	low.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), low.global_position + Vector3(0, 0.1, 0))
	low.lid.global_transform = low.global_transform * lid_rel
	await get_tree().physics_frame
	_check("tipped with the lid on, its creature stays in", in_shoe.state == Creature.State.HIDDEN,
		"state=%s" % in_shoe.state)
	# A small jostle of the lid isn't a way out either.
	low.lid.global_position += low.global_basis.x * 0.04
	await get_tree().physics_frame
	_check("a jostled lid keeps it in", in_shoe.state == Creature.State.HIDDEN,
		"state=%s" % in_shoe.state)
	low.lid.global_position += Vector3(0.0, 0.0, -0.5)
	await _wait(0.2)
	_check("once the lid falls away, it gets out", in_shoe.state != Creature.State.HIDDEN,
		"state=%s" % in_shoe.state)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _camera_pos() -> Vector3:
	return (_main.get_node("Player/Head") as Node3D).global_position


func _aim_at(target: Vector3) -> void:
	var dir: Vector3 = (target - _camera_pos()).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	(_player.get_node("Head") as Node3D).rotation.x = asin(dir.y)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])


## Points the beam's hold point at `target`: straight up, as a careful
## player would lift, rather than swinging out in an arc.
func _lift_to(target: Vector3) -> void:
	_aim_at(target)
	_beam._hold_distance = (target - (_beam.get_parent() as Node3D).global_position).length()
