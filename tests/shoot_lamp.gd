extends Node
## Tool, not a test: renders the ceiling around the main lamp, still and
## swinging, to user://shots, for checking how its light and shadow look.
## Needs a real window: Godot --path . --resolution 1600x900 res://tests/shoot_lamp.tscn

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	# Stop the mouse turning the camera while this runs.
	main.get_node("Player").set_process_unhandled_input(false)
	var player := main.get_node("Player") as Node3D
	var head := player.get_node("Head") as Node3D
	player.global_position = Vector3(2.6, 0.05, 1.55)
	player.reset_physics_interpolation()
	_look(player, head, Vector3(2.6, 2.6, -0.65))
	await get_tree().create_timer(1.5).timeout
	_shoot("lamp_still")
	# The same view at each Graphics > Lighting level.
	var saved: Settings.Lighting = Game.settings.lighting
	for level in [Settings.Lighting.HIGH, Settings.Lighting.MEDIUM, Settings.Lighting.LOW]:
		Game.settings.lighting = level
		Game.settings.apply_lighting(main)
		await get_tree().create_timer(0.6).timeout
		_shoot("lamp_still_%s" % Settings.LIGHTING_NAMES[level].to_lower())
	Game.settings.lighting = saved
	Game.settings.apply_lighting(main)

	var book := main.get_node("MainRoomProps/ShelfBook02") as Prop
	book.global_position = Vector3(1.2, 2.27, -0.15)
	book.linear_velocity = Vector3(12.0, 0.0, 0.0)  # side-on, across the view
	book.sleeping = false
	book.reset_physics_interpolation()
	await get_tree().create_timer(0.3).timeout
	_shoot("lamp_swing_a")
	await get_tree().create_timer(0.35).timeout
	_shoot("lamp_swing_b")
	get_tree().quit()


func _look(player: Node3D, head: Node3D, target: Vector3) -> void:
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _shoot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
