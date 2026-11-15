extends Node
## Art-direction comparison: the current pixel look against cleaner versions.
## Needs a real window (no --headless). Doesn't save the settings file.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_look.tscn
## Writes look_<view>_<variant>.png to user://shots.

const OUT: String = "user://shots"

const VIEWS: Array = [
	["bedroom", Vector3(4.2, 0.05, 1.3), Vector3(1.0, 0.7, -1.8)],
	["playroom", Vector3(-4.3, 0.05, 0.6), Vector3(-0.5, 0.5, -1.2)],
]

# name, filter on, strength, dither+16 shades, texel snapping
const VARIANTS: Array = [
	["a_off", false, 3, false, false],
	["b_current", true, 3, true, true],
	["c_nodither", true, 3, false, true],
	["d_smooth", true, 3, false, false],
	["e_smooth_360p", true, 2, false, false],
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
	# The filter's material, to switch the colour limit off for a shot.
	var mat: ShaderMaterial = Game.pixel_filter._material
	await _frames(30)
	for view: Array in VIEWS:
		player.global_position = view[1]
		player.reset_physics_interpolation()
		var dir: Vector3 = (view[2] - head.global_position).normalized()
		player.rotation.y = atan2(-dir.x, -dir.z)
		head.rotation.x = asin(dir.y)
		await _frames(20)
		for v: Array in VARIANTS:
			Game.settings.pixel_filter = v[1]
			Game.settings.pixel_strength = v[2]
			Game.settings.apply_pixel_filter()
			# 256 shades with no spread is the same as no limit at all.
			mat.set_shader_parameter("levels", 16.0 if v[3] else 256.0)
			mat.set_shader_parameter("spread", 0.5 if v[3] else 0.0)
			if not v[4]:
				RenderingServer.global_shader_parameter_set("pixel_texels", 0.0)
			await _frames(10)
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("%s/look_%s_%s.png" % [OUT, view[0], v[0]])
	mat.set_shader_parameter("levels", 16.0)
	mat.set_shader_parameter("spread", 0.5)
	Game.settings.pixel_filter = saved[0]
	Game.settings.pixel_strength = saved[1]
	Game.settings.apply_pixel_filter()
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
