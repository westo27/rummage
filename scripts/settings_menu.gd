class_name SettingsMenu
extends Control
## The settings page, shared by the title screen and the pause menu.
##
## Built in code rather than as a .tscn, because it's a list of near-identical
## rows: a name, a minus panel, the current value, a plus panel. Steppers
## instead of sliders so every control is the same big aim-and-click panel, and
## so it works the same with a mouse, the keyboard or a pad.
##
## Changes apply immediately and are written to disk when the page closes.

signal closed

var _value_labels: Dictionary = {}
var _first_panel: MenuPanel = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 34)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)

	var heading := UiStyle.label("Settings", 96, UiStyle.CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 20.0)
	column.add_child(spacer)

	column.add_child(_build_row("look", "Look sensitivity"))
	column.add_child(_build_row("invert", "Invert look (Y)"))
	column.add_child(_build_row("volume", "Volume"))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, 40.0)
	column.add_child(spacer2)

	var back := MenuPanel.make_pill("back", "Back", UiStyle.MINT)
	back.custom_minimum_size = Vector2(560.0, 140.0)
	back.pressed.connect(_close)
	var back_row := CenterContainer.new()
	back_row.add_child(back)
	column.add_child(back_row)

	_refresh()
	# Give the first stepper keyboard focus, so arrow keys and Enter work
	# without touching the mouse.
	if _first_panel != null:
		_first_panel.grab_focus.call_deferred()


## One setting: name on the left, then [-] value [+].
func _build_row(key: String, name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := UiStyle.label(name, UiStyle.ROW_FONT_SIZE, UiStyle.CREAM, 600)
	name_label.custom_minimum_size = Vector2(620.0, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Right-aligned so every name ends just before its steppers, however long.
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	# A real minus sign, not a hyphen, so it matches the weight of the plus.
	var down := MenuPanel.make_stepper("−")
	down.pressed.connect(_adjust.bind(key, -1))
	row.add_child(down)

	var value := UiStyle.label("", UiStyle.ROW_FONT_SIZE, UiStyle.CREAM)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.custom_minimum_size = Vector2(240.0, 110.0)
	value.add_theme_stylebox_override("normal", UiStyle.plate_box())
	_value_labels[key] = value
	row.add_child(value)

	var up := MenuPanel.make_stepper("+")
	up.pressed.connect(_adjust.bind(key, 1))
	row.add_child(up)

	if _first_panel == null:
		_first_panel = down
	return row


func _adjust(key: String, by: int) -> void:
	match key:
		"look":
			Game.settings.adjust_sensitivity(by)
		"volume":
			Game.settings.adjust_volume(by)
		"invert":
			Game.settings.invert_look = not Game.settings.invert_look
	_refresh()


func _refresh() -> void:
	(_value_labels["look"] as Label).text = str(Game.settings.sensitivity_step)
	(_value_labels["volume"] as Label).text = "%d%%" % Game.settings.volume_percent
	(_value_labels["invert"] as Label).text = "On" if Game.settings.invert_look else "Off"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Game.settings.save()
	closed.emit()
	queue_free()
