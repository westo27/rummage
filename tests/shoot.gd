extends Node
## Throwaway: renders the menus to PNGs so they can be looked at without
## playing. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1600x900 res://tests/shoot.tscn

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)

	var title: Control = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _frames(12)
	_shoot("title")

	# The settings page, opened as if clicked.
	for panel in _panels(title):
		if panel.label_text == "Settings":
			panel.pressed.emit()
	await _frames(12)
	_shoot("settings")
	title.queue_free()
	await _frames(4)

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	# Ignore the real mouse while rendering, so it can't swing the camera.
	main.get_node("Player").set_process_unhandled_input(false)
	await _frames(60)
	_shoot("game")

	# The lamp, swinging after a book is thrown at it.
	var book := main.get_node("MainRoomProps/ShelfBook02") as Prop
	book.global_position = Vector3(2.6, 2.27, 1.35)
	book.linear_velocity = Vector3(1.0, 0.0, -12.0)
	book.sleeping = false
	book.reset_physics_interpolation()
	await get_tree().create_timer(0.45).timeout
	_shoot("lamp_swing")
	await get_tree().create_timer(4.0).timeout

	# Fill the bag partway and let the pile settle.
	var hud := main.get_node("HUD") as Hud
	for i in 14:
		hud.add_to_bag(Creature.BODY_COLORS[i % Creature.BODY_COLORS.size()])
	hud.set_caught(14, 25)
	await get_tree().create_timer(4.5).timeout
	_shoot("bag")
	# The bag's own render, at full size, for checking the detail.
	hud._bag._viewport.get_texture().get_image().save_png("%s/bag_closeup.png" % OUT)
	# And completely full, as at the end of a game.
	for i in 11:
		hud.add_to_bag(Creature.BODY_COLORS[(i + 3) % Creature.BODY_COLORS.size()])
	hud.set_caught(25, 25)
	await get_tree().create_timer(4.0).timeout
	hud._bag._viewport.get_texture().get_image().save_png("%s/bag_full.png" % OUT)
	# A catch: a creature put in front of the camera and caught; sparkles
	# first, then the creature partway into the beam's hand.
	var player := main.get_node("Player") as Node3D
	var creature := main.get_node("MainRoomCreatures").get_child(0) as Creature
	var ahead: Vector3 = player.global_position - player.global_basis.z * 2.2
	creature.global_position = Vector3(ahead.x, 0.1, ahead.z)
	creature.reset_physics_interpolation()
	await _frames(3)
	(main.get_node("Player/Head/Camera3D/Beam") as Beam)._capture(creature)
	await get_tree().create_timer(0.12).timeout
	_shoot("catch_sparkles")
	await get_tree().create_timer(0.05).timeout
	_shoot("catch_suck")
	await get_tree().create_timer(1.0).timeout

	# The beam: holding a crate up, then straining red against the bed.
	var beam := main.get_node("Player/Head/Camera3D/Beam") as Beam
	var head := player.get_node("Head") as Node3D
	var crate := main.get_node("MainRoomProps/CrateA") as Prop
	crate.global_position = Vector3(3.0, 0.3, -0.6)  # out on the open bedroom floor
	await get_tree().create_timer(0.4).timeout
	player.global_position = Vector3(3.0, 0.05, 1.5)
	player.reset_physics_interpolation()
	_look(player, head, crate.global_position + Vector3(0.0, 0.3, 0.0))
	await _frames(3)
	beam._grab_armed = true
	beam._grab(crate, crate.global_position + Vector3(0.0, 0.3, 0.0))
	_look(player, head, Vector3(2.8, 1.0, -0.1))
	await get_tree().create_timer(0.8).timeout
	_shoot("beam_hold")
	if beam.held != null:
		beam._release()
	# Let go of the button first, or the beam grabs whatever it passes over
	# (a pillow) on the way to the bed.
	beam._grab_armed = false
	var bed := main.get_node("MainRoomProps/Bed") as Prop
	player.global_position = Vector3(2.85, 0.05, 0.75)
	player.reset_physics_interpolation()
	_look(player, head, bed.global_position + Vector3(0.3, 0.2, 0.0))
	await _frames(3)
	beam._grab_armed = true
	beam._rejected = bed
	beam._rejected_local = bed.to_local(bed.global_position + Vector3(0.3, 0.2, 0.3))
	await get_tree().create_timer(0.3).timeout
	_shoot("beam_strain")
	beam._rejected = null
	beam._grab_armed = false

	var pause := main.get_node("PauseMenu") as PauseMenu
	pause.open()
	await _frames(12)
	_shoot("pause")
	for panel in _panels(pause):
		if panel.label_text == "Settings":
			panel.pressed.emit()
	await _frames(12)
	_shoot("pause_settings")

	pause.close()
	(main.get_node("HUD") as Hud).show_win(187.4, 25)
	await _frames(12)
	_shoot("win")

	print("Wrote PNGs to %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _shoot(name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT, name])


func _panels(root: Node) -> Array[MenuPanel]:
	var found: Array[MenuPanel] = []
	for child in root.get_children():
		if child is MenuPanel:
			found.append(child as MenuPanel)
		found.append_array(_panels(child))
	return found


func _look(player: Node3D, head: Node3D, target: Vector3) -> void:
	var dir: Vector3 = (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = asin(dir.y)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
