extends Node
## Headless check for the catch: each of the three styles (switched with the
## 1/2/3 keys) plays its own animation and ends with a ball in the bag, with
## sparkles, the slurp and the tag hop every time. Not part of the game.
## Run: Godot --headless --path . res://tests/check_catch.tscn

var _failures: int = 0
var _main: Node
var _hud: Hud
var _beam: Beam


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var style_before: Game.CatchStyle = Game.catch_style
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_hud = _main.get_node("HUD")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	await _wait(1.0)

	var creatures: Array = _main.get_node("MainRoomCreatures").get_children()
	for style in 3:
		_press("catch_style_%d" % (style + 1))
		await _wait(0.1)
		var name: String = Game.CATCH_STYLE_NAMES[style]
		_check("key %d picks '%s'" % [style + 1, name], Game.catch_style == style,
			"style %d" % Game.catch_style)
		_check("a toast names the style", (_main.get_node("HUD/ToastLabel") as Label).text.contains(name),
			"'%s'" % (_main.get_node("HUD/ToastLabel") as Label).text)
		await _catch_one(creatures[style] as Creature, name)

	Game.catch_style = style_before
	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _catch_one(creature: Creature, style_name: String) -> void:
	var balls_before: int = _hud._bag.marble_count()
	var hand: Vector3 = _beam._camera.to_global(Beam.BEAM_ORIGIN_LOCAL)
	var room: Node = creature.get_parent()
	_beam._capture(creature)  # as if clicked: plays the sound too
	await get_tree().physics_frame

	var sparkles: int = 0
	for child in room.get_children():
		if child is CatchSparkles:
			sparkles += 1
	_check("[%s] sparkles burst where it was caught" % style_name, sparkles > 0, "")
	_check("[%s] the catch slurps" % style_name,
		_beam._capture_sound.playing and _beam._capture_sound.stream == Tones.slurp(), "")

	# Watch the animation until the creature is gone.
	var biggest: float = 0.0
	var longest: float = 0.0
	var nearest_hand: float = INF
	var flew: bool = false
	while is_instance_valid(creature):
		biggest = maxf(biggest, creature._visual.scale.x)
		longest = maxf(longest, creature._visual.scale.z)
		nearest_hand = minf(nearest_hand, creature._visual.global_position.distance_to(hand))
		await get_tree().physics_frame
	# The flying ball (if any) appears right as the creature goes.
	for i in 6:
		flew = flew or _hud.get_node_or_null("FlyingBall") != null
		await get_tree().physics_frame
	_check("[%s] the tag hops" % style_name, _hud._bag._tag_hop > 0.0, "%.2f" % _hud._bag._tag_hop)

	match style_name:
		"flies into the bag":
			_check("[%s] a ball flies across the screen" % style_name, flew, "")
			_check("[%s] it stays where it was caught" % style_name, nearest_hand > 0.5,
				"came within %.2f m of the hand" % nearest_hand)
		"pops on the spot":
			_check("[%s] it swells before bursting" % style_name, biggest > 1.5, "max scale %.2f" % biggest)
			_check("[%s] no ball flies" % style_name, not flew, "")
		"sucked into the beam":
			_check("[%s] it's pulled into the hand" % style_name, nearest_hand < 0.2,
				"%.2f m from the hand" % nearest_hand)
			_check("[%s] it stretches on the way" % style_name, longest > 1.8, "longest %.2f" % longest)
			_check("[%s] no ball flies" % style_name, not flew, "")

	await _wait(2.0)
	_check("[%s] a ball ends up in the bag" % style_name, _hud._bag.marble_count() == balls_before + 1,
		"%d -> %d" % [balls_before, _hud._bag.marble_count()])
	_check("[%s] the sparkles clean themselves up" % style_name,
		room.get_children().filter(func(n: Node) -> bool: return n is CatchSparkles).is_empty(), "")


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
