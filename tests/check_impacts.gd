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
	var crate: Prop = _main.get_node("MainRoomProps/CrateA")
	var crate_knock: Dictionary = await _drop(crate, 2.0)
	_check("a dropped crate knocks", not crate_knock.is_empty(), "")
	if not crate_knock.is_empty():
		_check("it sounds like wood", crate_knock.material == Tones.ImpactMaterial.WOOD,
			"material %d" % crate_knock.material)
		_check("the sound comes from the crate",
			(crate_knock.at as Vector3).distance_to(crate.global_position) < 0.6,
			"%.2f m away" % (crate_knock.at as Vector3).distance_to(crate.global_position))
		_check("a hard landing is near full loudness", crate_knock.db > Game.tune.impact_max_db - 4.0,
			"%.1f dB" % crate_knock.db)
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
	book.global_position = Vector3(0.5, 0.1, 2.5)
	var book_knock: Dictionary = await _drop(book, 1.5)
	_check("a book sounds like paper", not book_knock.is_empty()
		and book_knock.material == Tones.ImpactMaterial.PAPER, "%s" % book_knock)
	var sofa_knock: Dictionary = await _drop(_main.get_node("MainRoomProps/Sofa"), 0.6)
	_check("the sofa sounds soft", not sofa_knock.is_empty()
		and sofa_knock.material == Tones.ImpactMaterial.SOFT, "%s" % sofa_knock)
	_check("the sofa lands with a proper thud, not a whisper",
		not sofa_knock.is_empty() and sofa_knock.db > Game.tune.impact_max_db - 12.0,
		"%.1f dB" % sofa_knock.get("db", -99.0))
	# Pitch scales within a material: the same soft thump, lower for the
	# heavier thing. (Across materials each has its own natural pitch.)
	var cushion: Prop = _main.get_node("MainRoomProps/CushionL")
	cushion.global_position = Vector3(1.5, 0.1, 2.5)
	var cushion_knock: Dictionary = await _drop(cushion, 1.5)
	_check("the sofa thuds lower than a cushion", not cushion_knock.is_empty()
		and not sofa_knock.is_empty() and sofa_knock.pitch < cushion_knock.pitch * 0.7,
		"cushion %.2f, sofa %.2f" % [cushion_knock.get("pitch", 0.0), sofa_knock.get("pitch", 0.0)])
	var ball: Prop = _main.get_node("MainRoomProps/BallFloor")
	ball.global_position = Vector3(-0.5, 0.15, 2.5)
	var ball_knock: Dictionary = await _drop(ball, 1.5)
	_check("a ball sounds like rubber", not ball_knock.is_empty()
		and ball_knock.material == Tones.ImpactMaterial.RUBBER, "%s" % ball_knock)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Lifts a prop straight up by `height`, lets it fall, and returns its
## loudest knock (or an empty Dictionary if it made none). The loudest, not
## the first: lifting the sofa out from under its own cushions means it
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
