extends Node
## Headless check for impact sounds: things knock when they hit, by material,
## louder for harder hits, lower for heavier things, and stay quiet when
## they're only resting or being set down gently. Not part of the game.
## Run: Godot --headless --path . res://tests/check_impacts.tscn

var _failures: int = 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await _wait(2.0)
	_check("the room settles in silence", Game.impacts.log.is_empty(),
		"%d knocks" % Game.impacts.log.size())

	# --- A crate dropped from 2 m knocks, as wood, from where it landed ---
	# Drops happen on the open bedroom floor.
	var crate: Prop = _main.get_node("MainRoomProps/CrateA")
	crate.global_position = Vector3(2.8, 0.3, 0.5)
	crate.sleeping = false
	await _wait(0.5)
	var crate_knock: Dictionary = await _drop(crate, 2.0)
	_check("a dropped crate knocks", not crate_knock.is_empty(), "")
	if not crate_knock.is_empty():
		_check("it sounds like wood", crate_knock.material == Tones.ImpactMaterial.WOOD,
			"material %d" % crate_knock.material)
		_check("the sound comes from the crate",
			(crate_knock.at as Vector3).distance_to(crate.global_position) < 0.6,
			"%.2f m away" % (crate_knock.at as Vector3).distance_to(crate.global_position))
		_check("a hard landing is near full loudness", crate_knock.db > Game.tune.impact_max_db - 4.0,
			"%.1f dB at %.2f m/s" % [crate_knock.db, crate_knock.speed])
		_check("knocks stay quieter than the squeaks", crate_knock.db < Game.tune.squeak_volume_db,
			"%.1f dB vs squeak %.1f dB" % [crate_knock.db, Game.tune.squeak_volume_db])

	# --- Set down gently: no sound ---
	await _wait(1.0)
	var gentle: Dictionary = await _drop(crate, 0.02)
	_check("a crate set down gently is silent", gentle.is_empty(),
		"" if gentle.is_empty() else "%.2f m/s" % gentle.speed)

	# --- Resting stays silent ---
	await _wait(0.5)
	var before: int = Game.impacts.log.size()
	await _wait(1.5)
	_check("resting things stay silent", Game.impacts.log.size() == before,
		"%d new knocks" % (Game.impacts.log.size() - before))

	# --- Materials and pitch ---
	# Moved to open floor first, so they land on the floor and nothing else.
	var book: Prop = _main.get_node("MainRoomProps/ShelfBook01")
	book.global_position = Vector3(2.0, 0.1, 0.2)
	var book_knock: Dictionary = await _drop(book, 1.5)
	_check("a book sounds like paper", not book_knock.is_empty()
		and book_knock.material == Tones.ImpactMaterial.PAPER, "%s" % book_knock)
	# The pillows stay put when the bed is raised, so clear them away or the
	# bed lands on them.
	for i in 2:
		var pillow_out: Prop = _main.get_node("MainRoomProps/Pillow" + ["L", "R"][i])
		pillow_out.global_position = Vector3(3.0 + i * 0.6, 0.1, 0.9)
	await _wait(0.5)
	var bed_knock: Dictionary = await _drop(_main.get_node("MainRoomProps/Bed"), 0.6)
	_check("the bed sounds soft", not bed_knock.is_empty()
		and bed_knock.material == Tones.ImpactMaterial.SOFT, "%s" % bed_knock)
	_check("the bed lands with a proper thud, not a whisper",
		not bed_knock.is_empty() and bed_knock.db > Game.tune.impact_max_db - 12.0,
		"%.1f dB" % bed_knock.get("db", -99.0))
	# Pitch scales within a material: the same soft thump, lower for the
	# heavier thing. (Across materials each has its own natural pitch.)
	var pillow: Prop = _main.get_node("MainRoomProps/PillowL")
	pillow.global_position = Vector3(2.2, 0.1, 0.9)
	var pillow_knock: Dictionary = await _drop(pillow, 1.5)
	_check("the bed thuds lower than a pillow", not pillow_knock.is_empty()
		and not bed_knock.is_empty() and bed_knock.pitch < pillow_knock.pitch * 0.7,
		"pillow %.2f, bed %.2f" % [pillow_knock.get("pitch", 0.0), bed_knock.get("pitch", 0.0)])
	var ball: Prop = _main.get_node("MainRoomProps/BallFloor")
	ball.global_position = Vector3(2.6, 0.15, 0.0)
	var ball_knock: Dictionary = await _drop(ball, 1.5)
	_check("a ball sounds like rubber", not ball_knock.is_empty()
		and ball_knock.material == Tones.ImpactMaterial.RUBBER, "%s" % ball_knock)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Lifts a prop straight up by `height`, lets it fall, and returns its
## loudest knock (or an empty Dictionary if it made none). The loudest, not
## the first: lifting the bed out from under its own pillows means it
## brushes them on the way down before it lands.
func _drop(prop: Prop, height: float) -> Dictionary:
	prop.global_position += Vector3.UP * height
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.sleeping = false
	prop.reset_physics_interpolation()
	var before: int = Game.impacts.log.size()
	await _wait(1.2)
	var loudest: Dictionary = {}
	for i in range(before, Game.impacts.log.size()):
		var knock: Dictionary = Game.impacts.log[i]
		if is_equal_approx(knock.mass, prop.mass) and (loudest.is_empty() or knock.db > loudest.db):
			loudest = knock
	return loudest


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
