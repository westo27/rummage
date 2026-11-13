extends Node
## Walks the player into typical post-chaos floor clutter and reports whether
## they get past it. Not part of the game.
## Run: Godot --headless --path . res://tests/check_floor_clutter.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_main.get_node("MainRoomProps").free()
	_main.get_node("MainRoomCreatures").free()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	await _wait(0.5)

	var book: PackedScene = load("res://scenes/props/book.tscn")
	var flat := Basis(Vector3.RIGHT, PI / 2.0)      # lying flat, 4 cm tall
	var on_edge := Basis(Vector3.FORWARD, PI / 2.0)  # on its long edge, 17 cm tall
	# name, scene, basis, must_get_past
	var cases: Array = [
		["flat book", book, flat, true],
		["book on its edge", book, on_edge, true],
		["book standing up", book, Basis.IDENTITY, true],
		["ball", load("res://scenes/props/ball.tscn"), Basis.IDENTITY, true],
		["pillow", load("res://scenes/props/pillow.tscn"), Basis.IDENTITY, true],
		["bin on its side", load("res://scenes/props/bin.tscn"), Basis(Vector3.FORWARD, PI / 2.0), true],
		["pile of 5 books", null, flat, true],
		["crate", load("res://scenes/props/crate.tscn"), Basis.IDENTITY, false],
	]
	for c: Array in cases:
		await _try_case(c[0], c[1], c[2], c[3])

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Player walks north (−Z) along x=-2 from z=3 for 2 s; obstacle sits at z=1.5.
func _try_case(label: String, scene: PackedScene, basis: Basis, must_pass: bool) -> void:
	var spawned: Array[Node3D] = []
	if scene == null:  # pile
		var b: PackedScene = load("res://scenes/props/book.tscn")
		for i in 5:
			var p := b.instantiate() as Node3D
			_main.add_child(p)
			p.global_transform = Transform3D(basis, Vector3(-2.0, 0.022 + i * 0.041, 1.5))
			spawned.append(p)
	else:
		var p := scene.instantiate() as Node3D
		_main.add_child(p)
		p.global_transform = Transform3D(basis, Vector3(-2.0, 0.3, 1.5))
		spawned.append(p)
	await _wait(1.0)  # let it drop and settle
	var settled_at: Vector3 = spawned[0].global_position

	_player.global_position = Vector3(-2.0, 0.05, 3.0)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(0.1)
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	var z: float = _player.global_position.z
	var got_past: bool = z < 0.9
	var kicked: float = spawned[0].global_position.distance_to(settled_at)
	# Clutter must be both passable and visibly kicked (not ghosted through).
	var ok: bool = (got_past and kicked > 0.3) if must_pass else not got_past
	if not ok:
		_failures += 1
	print("%s  %-18s player z=%.2f (obstacle at 1.5) %s, obstacle moved %.2f m" % [
		"PASS" if ok else "FAIL", label, z, "got past" if got_past else "BLOCKED", kicked])
	for p in spawned:
		p.queue_free()
	await _wait(0.2)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
