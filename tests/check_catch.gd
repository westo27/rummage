extends Node
## Headless check for the catch: the creature is sucked into the beam's hand,
## stretching toward it, with sparkles and the slurp, and ends
## as one ball in the bag. Not part of the game.
## Run: Godot --headless --path . res://tests/check_catch.tscn

var _failures: int = 0
var _main: Node
var _hud: Hud
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_hud = _main.get_node("HUD")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	await _wait(1.0)

	var creature := _main.get_node("MainRoomCreatures").get_child(0) as Creature
	var room: Node = creature.get_parent()
	_check_lock_on(creature)
	var balls_before: int = _hud._bag.marble_count()
	var hand: Vector3 = _beam._camera.to_global(Beam.BEAM_ORIGIN_LOCAL)
	_beam._capture(creature)  # as if clicked: plays the sound too
	await get_tree().physics_frame

	var sparkles: int = room.get_children().filter(func(n: Node) -> bool: return n is CatchSparkles).size()
	_check("sparkles burst where it was caught", sparkles > 0, "")
	_check("the catch slurps",
		_beam._capture_sound.playing and _beam._capture_sound.stream == Tones.slurp(), "")

	# Watch the animation until the creature is gone.
	var nearest_hand: float = INF
	var longest: float = 0.0
	var beam_shown: bool = false
	var beam_in_its_colour: bool = false
	var beam_reached_it: bool = false
	var color: Color = creature.body_color
	while is_instance_valid(creature):
		nearest_hand = minf(nearest_hand, creature._visual.global_position.distance_to(hand))
		longest = maxf(longest, creature._visual.scale.z)
		await get_tree().process_frame  # the beam is redrawn per frame
		if not is_instance_valid(creature):
			break
		if _beam._beam_mesh.visible:
			beam_shown = true
			beam_in_its_colour = _beam.beam_color().is_equal_approx(color)
			if _beam_end().distance_to(creature._visual.global_position) < 0.1:
				beam_reached_it = true
		await get_tree().physics_frame
	_check("it's pulled into the hand", nearest_hand < 0.2, "%.2f m from the hand" % nearest_hand)
	_check("it stretches on the way", longest > 1.8, "longest %.2f" % longest)
	_check("the beam shows while it's sucked in", beam_shown, "")
	_check("the beam is the creature's colour", beam_in_its_colour, "")
	_check("the beam reaches the creature", beam_reached_it, "")
	await get_tree().process_frame
	_check("the beam goes once it's caught", not _beam._beam_mesh.visible, "")
	await get_tree().physics_frame

	# Listen for the ball clacking as it lands in the bag.
	var clacked: bool = false
	for i in 120:
		await get_tree().physics_frame
		for marble in _hud._bag._marbles.get_children():
			if (marble as BagMarble)._voice.playing:
				clacked = true
	_check("the ball clacks like a marble as it lands in the bag", clacked, "")
	_check("one ball ends up in the bag", _hud._bag.marble_count() == balls_before + 1,
		"%d -> %d" % [balls_before, _hud._bag.marble_count()])
	_check("the sparkles clean themselves up",
		room.get_children().filter(func(n: Node) -> bool: return n is CatchSparkles).is_empty(), "")

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Aim lock-on: a creature a little off the crosshair is still the one aimed
## at; one well off it isn't.
func _check_lock_on(creature: Creature) -> void:
	var home: Vector3 = creature.global_position
	var was_catchable: bool = creature.is_catchable()
	creature._set_catchable(true)
	var cam: Camera3D = _beam._camera
	var forward: Vector3 = _beam._forward()
	var side: Vector3 = cam.global_basis.x
	for case: Array in [[0.0, true], [7.0, true], [20.0, false]]:
		var dir: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(case[0]))
		creature.global_position = cam.global_position + dir * 1.5
		var found: bool = _beam._find_aimed_creature() == creature
		_check("aimed %.0f° off: %s" % [case[0], "locks on" if case[1] else "doesn't"],
			found == case[1], "side %.2f" % side.dot(dir))
	creature.global_position = home
	creature._set_catchable(was_catchable)


## The last point of the beam ribbon.
func _beam_end() -> Vector3:
	var arrays: Array = (_beam._beam_mesh.mesh as ImmediateMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return (verts[verts.size() - 1] + verts[verts.size() - 2]) * 0.5


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
