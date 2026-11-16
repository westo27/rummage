extends Control
## The title screen: the game's name and three clickable words (Play, Settings,
## Quit) over the real bedroom at night (TitleBackdrop), and a small Credits
## word in the corner.
##
## The shade that keeps the words readable is drawn by this node itself, over
## the 3D room (the canvas always draws over 3D) and under the menu, because a
## parent draws before its children.

var _panels: VBoxContainer
var _hint: Label
var _credits_word: MenuPanel
var _version: Label
## The settings or credits page while one is open.
var _page: Control = null


func _ready() -> void:
	# Coming back from a game: the cursor was captured, and time may be paused.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TitleBackdrop.new())
	_build()


func _build() -> void:
	var centre := CenterContainer.new()
	# The left part of the screen only, so the room shows on the right, set in
	# from the edge so the title has room to breathe.
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.anchor_left = 0.07
	centre.offset_left = 0.0
	centre.anchor_right = 0.5
	centre.offset_right = 0.0
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panels = VBoxContainer.new()
	_panels.alignment = BoxContainer.ALIGNMENT_CENTER
	_panels.add_theme_constant_override("separation", 10)
	centre.add_child(_panels)

	var title := UiStyle.label("I’m Losing My\nMarbles!", UiStyle.TITLE_FONT_SIZE, UiStyle.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("line_spacing", 14)
	UiStyle.set_marble_drift(title)
	_panels.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 80.0)
	_panels.add_child(gap)

	# Just the words, in the same glass as the title, stacked in one column.
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	_panels.add_child(stack)

	var play := MenuPanel.make_text("Play")
	play.pressed.connect(_on_play)
	stack.add_child(play)

	var settings := MenuPanel.make_text("Settings")
	settings.pressed.connect(_on_settings)
	stack.add_child(settings)

	var quit := MenuPanel.make_text("Quit")
	quit.pressed.connect(_on_quit)
	stack.add_child(quit)

	_hint = UiStyle.label("WASD to move  ·  C crouch  ·  Z lie down  ·  hold left mouse to grab  ·  Q to ping  ·  Esc to pause",
		UiStyle.HINT_FONT_SIZE, UiStyle.CREAM_SOFT, 400)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_left = -900.0
	_hint.offset_right = 900.0
	_hint.offset_top = -90.0
	_hint.offset_bottom = -40.0
	add_child(_hint)

	# Small, tucked into the bottom-right corner, clear of the controls hint.
	_credits_word = MenuPanel.make_text("Credits", 48)
	_credits_word.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_credits_word.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_credits_word.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_credits_word.offset_right = -40.0
	_credits_word.offset_bottom = -36.0
	_credits_word.pressed.connect(_on_credits)
	add_child(_credits_word)

	# The version from Project Settings (release.sh stamps it), faint in the
	# bottom-left corner so playtesters can say which build they're on.
	_version = UiStyle.label("v" + str(ProjectSettings.get_setting("application/config/version", "")),
		24, UiStyle.CREAM_SOFT, 400)
	_version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_version.offset_left = 40.0
	_version.offset_bottom = -40.0
	add_child(_version)

func _draw() -> void:
	if _page != null:
		# A page fills the middle, so dim the whole room behind it.
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiStyle.SHADE, 0.72))
	else:
		draw_texture_rect(UiStyle.title_shade(), Rect2(Vector2.ZERO, size), false)


func _on_play() -> void:
	# change_scene_to_file replaces the whole current scene on the next frame.
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_settings() -> void:
	_open_page(SettingsMenu.new())


func _on_credits() -> void:
	_open_page(CreditsPage.new())


## Hides the title's own words and shows `page` until it emits `closed`.
func _open_page(page: Control) -> void:
	if _page != null:
		page.free()
		return
	_set_title_visible(false)
	_page = page
	page.connect("closed", _on_page_closed)
	add_child(page)
	queue_redraw()


func _on_page_closed() -> void:
	_page = null
	_set_title_visible(true)
	queue_redraw()


func _set_title_visible(on: bool) -> void:
	_panels.visible = on
	_hint.visible = on
	_credits_word.visible = on
	_version.visible = on


func _on_quit() -> void:
	get_tree().quit()
