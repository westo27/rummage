extends Node
## Headless smoke test for stage 3 (creatures). Not part of the game.
## Run: Godot --headless --path . res://tests/check_stage3.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam
var _props: Node
var _creatures: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	# These checks grab 7 kg crates, heavier than the 4 kg start.
	_beam.lift_limit = 10.0
	_props = _main.get_node("MainRoomProps")
	_creatures = _main.get_node("MainRoomCreatures")

	# --- Setup: all hidden, nothing reveals by itself while the room settles ---
	_check("21 creatures in the main room", _creatures.get_child_count() == 21, "%d" % _creatures.get_child_count())
	await _wait(2.0)
	var hidden: int = _count_state(Creature.State.HIDDEN)
	_check("all stay hidden while the room settles", hidden == 21, "%d hidden" % hidden)
	var catchable: int = 0
	for c: Creature in _creatures.get_children():
		if c._pick_zone.collision_layer != 0:
			catchable += 1
	_check("hidden creatures can't be aimed at", catchable == 0, "%d catchable" % catchable)
	var no_covers: Array[String] = []
	for c: Creature in _creatures.get_children():
		if c._covers.is_empty():
			no_covers.append(c.name)
	_check("every hidden creature found a covering prop", no_covers.is_empty(), "missing: %s" % ", ".join(no_covers))

	# --- Tells: force one creature's tell timer ---
	var shy: Creature = _creatures.get_node("UnderBin01")
	shy._tell_left = 0.0
	# One tick only: the squeak is under 0.1 s long and could finish before a
	# slower check looks.
	await get_tree().physics_frame
	_check("a hidden creature's tell plays a squeak", shy._voice.playing, "")
	_check("giving a tell doesn't reveal it", shy.state == Creature.State.HIDDEN, "state=%s" % shy.state)
	await _wait(0.1)
	_check("its eyes glint as it gives itself away", shy._eyes.is_glinting(), "")

	# --- Lifting a crate reveals what's under it; it flees away from the player ---
	var crate: Prop = _props.get_node("CrateA")  # (2.5, 0.3, -1.5)
	var under: Creature = _creatures.get_node("UnderCrateA")
	_player.global_position = Vector3(2.5, 0.05, 0.5)
	_aim_at(crate.global_position)
	await _wait(0.1)
	var start_gap: float = _flat_distance(under.global_position, _player.global_position)
	_press("grab")
	await _wait(0.3)
	_check("grabbing the crate reveals the creature", under.state == Creature.State.FLEEING, "state=%s" % under.state)
	_check("found, its eyes go wide (or already squint cheekily)",
		under._eyes.mood in [CreatureEyes.Mood.WIDE, CreatureEyes.Mood.SQUINT], "mood=%s" % under._eyes.mood)
	_check("revealed creature can be aimed at", under._pick_zone.collision_layer == 8, "")
	_aim_at(Vector3(2.5, 2.0, -1.5))  # lift the crate up out of the way
	# Watch its "up" while it runs: rolling like a marble tips it right over.
	var most_tipped: float = 0.0
	var most_glanced: float = 0.0
	for i in 8:
		await _wait(0.1)
		most_tipped = maxf(most_tipped, under._visual.global_basis.y.angle_to(Vector3.UP))
		most_glanced = maxf(most_glanced, under._eyes.look_angle(0))
	_check("it glances back at you as it rolls", most_glanced > 0.3, "pupils turned up to %.2f rad" % most_glanced)
	_check("a fleeing creature rolls like a marble", most_tipped > 1.0, "tipped up to %.2f rad" % most_tipped)
	var gap: float = _flat_distance(under.global_position, _player.global_position)
	_check("fleeing creature runs away from the player", gap > start_gap + 1.0,
		"distance %.2f -> %.2f m" % [start_gap, gap])
	_check("fleeing creature stays on the floor", under.global_position.y < 0.3 and under.global_position.y > -0.05,
		"y=%.2f" % under.global_position.y)
	_release("grab")
	await _wait(0.5)

	# --- Capture: track the creature with the crosshair and click ---
	var lift_before: float = _beam.lift_limit
	# Walk after it: it has run further than the beam reaches.
	var toward: Vector3 = (_player.global_position - under.global_position) * Vector3(1, 0, 1)
	_player.global_position = Vector3(under.global_position.x, 0.05, under.global_position.z) \
		+ toward.normalized() * 2.0
	_player.reset_physics_interpolation()
	for i in 3:
		_aim_at(under.global_position)
		await get_tree().physics_frame
	_check("crosshair shows CREATURE state", _beam._state == Beam.AimState.CREATURE, "state=%s" % _beam._state)
	_aim_at(under.global_position)
	_press("grab")
	await _wait(0.5)
	_release("grab")
	_check("clicking catches the creature", not is_instance_valid(under), "")
	_check("catching raises lift by 4 kg", is_equal_approx(_beam.lift_limit, lift_before + 4.0),
		"%.1f -> %.1f" % [lift_before, _beam.lift_limit])
	var hud_text: String = (_main.get_node("HUD") as Hud).caught_text()
	_check("bag tag shows caught count", hud_text == "1 / 25", "'%s'" % hud_text)
	_check("capture didn't grab the crate behind it", _beam.held == null, "held=%s" % _beam.held)

	# --- Chaos reveals: a thrown book hitting a crate scares out its creature ---
	var crate_b: Prop = _props.get_node("CrateB")  # (-3.0, 0.3, 2.5)
	var under_b: Creature = _creatures.get_node("UnderCrateB")
	var book: Prop = _props.get_node("FloorPileB_4")  # top of pile at (-3.8, ~0.16, 3.8)
	book.global_position = Vector3(-3.0, 0.4, 3.6)
	book.linear_velocity = Vector3(0, 0, -8.0)
	await _wait(0.6)
	_check("thrown book knocking a crate reveals its creature", under_b.state != Creature.State.HIDDEN,
		"state=%s" % under_b.state)
	await _wait(1.0)
	var out_by: float = _flat_distance(under_b.global_position, crate_b.global_position)
	_check("creature escapes from under the knocked crate", out_by > 0.6,
		"%.2f m from crate centre (crate half-width 0.3)" % out_by)

	# --- Revealed creatures end up cowering somewhere, still inside the room ---
	await _wait(Game.tune.flee_time_max + Game.tune.seek_time + 0.5)
	_check("fled creature ends up cowering", under_b.state == Creature.State.COWERING, "state=%s" % under_b.state)
	var p: Vector3 = under_b.global_position
	_check("cowering creature is inside the room", absf(p.x) < 6.0 and absf(p.z) < 5.0 and p.y > -0.05,
		"pos=%s" % p)
	_check("cowering creature is still catchable", under_b._pick_zone.collision_layer == 8, "")

	# --- Walking up to a cowering creature makes it bolt again ---
	_player.global_position = p + _flat_dir(p) * 0.9
	await _wait(0.3)
	_check("approaching a cowering creature makes it bolt", under_b.state == Creature.State.FLEEING, "state=%s" % under_b.state)
	_player.global_position = Vector3(0, 0.05, 3.5)

	# --- Pulling a book off the shelf reveals the creature behind it ---
	var shelf_creature: Creature = _creatures.get_node("BehindBooks3")  # shelf at 0.64, first cluster
	var shelf_book: Prop = _props.get_node("ShelfBook12")  # middle book of that cluster
	shelf_book.global_position += Vector3(0.4, 0, 0)
	await _wait(0.3)
	_check("moving a shelf book reveals the creature behind it", shelf_creature.state != Creature.State.HIDDEN,
		"state=%s" % shelf_creature.state)
	await _wait(1.5)
	_check("shelf creature drops to the floor", shelf_creature.global_position.y < 0.3,
		"y=%.2f" % shelf_creature.global_position.y)

	# --- Bed creatures ignore knocks; only moving the bed reveals them ---
	var bed: Prop = _props.get_node("Bed")
	var bed_creature: Creature = _creatures.get_node("UnderBed2")
	var crate_f: Prop = _props.get_node("CrateF")
	crate_f.global_position = Vector3(-0.23, 0.35, -3.2)
	crate_f.linear_velocity = Vector3(0, 0, -7.0)
	await _wait(0.8)
	_check("a crate thrown at the bed doesn't reveal bed creatures", _count_under_bed_hidden() == 4,
		"%d of 4 still hidden; bed moved %.3f m" % [_count_under_bed_hidden(), bed.global_position.distance_to(Vector3(0, 0.302, -4.5))])

	# --- Aim priority: creature at the bed's edge, crosshair on the bed ---
	var edge: Creature = _creatures.get_node("UnderBin01")
	edge._reveal()
	await get_tree().physics_frame
	edge.state = Creature.State.COWERING  # hold it still for the test
	edge.velocity = Vector3.ZERO
	edge.global_position = Vector3(1.5, 0.09, -3.95)  # just in front of the bed's front face (z=-4.02)
	_player.global_position = Vector3(1.5, 0.05, -1.5)
	_aim_at(Vector3(1.5, 0.3, -4.06))  # a spot on the bed itself
	await _wait(0.05)
	_check("creature beside the bed wins the aim over the bed", _beam._state == Beam.AimState.CREATURE,
		"state=%s" % _beam._state)

	# --- Gate arithmetic from the tunables ---
	var start: float = Game.tune.start_lift_limit
	var per: float = Game.tune.lift_per_capture
	_check("bed (60 kg) needs 14 of 21 caught", start + per * 13 < 60.0 and start + per * 14 >= 60.0,
		"13 -> %.0f kg, 14 -> %.0f kg" % [start + per * 13, start + per * 14])
	_check("wardrobe (80 kg) needs 19 of 21 caught", start + per * 18 < 80.0 and start + per * 19 >= 80.0,
		"18 -> %.0f kg, 19 -> %.0f kg" % [start + per * 18, start + per * 19])

	# --- Cowering: a happy bounce, not a shiver, and it rolls upright to look at you ---
	var cower: Creature = _creatures.get_node("UnderBin09")
	_player.global_position = cower.global_position + Vector3(0, 0, 3.0)
	_player.reset_physics_interpolation()
	cower._visual.basis = Basis(Vector3.RIGHT, 2.0)  # as if it stopped mid-roll
	cower._start_cowering()
	var lowest: float = 1.0
	var highest: float = -1.0
	var sideways: float = 0.0
	for i in 60:
		await get_tree().physics_frame
		lowest = minf(lowest, cower._visual.position.y)
		highest = maxf(highest, cower._visual.position.y)
		sideways = maxf(sideways, Vector2(cower._visual.position.x, cower._visual.position.z).length())
	_check("a cowering creature bounces", highest - lowest > 0.02, "%.3f m" % (highest - lowest))
	_check("and doesn't shiver sideways", sideways < 0.001, "%.4f m" % sideways)
	_check("it settles upright", cower._visual.global_basis.y.angle_to(Vector3.UP) < 0.1, "")
	var to_player: Vector3 = (_player.global_position - cower.global_position) * Vector3(1, 0, 1)
	_check("facing the player", (-cower._visual.global_basis.z).angle_to(to_player) < 0.2, "")

	# --- Eyes: it blinks, winks while it waits, and is happy to be caught ---
	var least_open: float = 1.0
	var wink_seen: bool = false
	cower._wink_next = 0.0
	for i in int(6.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var l: float = cower._eyes.openness(0)
		var r: float = cower._eyes.openness(1)
		least_open = minf(least_open, minf(l, r))
		if absf(l - r) > 0.5:
			wink_seen = true
	_check("it blinks", least_open < 0.3, "least open %.2f" % least_open)
	_check("it winks (one eye at a time)", wink_seen, "")
	cower.capture(_player.global_position + Vector3.UP * 1.2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("caught, its eyes squeeze into happy arcs", cower._eyes.mood == CreatureEyes.Mood.HAPPY
		and cower._eyes._arcs[0].visible, "mood=%s" % cower._eyes.mood)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _count_state(s: Creature.State) -> int:
	var n: int = 0
	for c: Creature in _creatures.get_children():
		if c.state == s:
			n += 1
	return n


func _count_under_bed_hidden() -> int:
	var n: int = 0
	for i in 4:
		if (_creatures.get_node("UnderBed%d" % (i + 1)) as Creature).state == Creature.State.HIDDEN:
			n += 1
	return n


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Unit direction from p toward the room centre, flattened.
func _flat_dir(p: Vector3) -> Vector3:
	var d := Vector3(-p.x, 0, -p.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func _camera_pos() -> Vector3:
	# The head, not the camera: the camera is top_level and only catches up with
	# a teleported player on the next tick, while the head moves instantly.
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
