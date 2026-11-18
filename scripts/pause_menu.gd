class_name PauseMenu
extends CanvasLayer
## Esc during a game: stops time and shows Resume / Settings / Restart / Quit.
##
## Its process_mode is Always (set in the .tscn), so it keeps running and
## receiving input while `get_tree().paused` freezes everything else. Because
## it runs even when the game isn't paused, every handler starts by checking
## `_open`.
##
## It owns the Esc key outright: pressing Esc opens it, pressing Esc again (or
## while in Settings, backing out first) closes it. The player script no longer
## touches the cursor itself.

var _open: bool = false
var _root: Control
var _panels: Control
var _settings: SettingsMenu = null


func _ready() -> void:
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Dim the game behind, so the panels read clearly over a busy room.
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks meant for the beam
	_root.add_child(dim)

	_panels = CenterContainer.new()
	_panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panels)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 90)
	_panels.add_child(column)

	var heading := UiStyle.label("Paused", UiStyle.TITLE_FONT_SIZE, UiStyle.CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.set_marble_drift(heading)
	column.add_child(heading)

	# The same glass words as the title screen, so pausing feels like the
	# same menu rather than a different one.
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	column.add_child(stack)

	var resume := MenuPanel.make_text("Resume")
	resume.pressed.connect(close)
	stack.add_child(resume)

	var settings := MenuPanel.make_text("Settings")
	settings.pressed.connect(_on_settings)
	stack.add_child(settings)

	var restart := MenuPanel.make_text("Restart")
	restart.pressed.connect(_on_restart)
	stack.add_child(restart)

	var quit := MenuPanel.make_text("Title")
	quit.pressed.connect(_on_quit_to_title)
	stack.add_child(quit)


func _unhandled_input(event: InputEvent) -> void:
	# "release_mouse" is Esc. ui_cancel is also Esc, and the settings page
	# handles that one to back out, so check this action rather than ui_cancel.
	if not event.is_action_pressed("release_mouse"):
		return
	get_viewport().set_input_as_handled()
	if _open:
		if _settings == null:
			close()
	else:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_root.visible = true
	get_tree().paused = true
	Game.capture_mouse(false)
	_set_hud_visible(false)


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	Game.capture_mouse(true)
	_set_hud_visible(true)


func _on_settings() -> void:
	if _settings != null:
		return
	_panels.visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(_on_settings_closed)
	_root.add_child(_settings)


func _on_settings_closed() -> void:
	_settings = null
	_panels.visible = true


func _on_restart() -> void:
	close()
	get_tree().reload_current_scene()


func _on_quit_to_title() -> void:
	_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


## Hides the crosshair and counters while paused, so the panels sit on a clean
## screen. The HUD puts itself in the "hud" group.
func _set_hud_visible(shown: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as CanvasLayer
	if hud != null:
		hud.visible = shown
