extends Node
## Headless test: creatures bump into each other like marbles and clack.
## Run: Godot --headless --path . res://tests/check_bump.tscn

var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	var creatures: Node = main.get_node("MainRoomCreatures")
	var player := main.get_node("Player") as Node3D
	await _wait(1.0)

	# Two creatures on open bedroom floor, the player well away. One sits
	# still (cowering); the other rolls straight at it.
	player.global_position = Vector3(6.5, 0.05, 2.0)
	var still: Creature = creatures.get_child(0)
	var roller: Creature = creatures.get_child(1)
	still.global_position = Vector3(1.4, 0.07, -0.3)
	roller.global_position = Vector3(2.0, 0.07, -0.3)
	still._start_cowering()
	still._covers = {}
	roller._reveal()
	roller._flee_dir = Vector3.LEFT
	roller._escape_left = 1.0  # straight ahead, ignoring the player
	roller._state_left = 5.0
	roller.velocity = Vector3.ZERO  # no startled hop: it would jump right over

	var clacked: bool = false
	var closest: float = 99.0
	for i in 60:
		await get_tree().physics_frame
		if roller._clack_voice.playing:
			clacked = true
		closest = minf(closest, roller.global_position.distance_to(still.global_position))
	_check("rolling into another creature clacks", clacked, "")
	_check("they collide instead of passing through", closest > 0.09, "closest %.3f m" % closest)
	_check("the still one doesn't clack too", not still._clack_voice.playing, "")

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
