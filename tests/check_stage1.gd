extends Node
## Headless smoke test for stage 1. Not part of the game.
## Run: Godot --headless --path . res://tests/check_stage1.tscn
## (A scene rather than --script, so the Game autoload is loaded first.)
## Loads the main scene, simulates key presses, and prints PASS/FAIL lines.

var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Stage 1 checks the bare room shell, so remove the furniture first.
	main.get_node("MainRoomProps").free()
	get_tree().root.add_child(main)
	var player := main.get_node("Player") as CharacterBody3D

	await _wait(1.0)
	_check("player lands on floor", player.is_on_floor() and absf(player.global_position.y) < 0.05,
		"y=%.3f on_floor=%s" % [player.global_position.y, player.is_on_floor()])

	# Gravity on the physics space should be the tunable value (14), not Godot's 9.8.
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	ball.collision_mask = 0
	main.add_child(ball)
	ball.global_position = Vector3(-3, 2.5, -3)
	await _wait(0.25)
	var expected: float = -14.0 * 0.25
	_check("rigid body gravity is 14", absf(ball.linear_velocity.y - expected) < 0.6,
		"vy=%.2f expected about %.2f" % [ball.linear_velocity.y, expected])
	ball.queue_free()

	var start_z: float = player.global_position.z
	Input.action_press("move_forward")
	await _wait(0.5)
	Input.action_release("move_forward")
	var walked: float = start_z - player.global_position.z
	_check("walks forward at about 4.5 m/s", absf(walked - 2.25) < 0.3, "moved %.2f m in 0.5 s" % walked)

	start_z = player.global_position.z
	Input.action_press("move_forward")
	Input.action_press("run")
	await _wait(0.5)
	Input.action_release("move_forward")
	Input.action_release("run")
	walked = start_z - player.global_position.z
	_check("runs at about 7.5 m/s", absf(walked - 3.75) < 0.3, "moved %.2f m in 0.5 s" % walked)

	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	_check("north wall stops the player", player.global_position.z > -5.0,
		"z=%.2f (wall inner face at -5)" % player.global_position.z)

	# Walk east through the doorway into the side room (doorway is at z=0, x=6).
	player.global_position = Vector3(4.5, 0.05, 0.0)
	player.rotation.y = -PI / 2.0  # face +X
	await _wait(0.2)
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_check("doorway leads into side room", player.global_position.x > 7.0,
		"x=%.2f" % player.global_position.x)

	player.global_position = Vector3(0, -20, 0)
	await _wait(0.1)
	_check("falling below floor resets to start", player.global_position.y > -1.0,
		"pos=%s" % player.global_position)

	print("RESULT: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _wait(seconds: float) -> void:
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", label, detail])
