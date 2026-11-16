extends Node
## Headless test: furniture is fixed and the beam ignores it; drawers and doors
## still work; creatures under the bed are found by crouching and looking; the
## wardrobe leads through to the box room.
## Run: Godot --headless --path . res://tests/check_furniture.tscn

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
	_beam.lift_limit = 100.0
	var props: Node = _main.get_node("MainRoomProps")
	await _wait(1.0)

	# --- Which props are furniture ---
	for name in ["Bed", "Wardrobe", "ChestOfDrawers", "Desk", "Bookcase", "BedsideTable"]:
		var prop: Prop = props.get_node(name)
		_check("%s is fixed furniture" % name, prop.is_furniture and prop.freeze, "%.0f kg" % prop.mass)
	for path in ["ToyBinA", "Chair", "Wardrobe/DoorA", "ChestOfDrawers/DrawerTop"]:
		var prop := props.get_node_or_null(path) as Prop
		_check("%s can still be grabbed" % path, prop != null and not prop.is_furniture, "")

	# --- The beam ignores the bed ---
	var bed: Prop = props.get_node("Bed")
	var bed_at: Vector3 = bed.global_position
	_player.global_position = Vector3(2.55, 0.05, 0.6)
	_aim_at(bed.global_position + Vector3(0.0, 0.2, 0.3))
	await _wait(0.1)
	_check("aiming at the bed offers nothing", _beam._state == Beam.AimState.IDLE, "state=%s" % _beam._state)
	_press("grab")
	await _wait(0.3)
	_check("clicking the bed grabs nothing", _beam.held == null and _beam._rejected == null, "")
	_release("grab")

	# --- Under the bed: standing over it you can't see them; crouch and look ---
	var under := _main.get_node("MainRoomCreatures/UnderBed2") as Creature
	_aim_at(under.global_position)
	await _wait(1.0)
	_check("standing, you can't see under the bed", under.state == Creature.State.HIDDEN, "state=%s" % under.state)
	_player.global_position = Vector3(2.3, 0.05, 0.3)
	Input.action_press("prone")
	await _wait(0.6)
	_aim_at(under.global_position)
	await _wait(0.5)
	_check("crouching and looking under the bed finds it", under.state != Creature.State.HIDDEN, "state=%s" % under.state)
	Input.action_release("prone")
	_check("the bed never moved", bed.global_position.distance_to(bed_at) < 0.001, "")

	# --- Through the wardrobe into the box room ---
	var wardrobe: Node = props.get_node("Wardrobe")
	for door_name in ["DoorA", "DoorB"]:
		var door: Prop = wardrobe.get_node(door_name)
		var side: float = -1.0 if door_name == "DoorA" else 1.0
		_player.global_position = Vector3(3.5, 0.05, 0.5 * side)
		_player.reset_physics_interpolation()
		var handle: Vector3 = door.global_position + Vector3(0, 0, -0.3 * side)
		_aim_at(handle)
		await _wait(0.1)
		_beam._grab_armed = true
		_beam._grab(door, handle)
		# Back away and out to the side, pulling the door's free edge after you.
		for i in 40:
			_player.global_position += Vector3(-0.03, 0.0, 0.02 * side)
			await get_tree().physics_frame
		await _wait(0.4)
		_beam._release()
		_beam._grab_armed = false
		await _wait(0.3)
	_check("both wardrobe doors open", wardrobe.door_angle("DoorA") > 0.9 and wardrobe.door_angle("DoorB") > 0.9,
		"%.2f, %.2f rad" % [wardrobe.door_angle("DoorA"), wardrobe.door_angle("DoorB")])
	_player.global_position = Vector3(3.9, 0.05, 0.0)
	_player.reset_physics_interpolation()
	_player.rotation.y = -PI / 2.0  # face +X
	(_player.get_node("Head") as Node3D).rotation.x = 0.0
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	_check("you walk through the wardrobe into the box room", _player.global_position.x > 5.5,
		"x=%.2f" % _player.global_position.x)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


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
