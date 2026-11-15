extends Node
## Scripted clip: pull open the chest of drawers, a creature pops out and
## bolts under the bed, which is too heavy to lift yet.
## Plan it headless (prints where the creature goes), then record it:
##   Godot --headless --path . --fixed-fps 60 res://tests/clip_drawer_bed.tscn
##   Godot --path . --resolution 1280x720 --write-movie <dir>/f.png res://tests/clip_drawer_bed.tscn
## Extra args after `--`: px=, pz= (where the player starts), drawer=, seed=.

var _main: Node
var _player: CharacterBody3D
var _head: Node3D
var _beam: Beam
var _creature: Creature
# The view is a spring chasing a target (yaw/pitch), like a hand on a mouse:
# it speeds up, slightly overshoots and settles, and lags a moving target.
var _yaw: float
var _pitch: float
var _yaw_v: float = 0.0
var _pitch_v: float = 0.0
## How snappy the hand is (rad/s): ~6 for a lazy look, ~14 for a flick.
var _omega: float = 6.0
var _damping: float = 0.8
var _time: float = 0.0
var _wobble_phase: Array[float] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := _args()
	seed(int(args.get("seed", "7")))
	var drawer: int = int(args.get("drawer", "2"))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main.get_node("Player")
	_head = _player.get_node("Head")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	_player.set_process_unhandled_input(false)  # no mouse look
	var chest := _main.get_node("MainRoomProps/ChestOfDrawers") as Prop
	var bed := _main.get_node("MainRoomProps/Bed") as Prop
	for c: Creature in get_tree().get_nodes_in_group("creatures"):
		if c.drawer_furniture == NodePath("../../MainRoomProps/ChestOfDrawers") and c.drawer_index == drawer:
			_creature = c

	for i in 4:
		_wobble_phase.append(randf() * TAU)
	_player.global_position = Vector3(float(args.get("px", "3.05")), 0.05, float(args.get("pz", "0.85")))
	_player.reset_physics_interpolation()
	var front: Vector3 = _drawer_front(chest, drawer)
	print("drawer front ", front, " out dir ", chest.drawers[drawer].global_basis.z)
	# Open looking at the window wall, glance about, then wander up to the chest.
	_set_view(Vector3(3.6, 1.35, -2.2))
	var window := func() -> Vector3: return Vector3(3.2, 1.4, -2.2)
	await _ticks(0.6, window)
	_omega = 5.0
	await _ticks(0.5, func() -> Vector3: return Vector3(4.2, 1.0, -2.2))
	_omega = 7.0
	_press("move_forward")
	await _ticks(0.18, func() -> Vector3: return _drawer_front(chest, drawer) + Vector3(0, 0.25, 0))
	_release("move_forward")
	await _ticks(0.5, func() -> Vector3: return _drawer_front(chest, drawer) + Vector3(0, 0.25, 0))
	_omega = 9.0
	await _ticks(0.55, func() -> Vector3: return _drawer_front(chest, drawer))
	print("player at ", _player.global_position)

	# Grab the drawer's front and pull it toward us.
	_press("grab")
	await _ticks(0.15, func() -> Vector3: return _drawer_front(chest, drawer))
	print("held: ", _beam.held)
	var popped_at: float = -1.0
	var t: float = 0.0
	while t < 1.2:
		_beam._hold_distance = maxf(_beam._hold_distance - 0.6 / 60.0, 0.6)
		await _ticks(1.0 / 60.0, func() -> Vector3: return _drawer_front(chest, drawer))
		t += 1.0 / 60.0
		if _creature.state != Creature.State.HIDDEN:
			popped_at = t
			break
	print("popped after %.2f s, drawer out %.2f" % [popped_at, chest.drawer_out(drawer)])
	await _ticks(0.15, func() -> Vector3: return _drawer_front(chest, drawer))
	_release("grab")

	# Staged: steer it in an arc round the foot of the bed and under its near
	# side, while we follow it with our eyes. Holding it in its
	# "escape" phase makes it run straight along _flee_dir, which we turn.
	var follow := func() -> Vector3: return _creature.global_position + Vector3(0, 0.05, 0)
	var path: Array[Vector3] = [Vector3(3.95, 0, -0.95), Vector3(3.3, 0, -0.72),
		Vector3(2.8, 0, -0.95), Vector3(2.62, 0, -1.62)]
	_omega = 8.0  # chasing it: a bit behind, then catching up
	var ticks: int = 0
	while not path.is_empty() and ticks < 240:
		var to: Vector3 = path[0] - _creature.global_position
		to.y = 0.0
		if to.length() < 0.15:
			path.pop_front()
			continue
		if ticks > 12:  # let it land from the pop first
			_creature._flee_dir = _creature._flee_dir.lerp(to.normalized(), 0.18).normalized()
		_creature._escape_left = 1.0
		await _ticks(1.0 / 60.0, follow)
		ticks += 1
	_creature._start_cowering()
	print("cowering at ", _creature.global_position, " under bed: ", _under_bed(bed, _creature.global_position))
	_omega = 6.0
	await _ticks(0.45, follow)
	# Crouch for a look under it.
	_press("crouch")
	await _ticks(1.5, follow)

	# Try to lift the bed: too heavy.
	var bed_spot := Vector3(_creature.global_position.x + 0.6, 0.33, -1.26)  # the side rail
	_omega = 9.0
	await _ticks(0.45, func() -> Vector3: return bed_spot)
	_press("grab")
	await _ticks(0.3, func() -> Vector3: return bed_spot)
	print("bed rejected: ", _beam._rejected, " player at ", _player.global_position)
	# Still holding: yank the view left and right in frustration. The beam stays
	# latched on the bed, so it whips about in arcs.
	_omega = 14.0
	_damping = 0.6
	var yanks: Array = [[0.9, 0.12, 0.34], [-0.75, 0.05, 0.3], [0.85, 0.15, 0.28],
		[-0.6, 0.0, 0.26], [0.7, 0.1, 0.24], [-0.35, 0.05, 0.3], [0.45, 0.1, 0.4]]
	for y: Array in yanks:
		var aim := bed_spot + Vector3(y[0], y[1], 0.0)
		await _ticks(y[2], func() -> Vector3: return aim)
	_release("grab")
	# Give up: drift back to the marble, slowly.
	_omega = 4.0
	_damping = 0.9
	await _ticks(0.5, func() -> Vector3: return bed_spot + Vector3(0.3, 0.05, 0))
	await _ticks(1.5, follow)
	print("RESULT under bed at the end: ", _under_bed(bed, _creature.global_position), " ", Creature.State.keys()[_creature.state])
	get_tree().quit()


func _drawer_front(chest: Prop, index: int) -> Vector3:
	var d: Prop = chest.drawers[index]
	return d.global_position + d.global_basis.z * 0.25


func _under_bed(bed: Prop, p: Vector3) -> bool:
	var local: Vector3 = bed.to_local(p)
	return absf(local.x) < 1.04 and absf(local.z) < 0.48 and p.y < 0.2


## Waits `seconds` of physics, with the view's spring chasing `target()`.
func _ticks(seconds: float, target: Callable) -> void:
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	for i in maxi(1, roundi(seconds * Engine.physics_ticks_per_second)):
		var want: Vector2 = _angles_to(target.call())
		# Damped spring: pulled toward the target, slowed by its own speed.
		var w2: float = _omega * _omega
		_yaw_v += (w2 * wrapf(want.x - _yaw, -PI, PI) - 2.0 * _damping * _omega * _yaw_v) * dt
		_pitch_v += (w2 * (want.y - _pitch) - 2.0 * _damping * _omega * _pitch_v) * dt
		_yaw += _yaw_v * dt
		_pitch += _pitch_v * dt
		_time += dt
		_apply_view()
		await get_tree().physics_frame


func _set_view(point: Vector3) -> void:
	var a: Vector2 = _angles_to(point)
	_yaw = a.x
	_pitch = a.y
	_apply_view()


## A hand never holds a mouse perfectly still: a slow, small wander.
func _apply_view() -> void:
	var p: Array[float] = _wobble_phase
	var wob_yaw: float = 0.004 * sin(_time * 1.3 + p[0]) + 0.002 * sin(_time * 3.1 + p[1])
	var wob_pitch: float = 0.003 * sin(_time * 1.7 + p[2]) + 0.0015 * sin(_time * 2.9 + p[3])
	_player.rotation.y = _yaw + wob_yaw
	_head.rotation.x = clampf(_pitch + wob_pitch, -1.4, 1.4)


func _angles_to(point: Vector3) -> Vector2:
	var dir: Vector3 = (point - _head.global_position).normalized()
	return Vector2(atan2(-dir.x, -dir.z), asin(dir.y))


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


func _args() -> Dictionary:
	var out := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out
