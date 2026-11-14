extends Node
## Renders one bedroom view with the pixel filter off and at a few strengths.
## Needs a real window (no --headless). Doesn't save the settings file.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_pixel.tscn

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var saved: Array = [Game.settings.pixel_filter, Game.settings.pixel_strength]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	player.global_position = Vector3(4.2, 0.05, 1.3)
	player.reset_physics_interpolation()
	var dir: Vector3 = (Vector3(1.0, 0.7, -1.8) - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	await _frames(30)
	for strength: int in [0, 1, 3, 5, 8]:
		Game.settings.pixel_filter = strength > 0
		Game.settings.pixel_strength = maxi(strength, 1)
		Game.settings.apply_pixel_filter()
		await _frames(10)
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("%s/pixel_%d.png" % [OUT, strength])
	Game.settings.pixel_filter = saved[0]
	Game.settings.pixel_strength = saved[1]
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
