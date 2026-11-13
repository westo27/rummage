extends Node
## Throwaway: renders the menus to PNGs so they can be looked at without
## playing. Needs a real window (no --headless).
## Run: Godot --path . --resolution 1600x900 res://tests/shoot.tscn

const OUT: String = "user://shots"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)

	# The mouse cursor, blown up 4x so its detail can be seen.
	await _frames(4)
	if PointerCursor.image != null:
		var big: Image = PointerCursor.image.duplicate()
		big.resize(PointerCursor.CURSOR_SIZE * 4, PointerCursor.CURSOR_SIZE * 4, Image.INTERPOLATE_NEAREST)
		big.save_png("%s/cursor.png" % OUT)

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
	await _frames(60)
	_shoot("game")

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
	# A catch in the "flies into the bag" style: a creature put in front of
	# the camera, caught; sparkles first, then the ball partway to the bag.
	Game.catch_style = Game.CatchStyle.FLY_TO_BAG
	var player := main.get_node("Player") as Node3D
	var creature := main.get_node("MainRoomCreatures").get_child(0) as Creature
	var ahead: Vector3 = player.global_position - player.global_basis.z * 2.2
	creature.global_position = Vector3(ahead.x, 0.1, ahead.z)
	creature.reset_physics_interpolation()
	await _frames(3)
	(main.get_node("Player/Head/Camera3D/Beam") as Beam)._capture(creature)
	await get_tree().create_timer(0.12).timeout
	_shoot("catch_sparkles")
	await get_tree().create_timer(0.3).timeout
	_shoot("catch_flying")
	await get_tree().create_timer(1.0).timeout

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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
