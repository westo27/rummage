extends Node
## Renders the three rooms from a few spots, to check the layout by eye.
## Needs a real window (no --headless).
## Run: Godot --path . --resolution 960x540 res://tests/shoot_rooms.tscn

const OUT: String = "user://shots"

# name, where the player stands, what they look at
const VIEWS: Array = [
	["room_start", Vector3(-2.6, 0.05, 1.5), Vector3(-2.6, 1.0, -2.2)],
	["room_playroom_ne", Vector3(-0.6, 0.05, -1.6), Vector3(-4.5, 0.4, 1.4)],
	["room_playroom_sw", Vector3(-4.3, 0.05, 0.6), Vector3(-0.5, 0.5, -1.2)],
	["room_bedroom_door", Vector3(0.5, 0.05, 0.3), Vector3(4.5, 0.6, -1.0)],
	["room_bedroom_se", Vector3(4.2, 0.05, 1.3), Vector3(1.0, 0.7, -1.8)],
	["room_bedroom_desk", Vector3(3.5, 0.05, -0.6), Vector3(1.0, 0.6, 1.8)],
	["room_box", Vector3(3.6, 0.05, 0.0), Vector3(8.2, 0.4, 0.0)],
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
	await _frames(30)
	for view: Array in VIEWS:
		if view[0] == "room_box":
			# Hide the wardrobe doors, as if flung open, so the box room shows
			# through the wardrobe.
			for door_name in ["DoorA", "DoorB"]:
				(main.get_node("MainRoomProps/Wardrobe/" + door_name) as Node3D).visible = false
		player.global_position = view[1]
		player.reset_physics_interpolation()
		_look(player, head, view[2])
		await _frames(20)
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [OUT, view[0]])
	# Lying flat in front of the bed, peering under it.
	Input.action_press("prone")
	player.global_position = Vector3(2.55, 0.05, 0.2)
	player.reset_physics_interpolation()
	await _frames(40)
	_look(player, head, Vector3(2.55, 0.1, -1.75))
	await _frames(20)
	get_viewport().get_texture().get_image().save_png("%s/room_under_bed.png" % OUT)
	Input.action_release("prone")
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _look(player: Node3D, head: Node3D, target: Vector3) -> void:
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
