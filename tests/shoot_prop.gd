extends Node
## Close-up of one prop, for checking rounded edges. Needs a real window.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_prop.tscn -- <scene name> [tag]
## e.g. -- chest_of_drawers round. Writes <name>_<tag>_<off|360p>.png to user://shots.

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var prop_name: String = args[0] if args.size() > 0 else "bed"
	var tag: String = args[1] if args.size() > 1 else "now"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	await _frames(30)
	var prop: Node3D
	for p: Node in get_tree().get_nodes_in_group("props"):
		if p.scene_file_path.ends_with("/%s.tscn" % prop_name):
			prop = p
	# Stand a little off its front, a bit more than its width away.
	var width := 0.0
	for m in prop.find_children("*", "MeshInstance3D", true, false):
		width = maxf(width, (m as MeshInstance3D).get_aabb().size.x)
	var target := prop.global_position
	var offset := prop.global_basis * Vector3(0.35, 0, 0.94).normalized() * maxf(width * 1.3, 1.1)
	player.global_position = Vector3(target.x + offset.x, 0.05, target.z + offset.z)
	player.reset_physics_interpolation()
	await _frames(5)
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	Game.looks.set_wii_finish(true)
	for v: Array in [["off", false, 3], ["360p", true, 2]]:
		Game.looks.set_look("", v[1], v[2])
		await _frames(20)
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [OUT, prop_name, tag, v[0]])
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
