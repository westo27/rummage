class_name CreditsPage
extends Control
## The credits, opened from the title screen: who made it and the licences
## the game ships under. Laid out like the settings page (centred column,
## glass Back word, Esc closes).

signal closed

## Each entry is a soft heading and the lines under it.
const ENTRIES: Array = [
	["Made by", ["Tom Weston"]],
	["Tested by", ["Grace Weston (Love you)"]],
	["Built with", ["Godot Engine (MIT licence)", "© Juan Linietsky, Ariel Manzur and contributors", "Jolt Physics (MIT licence) © Jorrit Rouwe"]],
	["Font", ["Coiny by Marcelo Magalhães", "SIL Open Font License 1.1"]],
	["Sounds", ["Made in code, for this game"]],
]

var _column: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_column)

	var heading := UiStyle.label("Credits", 96, UiStyle.CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.set_marble_drift(heading)
	_column.add_child(heading)

	for entry in ENTRIES:
		_add_gap(30.0)
		var title := UiStyle.label(entry[0], 40, UiStyle.CREAM_SOFT, 700)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(title)
		for line: String in entry[1]:
			var l := UiStyle.label(line, UiStyle.ROW_FONT_SIZE, UiStyle.CREAM, 600)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_column.add_child(l)

	_add_gap(50.0)
	var back := MenuPanel.make_text("Back", 96)
	back.pressed.connect(_close)
	var back_row := CenterContainer.new()
	back_row.add_child(back)
	_column.add_child(back_row)

	resized.connect(_fit)
	_column.resized.connect(_fit)
	_fit.call_deferred()


func _add_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	_column.add_child(gap)


## Centres the column, shrinking it on short screens (same as SettingsMenu).
func _fit() -> void:
	var needed: Vector2 = _column.get_combined_minimum_size()
	_column.size = needed
	var room: Vector2 = size * 0.94
	var s: float = minf(1.0, minf(room.x / needed.x, room.y / needed.y))
	_column.scale = Vector2.ONE * s
	_column.position = (size - needed * s) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
