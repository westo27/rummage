extends Node
## Close-ups of the playroom's toy chest, jack-in-the-box, robot and action
## figures, the desk's pencil pot and globe, and the clothes in the wardrobe,
## shut and open (or spilled), to check their look by eye. Needs a real window.
## Run: Godot --path . --resolution 960x540 res://tests/shoot_toys.tscn

const OUT: String = "user://shots"

# name, camera position, what it looks at
const VIEWS: Array = [
	["toys_room", Vector3(-2.6, 1.25, 1.5), Vector3(-2.4, 0.4, -1.2)],
	["toys_chest", Vector3(-2.2, 0.95, -0.9), Vector3(-2.5, 0.3, -2.0)],
	["toys_jack", Vector3(-2.0, 1.0, 0.55), Vector3(-2.15, 0.86, 0.15)],
	["toys_robot", Vector3(-1.45, 0.42, -0.95), Vector3(-1.55, 0.17, -1.35)],
	["toys_figures", Vector3(-3.0, 0.35, 1.1), Vector3(-3.22, 0.09, 0.67)],
	["toys_desk", Vector3(1.25, 1.12, 1.15), Vector3(1.3, 0.85, 1.72)],
	["toys_wardrobe", Vector3(3.3, 1.35, 0.0), Vector3(4.78, 1.25, 0.0)],
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var player := main.get_node("Player") as CharacterBody3D
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	var view_camera := player.get_node("Head/Camera3D") as Camera3D
	# A camera of our own, free of the player, with the same lens.
	var camera := Camera3D.new()
	camera.fov = view_camera.fov
	main.add_child(camera)
	camera.make_current()
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _frames(60)
	# The wardrobe doors hidden, as if flung open, to see the clothes.
	for door_name in ["DoorA", "DoorB"]:
		(main.get_node("MainRoomProps/Wardrobe/" + door_name) as Node3D).visible = false
	for view: Array in VIEWS:
		await _shoot(camera, view[0], view[1], view[2])
	# Open: the chest's lid swung back, the jack sprung.
	var chest: Node = main.get_node("MainRoomProps/ToyChest")
	var lid := chest.lid as RigidBody3D
	# The teddy sat on the lid; set it on the floor beside the chest.
	var teddy := main.get_node("MainRoomProps/Teddy") as RigidBody3D
	teddy.global_position = Vector3(-1.95, 0.16, -1.85)
	teddy.reset_physics_interpolation()
	for i in 20:
		lid.sleeping = false
		lid.angular_velocity = Vector3(-14.0, 0.0, 0.0)
		await get_tree().physics_frame
	(main.get_node("MainRoomProps/JackInTheBox")).pop()
	# Knock the pencil pot over, and set the globe spinning.
	var pot := main.get_node("MainRoomProps/PencilPot") as RigidBody3D
	pot.linear_velocity = Vector3(-1.2, 1.2, -0.6)
	pot.angular_velocity = Vector3(6.0, 0.0, 4.0)
	var ball := main.get_node("MainRoomProps/DeskGlobe").ball as RigidBody3D
	ball.angular_velocity = ball.global_basis.y * 8.0
	await _frames(150)
	print("lid angle %.1f deg" % rad_to_deg(chest.lid_angle()))
	await _shoot(camera, "toys_chest_open", Vector3(-2.2, 1.2, -1.0), Vector3(-2.5, 0.25, -2.0))
	await _shoot(camera, "toys_jack_open", Vector3(-1.95, 1.0, 0.6), Vector3(-2.15, 0.93, 0.15))
	await _shoot(camera, "toys_desk_spill", Vector3(1.0, 1.25, 0.9), Vector3(1.2, 0.75, 1.65))
	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _shoot(camera: Camera3D, shot: String, from: Vector3, target: Vector3) -> void:
	camera.global_position = from
	camera.look_at(target)
	camera.reset_physics_interpolation()
	await _frames(15)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
