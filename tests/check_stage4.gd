extends Node
## Headless smoke test for stage 4 (gates, side room, ping, HUD, win, restart).
## Not part of the game.
## Run: Godot --headless --path . res://tests/check_stage4.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D
var _beam: Beam
var _hud: Hud


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	# Make it the "current scene" so R (reload_current_scene) reloads it.
	get_tree().current_scene = _main
	_bind()
	await _wait(1.0)

	# --- Totals and HUD ---
	_check("25 creatures in total", get_tree().get_nodes_in_group("creatures").size() == 25, "")
	_check("4 of them in the side room", _main.get_node("SideRoomCreatures").get_child_count() == 4, "")
	_check("HUD shows 0 / 25", _label("CaughtLabel") == "Caught: 0 / 25", "'%s'" % _label("CaughtLabel"))
	_check("HUD shows lift", _label("LiftLabel") == "Lift: 10 kg", "'%s'" % _label("LiftLabel"))
	_check("timer is counting up", _label("TimerLabel") != "0:00.0", "'%s'" % _label("TimerLabel"))
	_check("HUD shows ping ready", _label("PingLabel").begins_with("Ping ready"), "'%s'" % _label("PingLabel"))

	# --- Ping: near hidden creatures answer, far ones don't, then cooldown ---
	_player.global_position = Vector3(-0.6, 0.05, 3.6)  # 1.2 m from the creature under Bin01
	await _wait(0.1)
	var near: Creature = _main.get_node("MainRoomCreatures/UnderBin01")  # (-0.6, 2.4)
	var far: Creature = _main.get_node("MainRoomCreatures/UnderCrateD")  # (-4.2, -4.2), ~9 m away
	_press("ping")
	await _wait(0.2)
	_check("ping: nearby hidden creature glows", near._glow.visible, "")
	_check("ping: far creature does not answer", not far._glow.visible, "")
	_check("ping doesn't reveal anyone", near.state == Creature.State.HIDDEN, "state=%s" % near.state)
	_check("HUD shows ping cooldown", _label("PingLabel").begins_with("Ping  "), "'%s'" % _label("PingLabel"))
	await _wait(1.0)  # let the glow fade
	_press("ping")
	await _wait(0.2)
	_check("ping can't be used again during cooldown", not near._glow.visible, "")

	# --- Gates: catch main-room creatures one by one (sofa ones last) ---
	var order: Array[Creature] = []
	for c: Creature in _main.get_node("MainRoomCreatures").get_children():
		if not c.name.begins_with("UnderSofa"):
			order.append(c)
	for c: Creature in _main.get_node("MainRoomCreatures").get_children():
		if c.name.begins_with("UnderSofa"):
			order.append(c)

	var sofa: Prop = _main.get_node("MainRoomProps/Sofa")
	var wardrobe: Prop = _main.get_node("MainRoomProps/Wardrobe")
	await _catch(order.slice(0, 7))
	_check("after 7 catches the sofa is still too heavy", sofa.mass > _beam.lift_limit, "lift %.0f" % _beam.lift_limit)
	await _catch(order.slice(7, 8))
	_check("after 8 catches the sofa is liftable", sofa.mass <= _beam.lift_limit, "lift %.0f" % _beam.lift_limit)
	_check("HUD announces the sofa", _label("ToastLabel").contains("sofa"), "'%s'" % _label("ToastLabel"))

	# Actually lift the sofa with the beam.
	_player.global_position = Vector3(0.0, 0.05, -1.8)
	_aim_at(sofa.global_position)
	await _wait(0.1)
	_check("crosshair shows CAN_GRAB on the sofa", _beam._state == Beam.AimState.CAN_GRAB, "state=%s" % _beam._state)
	_press("grab")
	await _wait(0.2)
	_check("beam picks up the sofa", _beam.held == sofa, "held=%s" % _beam.held)
	_aim_at(sofa.global_position + Vector3(0, 1.2, 0))
	await _wait(1.0)
	_release("grab")
	await _wait(0.3)
	var sofa_hidden: int = 0
	for i in 4:
		if (_main.get_node("MainRoomCreatures/UnderSofa%d" % (i + 1)) as Creature).state == Creature.State.HIDDEN:
			sofa_hidden += 1
	_check("lifting the sofa reveals the creatures under it", sofa_hidden == 0, "%d still hidden" % sofa_hidden)

	await _catch(order.slice(8, 14))
	_check("after 14 catches the wardrobe is still too heavy", wardrobe.mass > _beam.lift_limit, "lift %.0f" % _beam.lift_limit)
	await _catch(order.slice(14, 15))
	_check("after 15 catches the wardrobe is liftable", wardrobe.mass <= _beam.lift_limit, "lift %.0f" % _beam.lift_limit)
	_check("HUD announces the wardrobe", _label("ToastLabel").contains("wardrobe"), "'%s'" % _label("ToastLabel"))

	# --- Drag the wardrobe off the doorway, then walk into the side room ---
	_player.global_position = Vector3(3.6, 0.05, 0.0)
	_aim_at(wardrobe.global_position)
	await _wait(0.1)
	_press("grab")
	await _wait(0.2)
	_check("beam picks up the wardrobe", _beam.held == wardrobe, "held=%s" % _beam.held)
	_aim_at(Vector3(4.6, 1.0, 3.5))  # pull it toward the south-east corner
	await _wait(4.0)
	_release("grab")
	await _wait(1.0)
	_check("wardrobe moved off the doorway", absf(wardrobe.global_position.z) > 1.2,
		"pos=%s" % wardrobe.global_position)
	_player.global_position = Vector3(4.5, 0.05, 0.0)
	_player.rotation.y = -PI / 2.0
	(_player.get_node("Head") as Node3D).rotation.x = 0.0
	Input.action_press("move_forward")
	await _wait(1.2)
	Input.action_release("move_forward")
	_check("player can walk into the side room", _player.global_position.x > 7.0, "x=%.2f" % _player.global_position.x)

	# --- Catch everything else: win screen, timer stops ---
	var rest: Array[Creature] = []
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c.state != Creature.State.CAPTURED:
			rest.append(c)
	await _catch(rest)
	var win_panel := _main.get_node("HUD/WinPanel") as Control
	_check("win panel appears when all are caught", win_panel.visible, "")
	_check("win panel shows the time",
		(win_panel.find_child("WinLabel", true, false) as Label).text.contains("Time"), "")
	var win_pills: Array[String] = []
	for node in win_panel.find_children("*", "MenuPanel", true, false):
		win_pills.append((node as MenuPanel).label_text)
	_check("win screen offers Play again and Title", win_pills == ["Play again", "Title"],
		"%s" % [win_pills])
	_check("the player stops grabbing the cursor after winning",
		not _player.is_processing_input() and not _beam.is_processing_unhandled_input(), "")
	_check("HUD shows 25 / 25", _label("CaughtLabel") == "Caught: 25 / 25", "'%s'" % _label("CaughtLabel"))
	var t1: String = _label("TimerLabel")
	await _wait(0.5)
	_check("timer stops after winning", _label("TimerLabel") == t1, "%s -> %s" % [t1, _label("TimerLabel")])

	# --- R restarts everything ---
	_press("restart")
	await _wait(0.5)
	_main = get_tree().current_scene
	_bind()
	_check("R reloads a fresh game", _label("CaughtLabel") == "Caught: 0 / 25" and not (_main.get_node("HUD/WinPanel") as Control).visible,
		"'%s'" % _label("CaughtLabel"))
	_check("lift is reset after restart", is_equal_approx(_beam.lift_limit, 10.0), "%.0f" % _beam.lift_limit)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _bind() -> void:
	_player = _main.get_node("Player")
	_beam = _main.get_node("Player/Head/Camera3D/Beam")
	_hud = _main.get_node("HUD")


## Catches creatures directly (as if clicked) and waits for their capture animation.
func _catch(creatures: Array[Creature]) -> void:
	var hand: Vector3 = (_main.get_node("Player/Head") as Node3D).global_position
	for c in creatures:
		c.capture(hand)
	await _wait(0.4)


func _label(node_name: String) -> String:
	return (_main.get_node("HUD/" + node_name) as Label).text


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
	# A press is followed by a release, like a real key tap.
	if action != "grab":
		_release.call_deferred(action)


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
