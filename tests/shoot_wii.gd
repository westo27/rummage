extends Node
## Art-direction comparison: rim light and gloss off and on.
## Needs a real window (no --headless). Doesn't save the settings file.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_wii.tscn
## Writes look_<view>_<variant>.png to user://shots.

const OUT: String = "user://shots"

const VIEWS: Array = [
	["bedroom", Vector3(4.2, 0.05, 1.3), Vector3(1.0, 0.7, -1.8)],
	["playroom", Vector3(-4.3, 0.05, 0.6), Vector3(-0.5, 0.5, -1.2)],
]

# name, look (1 off / 3 smooth 360p), rim + gloss
const VARIANTS: Array = [
	["1_plain", 1, false],
	["1_wii", 1, true],
	["3_plain", 3, false],
	["3_wii", 3, true],
]


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
	await _frames(30)
	for view: Array in VIEWS:
		player.global_position = view[1]
		player.reset_physics_interpolation()
		var dir: Vector3 = (view[2] - head.global_position).normalized()
		player.rotation.y = atan2(-dir.x, -dir.z)
		head.rotation.x = asin(dir.y)
		await _frames(20)
		for v: Array in VARIANTS:
			if v[1] == 1:
				Game.looks.set_look("", false, 3)
			else:
				Game.looks.set_look("", true, 2)
			Game.looks.set_wii_finish(v[2])
			await _frames(10)
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("%s/wii_%s_%s.png" % [OUT, view[0], v[0]])
	Game.looks.set_wii_finish(false)
	Game.pixel_filter.set_colour_limit(true)
	Game.settings.pixel_filter = saved[0]
	Game.settings.pixel_strength = saved[1]
	Game.settings.apply_pixel_filter()
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
