class_name SettingsMenu
extends Control
## The settings page, shared by the title screen and the pause menu.
##
## Built in code rather than as a .tscn, because it's a list of near-identical
## rows: a name, a minus panel, the current value, a plus panel. Steppers
## instead of sliders so every control is the same big point-and-click panel
## and nothing needs dragging.
##
## Changes apply immediately and are written to disk when the page closes.

signal closed

## The width of a setting row (name, two steppers, value, gaps), so the
## section headings line up with the rows' left edge.
const ROW_WIDTH: float = 620.0 + 110.0 + 240.0 + 110.0 + 26.0 * 3

var _value_labels: Dictionary = {}
var _column: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Placed and scaled by _fit rather than a CenterContainer, because
	# containers reset their children's scale.
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 20)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var heading := UiStyle.label("Settings", 96, UiStyle.CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 20.0)
	column.add_child(spacer)

	column.add_child(_build_section("Controls"))
	column.add_child(_build_row("look", "Look sensitivity"))
	column.add_child(_build_row("invert", "Invert look (Y)"))
	column.add_child(_build_section("Sound"))
	column.add_child(_build_row("volume", "Volume"))
	column.add_child(_build_section("Graphics"))
	column.add_child(_build_row("lighting", "Lighting"))
	column.add_child(_build_row("pixel", "Pixel filter"))
	column.add_child(_build_row("pixel_strength", "Pixel size"))
	column.add_child(_build_row("dither", "Dither"))

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
	resized.connect(_fit)
	_column.resized.connect(_fit)
	_fit.call_deferred()


## Centres the page, shrinking it to fit when the screen is shorter than it
## (a smaller design size, or a wide window with "expand"). scale draws it
## smaller without changing its layout.
func _fit() -> void:
	var needed: Vector2 = _column.get_combined_minimum_size()
	_column.size = needed
	var room: Vector2 = size * 0.94
	var s: float = minf(1.0, minf(room.x / needed.x, room.y / needed.y))
	_column.scale = Vector2.ONE * s
	_column.position = (size - needed * s) * 0.5


## A small heading over a group of rows, lined up with their left edge.
func _build_section(title: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := UiStyle.label(title, 40, UiStyle.CREAM_SOFT, 700)
	label.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	row.add_child(label)
	return row


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
	return row


func _adjust(key: String, by: int) -> void:
	match key:
		"look":
			Game.settings.adjust_sensitivity(by)
		"volume":
			Game.settings.adjust_volume(by)
		"invert":
			Game.settings.invert_look = not Game.settings.invert_look
		"lighting":
			Game.settings.adjust_lighting(by)
			# Straight away, so from the pause menu you see the change.
			Game.settings.apply_lighting(get_tree().current_scene)
		"pixel":
			Game.settings.pixel_filter = not Game.settings.pixel_filter
			Game.settings.apply_pixel_filter()
		"pixel_strength":
			Game.settings.adjust_pixel_strength(by)
			Game.settings.apply_pixel_filter()
		"dither":
			Game.settings.pixel_dither = not Game.settings.pixel_dither
			Game.settings.apply_pixel_filter()
	_refresh()


func _refresh() -> void:
	(_value_labels["look"] as Label).text = str(Game.settings.sensitivity_step)
	(_value_labels["volume"] as Label).text = "%d%%" % Game.settings.volume_percent
	(_value_labels["invert"] as Label).text = "On" if Game.settings.invert_look else "Off"
	(_value_labels["lighting"] as Label).text = Settings.LIGHTING_NAMES[Game.settings.lighting]
	(_value_labels["pixel"] as Label).text = "On" if Game.settings.pixel_filter else "Off"
	(_value_labels["pixel_strength"] as Label).text = str(Game.settings.pixel_strength)
	(_value_labels["dither"] as Label).text = "On" if Game.settings.pixel_dither else "Off"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Game.settings.save()
	closed.emit()
	queue_free()
