extends Node
## Headless check: a creature that's been uncovered cowers somewhere the player
## can't see it from where they're standing. Not part of the game.
## Run: Godot --headless --path . res://tests/check_hiding.tscn

var _failures: int = 0
var _main: Node
var _player: CharacterBody3D

## Where the player stands for each trial (they don't move during it).
const PLAYER_SPOTS: Array[Vector3] = [
	Vector3(0.0, 0.05, 3.5), Vector3(-4.0, 0.05, 0.0), Vector3(4.0, 0.05, -3.0),
	Vector3(2.0, 0.05, 3.8), Vector3(-2.5, 0.05, -3.5), Vector3(0.0, 0.05, 0.0),
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_player = _main.get_node("Player")
	await _wait(1.0)

	var candidates: Array[Creature] = []
	for c: Creature in _main.get_node("MainRoomCreatures").get_children():
		if not c.name.begins_with("UnderSofa"):
			candidates.append(c)

	var hid: int = 0
	var trials: int = 0
	for i in 12:
		var c: Creature = candidates[i]
		_player.global_position = PLAYER_SPOTS[i % PLAYER_SPOTS.size()]
		_player.reset_physics_interpolation()
		await _wait(0.2)
		c._reveal()
		await _wait(Game.tune.flee_time_max + Game.tune.seek_time + 0.5)
		var eye: Vector3 = (_player.get_node("Head") as Node3D).global_position
		var cowering: bool = c.state == Creature.State.COWERING
		var hidden: bool = c._hidden_at(c.global_position, eye)
		trials += 1
		if cowering and hidden:
			hid += 1
		print("  %-14s player %s -> %s  %s  behind %s" % [c.name, PLAYER_SPOTS[i % PLAYER_SPOTS.size()],
			c.global_position.snapped(Vector3.ONE * 0.01), "HIDDEN" if hidden else "VISIBLE",
			c._seek_target.name if is_instance_valid(c._seek_target) else "-"])
		c.queue_free()  # out of the way of the next trial
		await _wait(0.1)

	_check("uncovered creatures cower out of the player's sight", hid == trials, "%d / %d hidden" % [hid, trials])
	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
