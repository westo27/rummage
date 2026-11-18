extends Node
## Renders two views with the screen filter off and at each size.
## Needs a real window (no --headless). Doesn't save the settings file.
## Run: Godot --path . --resolution 1920x1080 res://tests/shoot_filter.tscn

const OUT: String = "user://shots"

# name, where the player stands, what they look at
const VIEWS: Array = [
	["bedroom", Vector3(4.2, 0.05, 1.3), Vector3(1.0, 0.7, -1.8)],
	["playroom", Vector3(-4.3, 0.05, 0.6), Vector3(-0.5, 0.5, -1.2)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var saved: Array = [Game.settings.screen_filter, Game.settings.filter_size]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	await _frames(30)
	for view: Array in VIEWS:
		player.global_position = view[1]
		player.reset_physics_interpolation()
		var dir: Vector3 = (view[2] - head.global_position).normalized()
		player.rotation.y = atan2(-dir.x, -dir.z)
		head.rotation.x = asin(dir.y)
		await _frames(20)
		# 0 is the filter off.
		for size: int in [0, 1, 2, 3]:
			Game.settings.screen_filter = size > 0
			Game.settings.filter_size = maxi(size, 1)
			Game.settings.apply_screen_filter()
			await _frames(10)
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("%s/filter_%s_%d.png" % [OUT, view[0], size])
	Game.settings.screen_filter = saved[0]
	Game.settings.filter_size = saved[1]
	Game.settings.apply_screen_filter()
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
