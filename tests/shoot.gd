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
	await _frames(60)
	_shoot("game")
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
