extends Node
## Renders the new hiding places up close, to check their look by eye.
## Needs a real window (no --headless).
## Run: Godot --path . --resolution 960x540 res://tests/shoot_hiding.tscn

const OUT: String = "user://shots"

# name, where the player stands, what they look at
const VIEWS: Array = [
	["hide_bowl", Vector3(-1.5, 0.05, 1.2), Vector3(-2.35, 0.08, 1.85)],
	["hide_rug_lump", Vector3(-3.1, 0.05, 1.45), Vector3(-2.4, 0.05, 0.62)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	var head := player.get_node("Head") as Node3D
	player.set_process_unhandled_input(false)
	await _frames(120)  # the room settles and the rug drapes over its lump
	for view: Array in VIEWS:
		player.global_position = view[1]
		player.reset_physics_interpolation()
		_look(player, head, view[2])
		await _frames(20)
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, view[0]])
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _look(player: Node3D, head: Node3D, target: Vector3) -> void:
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
