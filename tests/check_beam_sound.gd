extends Node
## Headless check for the beam's sounds: silent when idle; the whirr fades in
## when you grab something, rises and swells when you swing it, settles when
## you hold still, and fades away when you let go; the crackle plays only
## while straining against something too heavy. (What they sound like can be
## heard in the WAVs tests/render_knocks.tscn saves.) Not part of the game.
## Run: Godot --headless --path . res://tests/check_beam_sound.tscn

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
	await _wait(1.0)
	_check("silent when the beam isn't holding anything",
		not _beam._hum.playing and not _beam._strain.playing, "")
	_check("both sounds are seamless loops",
		_beam._hum.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and _beam._strain.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "")

	# --- Grab a crate: the whirr fades in ---
	var crate: Prop = _main.get_node("MainRoomProps/CrateA")
	_player.global_position = Vector3(2.5, 0.05, 0.9)
	_aim_at(crate.global_position + Vector3(0.0, 0.3, 0.0))
	await _wait(0.1)
	_press("grab")
	await _wait(0.05)
	var early: float = _beam._hum_gain
	await _wait(0.5)
	_check("grabbing starts the whirr", _beam._hum.playing, "")
	_check("it fades in rather than starting at full volume", early < _beam._hum_gain,
		"%.3f -> %.3f" % [early, _beam._hum_gain])
	var still_pitch: float = _beam._hum.pitch_scale
	var still_volume: float = _beam._hum.volume_db
	_check("holding still: normal pitch", still_pitch < 1.1, "pitch %.2f" % still_pitch)

	# --- Swing it hard: the whirr rises and swells ---
	var highest: float = 0.0
	var loudest: float = -80.0
	for i in 40:
		var side: float = 1.0 if (i / 10) % 2 == 0 else -1.0
		_aim_at(Vector3(2.5 + side * 2.5, 1.2, -1.5))
		await get_tree().physics_frame
		await get_tree().process_frame
		highest = maxf(highest, _beam._hum.pitch_scale)
		loudest = maxf(loudest, _beam._hum.volume_db)
	_check("swinging raises the whirr's pitch", highest > 1.25, "up to %.2f" % highest)
	_check("swinging makes it louder", loudest > still_volume + 3.0,
		"%.1f dB still, up to %.1f dB" % [still_volume, loudest])
	_check("it stays quieter than the squeaks", loudest < Game.tune.squeak_volume_db,
		"%.1f dB vs squeak %.1f dB" % [loudest, Game.tune.squeak_volume_db])

	# --- Hold still again: it settles ---
	_aim_at(Vector3(2.5, 1.0, -1.5))
	await _wait(1.5)
	_check("held still again, it settles back down", _beam._hum.pitch_scale < 1.1,
		"pitch %.2f" % _beam._hum.pitch_scale)

	# --- Let go: it fades away and stops ---
	_release("grab")
	await _wait(1.0)
	_check("letting go fades the whirr away", not _beam._hum.playing, "gain %.4f" % _beam._hum_gain)

	# --- Strain against the sofa: crackle, and only then ---
	var sofa: Prop = _main.get_node("MainRoomProps/Sofa")
	_player.global_position = Vector3(0.3, 0.05, -2.2)
	_aim_at(sofa.global_position + Vector3(0.0, 0.35, 0.3))
	await _wait(0.1)
	_press("grab")
	await _wait(0.5)
	_check("straining against the sofa crackles", _beam._rejected == sofa and _beam._strain.playing, "")
	_check("no whirr while straining", not _beam._hum.playing, "")
	_release("grab")
	await _wait(1.0)
	_check("letting go stops the crackle", not _beam._strain.playing, "")

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
