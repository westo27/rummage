extends Node
## Headless check for the landing lesson: you start on the landing behind a
## shut door, the hints follow grab, throw, ping, find, catch, and the catch
## swings the door open into the playroom. Not part of the game.
## Run: Godot --headless --path . res://tests/check_tutorial.tscn

var _failures: int = 0
var _main: Node
var _hud: Hud
var _beam: Beam
var _player: CharacterBody3D
var _tutorial: Tutorial


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_hud = _main.get_node("HUD")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	_player = _main.get_node("Player")
	_tutorial = _main.get_node("Tutorial")
	await _wait(1.0)

	var p: Vector3 = _player.global_position
	_check("you start on the landing", p.z > 2.65 and p.z < 5.85 and p.x > -4.4 and p.x < -0.8 \
		and _player.is_on_floor(), "%s" % p)
	_check("first hint: grab", _hud.hint_text() == Tutorial.HINTS[Tutorial.Step.GRAB], "'%s'" % _hud.hint_text())
	var creature: Creature = _main.get_node("Landing/LessonCreature")
	_check("the lesson creature starts hidden", creature.state == Creature.State.HIDDEN, "%s" % creature.state)
	for prop: Prop in _main.get_node("Landing").get_children().filter(func(n: Node) -> bool: return n is Prop):
		_check("%s rests on the landing floor" % prop.name,
			prop.global_position.y > 0.0 and prop.global_position.y < 0.5 and prop.global_position.z > 2.65, "%s" % prop.global_position)

	# The shut door holds you in.
	_player.global_position = Vector3(-2.6, 0.05, 3.2)
	_player.reset_physics_interpolation()
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_check("the shut door stops you", _player.global_position.z > 2.25, "z=%.2f" % _player.global_position.z)

	# Grab the teddy, then throw it.
	var box: Prop = _main.get_node("Landing/LessonTeddy")
	_player.global_position = Vector3(-2.6, 0.05, 5.2)
	_player.reset_physics_interpolation()
	await _wait(0.2)
	_aim_at(box.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.3)
	_check("the teddy is grabbed", _beam.held == box, "held=%s" % _beam.held)
	await _wait(0.6)
	_check("hint moves on to throwing", _hud.hint_text() == Tutorial.HINTS[Tutorial.Step.THROW], "'%s'" % _hud.hint_text())
	_press("throw")
	await _wait(0.1)
	_release("throw")
	_release("grab")
	await _wait(0.6)
	_check("hint moves on to ping", _hud.hint_text() == Tutorial.HINTS[Tutorial.Step.PING], "'%s'" % _hud.hint_text())

	_press("ping")
	await _wait(0.1)
	_release("ping")
	await _wait(0.6)
	_check("hint moves on to finding it", _hud.hint_text() == Tutorial.HINTS[Tutorial.Step.FIND], "'%s'" % _hud.hint_text())

	# Lift the bin off it (as the beam would) and it's out.
	var bin: Prop = _main.get_node("Landing/LessonBin")
	bin.global_position += Vector3(0, 0.8, 0)
	bin.freeze = true
	await _wait(1.0)
	_check("lifting the bin finds it", creature.state != Creature.State.HIDDEN, "%s" % creature.state)
	_check("hint moves on to catching", _hud.hint_text() == Tutorial.HINTS[Tutorial.Step.CATCH], "'%s'" % _hud.hint_text())
	_check("the door is still shut", absf((_main.get_node("House/LandingDoor/Door") as Node3D).rotation.y) < 0.01, "")

	_beam._capture(creature)
	await _wait(2.0)
	_check("catching it ends the lesson", _tutorial.step == Tutorial.Step.DONE, "%s" % _tutorial.step)
	_check("last hint points to the house", _hud.hint_text() == Tutorial.DONE_HINT, "'%s'" % _hud.hint_text())
	_check("one ball in the bag", _hud._bag.marble_count() == 1, "%d" % _hud._bag.marble_count())
	var hinge := _main.get_node("House/LandingDoor/Door") as Node3D
	_check("the door swings open", rad_to_deg(hinge.rotation.y) > 90.0, "%.0f deg" % rad_to_deg(hinge.rotation.y))
	await _wait(4.0)
	_check("the last hint fades away", _hud.hint_text() == "", "'%s'" % _hud.hint_text())

	# Now you can walk through into the playroom.
	_player.global_position = Vector3(-2.6, 0.05, 3.4)
	_player.rotation = Vector3.ZERO
	_player.reset_physics_interpolation()
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	_check("you can walk through to the playroom", _player.global_position.z < 1.8, "z=%.2f" % _player.global_position.z)

	# By the bed: crouch, then lie flat; walking off hides it.
	_check("no bed hint away from the bed", _hud.hint_text() == "", "'%s'" % _hud.hint_text())
	var bed: Node3D = _main.get_node("MainRoomProps/Bed")
	_player.global_position = Vector3(bed.global_position.x - 0.4, 0.05, bed.global_position.z + 1.2)
	_player.reset_physics_interpolation()
	await _wait(0.8)
	_check("near the bed: crouch hint", _hud.hint_text() == Tutorial.CROUCH_HINT, "'%s'" % _hud.hint_text())
	_player.global_position = Vector3(-2.6, 0.05, 1.0)
	_player.reset_physics_interpolation()
	await _wait(0.8)
	_check("walking off hides it", _hud.hint_text() == "", "'%s'" % _hud.hint_text())
	_player.global_position = Vector3(bed.global_position.x - 0.4, 0.05, bed.global_position.z + 1.2)
	_player.reset_physics_interpolation()
	Input.action_press("crouch")
	await _wait(1.5)
	_check("crouched: lie-flat hint", _hud.hint_text() == Tutorial.PRONE_HINT, "'%s'" % _hud.hint_text())
	Input.action_press("prone")
	await _wait(2.0)
	_check("lying flat hides it", _hud.hint_text() == "", "'%s'" % _hud.hint_text())
	Input.action_release("prone")
	Input.action_release("crouch")
	await _wait(2.0)
	_check("and it doesn't come back", _hud.hint_text() == "", "'%s'" % _hud.hint_text())

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


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
