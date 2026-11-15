extends Node
## Close-up of the bed, for checking rounded edges. Needs a real window.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_bed.tscn [-- tag]
## Writes bed_<tag>_<off|360p>.png to user://shots.

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "now"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	await _frames(30)
	var bed: Node3D
	for prop: Node in get_tree().get_nodes_in_group("props"):
		if prop.scene_file_path.ends_with("bed.tscn"):
			bed = prop
	# Stand off the foot corner of the bed, looking at its middle.
	var target := bed.global_position + Vector3(0, 0.15, 0)
	player.global_position = bed.to_global(Vector3(1.9, 0, 1.5)) * Vector3(1, 0, 1) + Vector3(0, 0.05, 0)
	player.reset_physics_interpolation()
	await _frames(5)
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)
	Game.looks.set_wii_finish(true)
	for v: Array in [["off", false, 3], ["360p", true, 2]]:
		Game.looks.set_look("", v[1], v[2])
		await _frames(20)
		get_viewport().get_texture().get_image().save_png("%s/bed_%s_%s.png" % [OUT, tag, v[0]])
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
