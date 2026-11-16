extends Node
## Renders the itch.io page screenshots: five staged moments of play with the
## HUD showing. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1920x1080 res://tests/shoot_itch.tscn

const OUT: String = "user://shots"
const SEED: int = 2
const UNDER_BED := Vector3(2.5, 0.1, -1.6)
const CATCH_SPOT := Vector3(2.45, 0.1, -1.17)

var _main: Node
var _player: CharacterBody3D
var _head: Node3D
var _beam: Beam
var _reach: float = -1.0


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	# Holds the catch beam part-way out (see shoot_cover.gd).
	if _reach >= 0.0:
		_beam._catch_started = Time.get_ticks_msec() / 1000.0 - _reach * Beam.CATCH_REACH_TIME


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(SEED)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main.get_node("Player") as CharacterBody3D
	_head = _player.get_node("Head") as Node3D
	_beam = _main.get_node("Player/Head/Camera3D/Beam") as Beam
	_player.set_process_unhandled_input(false)
	# No lesson prompts over the shots.
	_main.get_node("Tutorial").queue_free()

	# A game partway through: some marbles in the bag.
	var hud := _main.get_node("HUD") as Hud
	for i in 9:
		hud.add_to_bag(Creature.BODY_COLORS[i % Creature.BODY_COLORS.size()])
	hud.set_caught(9, 25)
	hud.set_time(204.0)
	await get_tree().create_timer(4.0).timeout
	hud.hide_hint()
	await get_tree().create_timer(1.0).timeout

	# 1. The bedroom by lamplight.
	await _stand(Vector3(4.2, 0.05, 1.3), Vector3(1.0, 0.7, -1.8))
	_shoot("itch_1_bedroom")

	# 2. The beam lifting the school bag in the playroom.
	var bag := _main.get_node("MainRoomProps/PlayroomBag") as Prop
	var at: Vector3 = bag.global_position
	await _stand(at + Vector3(-1.1, 0.0, 1.6), at + Vector3(0.0, 0.3, 0.0))
	_beam._grab_armed = true
	_beam._grab(bag, bag.global_position + Vector3(0.0, 0.1, 0.0))
	_look(at + Vector3(0.0, 0.9, 0.0))
	await get_tree().create_timer(0.9).timeout
	_shoot("itch_2_beam")
	if _beam.held != null:
		_beam._release()
	_beam._grab_armed = false
	await get_tree().create_timer(0.8).timeout

	# 3. A ping: hidden creatures answer with a glow.
	var creature := _creature_of(Creature.BODY_COLORS[1])
	creature.global_position = UNDER_BED
	creature.reset_physics_interpolation()
	# Get right down first: aiming mid-crouch would tilt the view at the carpet.
	Input.action_press("crouch")
	await _frames(60)
	await _stand(Vector3(2.55, 0.05, 0.6), Vector3(2.55, 0.3, -1.6), 30)
	(_main.get_node("Ping") as Ping)._ping()
	await get_tree().create_timer(0.7).timeout
	_shoot("itch_3_ping")
	await get_tree().create_timer(4.0).timeout

	# 4. The catch: the creature pulled out from under the bed.
	creature.global_position = CATCH_SPOT
	creature.reset_physics_interpolation()
	await _stand(Vector3(2.3, 0.05, 0.5), Vector3(2.5, 0.3, -1.6))
	_beam._capture(creature)
	Engine.time_scale = 0.03
	_reach = 0.8
	await get_tree().create_timer(0.12, true, false, true).timeout
	_shoot("itch_4_catch")
	_reach = -1.0
	Engine.time_scale = 1.0
	Input.action_release("crouch")
	await get_tree().create_timer(1.0).timeout

	# 5. The playroom by lamplight.
	await _stand(Vector3(-0.6, 0.05, -1.6), Vector3(-4.5, 0.4, 1.4))
	_shoot("itch_5_playroom")

	print("RESULT itch shots in %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _stand(eye: Vector3, target: Vector3, settle: int = 25) -> void:
	_player.global_position = eye
	_player.reset_physics_interpolation()
	await _frames(5)
	_look(target)
	await _frames(settle)


func _creature_of(color: Color) -> Creature:
	for c in _main.get_node("MainRoomCreatures").get_children():
		if c is Creature and (c as Creature).body_color == color:
			return c as Creature
	return null


func _shoot(shot_name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])


func _look(target: Vector3) -> void:
	var dir: Vector3 = (target - _head.global_position).normalized()
	_player.rotation.y = atan2(-dir.x, -dir.z)
	_head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
