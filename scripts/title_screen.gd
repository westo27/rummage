extends Control
## The title screen: the game's name and three panels (Play, Settings, Quit).
##
## The background wash and the drifting blobs are drawn by this node itself
## rather than by child nodes, because a parent draws before its children and
## that's what puts them behind the panels.

## How many creature-coloured blobs drift about behind the menu.
const BLOB_COUNT: int = 14

var _blob_positions: Array[Vector2] = []
var _blob_velocities: Array[Vector2] = []
var _blob_radii: Array[float] = []
var _blob_colors: Array[Color] = []

var _panels: VBoxContainer
var _hint: Label
var _settings: SettingsMenu = null


func _ready() -> void:
	# Coming back from a game: the cursor was captured, and time may be paused.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_blobs()
	_build()


func _make_blobs() -> void:
	var area: Vector2 = Vector2(2560.0, 1440.0)
	for i in BLOB_COUNT:
		_blob_positions.append(Vector2(randf() * area.x, randf() * area.y))
		# Slow drift, a few tens of pixels a second.
		_blob_velocities.append(Vector2(randf_range(-26.0, 26.0), randf_range(-18.0, 18.0)))
		_blob_radii.append(randf_range(40.0, 150.0))
		var tint: Color = UiStyle.ACCENTS[i % UiStyle.ACCENTS.size()]
		_blob_colors.append(Color(tint, randf_range(0.05, 0.12)))


func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panels = VBoxContainer.new()
	_panels.alignment = BoxContainer.ALIGNMENT_CENTER
	_panels.add_theme_constant_override("separation", 10)
	centre.add_child(_panels)

	var title := UiStyle.label("Losing My\nMarbles!", UiStyle.TITLE_FONT_SIZE, UiStyle.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("line_spacing", 14)
	_panels.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 80.0)
	_panels.add_child(gap)

	# A stack of wide pills rather than a row of tiles: the long shape shows
	# the gloss off, and one column is easier to run down with the keyboard.
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 34)
	_panels.add_child(stack)

	var play := MenuPanel.make_pill("creature", "Play", UiStyle.AMBER)
	play.pressed.connect(_on_play)
	stack.add_child(play)

	var settings := MenuPanel.make_pill("sliders", "Settings", UiStyle.MINT)
	settings.pressed.connect(_on_settings)
	stack.add_child(settings)

	var quit := MenuPanel.make_pill("exit", "Quit", UiStyle.CORAL)
	quit.pressed.connect(_on_quit)
	stack.add_child(quit)

	_hint = UiStyle.label("WASD to move  ·  hold left mouse to grab  ·  Q to ping  ·  Esc to pause",
		UiStyle.HINT_FONT_SIZE, UiStyle.CREAM_SOFT, 400)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_left = -900.0
	_hint.offset_right = 900.0
	_hint.offset_top = -90.0
	_hint.offset_bottom = -40.0
	add_child(_hint)



func _process(delta: float) -> void:
	# Drift the blobs, bouncing them off the edges of the design area.
	var area: Vector2 = Vector2(2560.0, 1440.0)
	for i in _blob_positions.size():
		var p: Vector2 = _blob_positions[i] + _blob_velocities[i] * delta
		var v: Vector2 = _blob_velocities[i]
		if p.x < -200.0 or p.x > area.x + 200.0:
			v.x = -v.x
		if p.y < -200.0 or p.y > area.y + 200.0:
			v.y = -v.y
		_blob_velocities[i] = v
		_blob_positions[i] = p
	queue_redraw()


func _draw() -> void:
	var screen := Rect2(Vector2.ZERO, size)
	draw_texture_rect(UiStyle.gradient(), screen, false)
	for i in _blob_positions.size():
		draw_circle(_blob_positions[i], _blob_radii[i], _blob_colors[i])
	# Over the blobs, so the edges of the screen fall away and the middle
	# reads as lit.
	draw_texture_rect(UiStyle.vignette(), screen, false)


func _on_play() -> void:
	# change_scene_to_file replaces the whole current scene on the next frame.
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_settings() -> void:
	if _settings != null:
		return
	_panels.visible = false
	_hint.visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)


func _on_settings_closed() -> void:
	_settings = null
	_panels.visible = true
	_hint.visible = true


func _on_quit() -> void:
	get_tree().quit()
