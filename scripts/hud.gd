class_name Hud
extends CanvasLayer
## On-screen display. A CanvasLayer draws 2D UI on top of the 3D view.
## It only displays what it's told; it holds no game state of its own.
##
## Every in-play Control here has mouse_filter = Ignore, so none of them can
## swallow mouse clicks meant for the beam. The win screen is the exception:
## it's only shown once play is over, and its buttons need the clicks.


@onready var _crosshair: Crosshair = $Crosshair
@onready var _lift_label: Label = $LiftLabel
@onready var _timer_label: Label = $TimerLabel
@onready var _ping_label: Label = $PingLabel

## The drawstring bag in the bottom-right corner that caught creatures drop
## into. See marble_bag.gd.
var _bag: MarbleBag
## "12 of 26" in glass text just above the bag.
var _count_label: Label
## The win screen, built in code by _build_win_screen: the room dimmed, with
## the bag, the heading, the time and two clickable glass words floating over
## it. Named WinPanel and WinLabel so tests can find them.
var _win_panel: Control
## Where the bag moves to on the win screen.
var _win_bag_slot: CenterContainer
var _win_heading: Label
var _win_label: Label
var _play_again: MenuPanel
## The one-at-a-time lesson prompt just above the crosshair, in glass words
## (tutorial.gd decides what it says).
var _hint_label: Label
var _hint_tween: Tween


## Sizes here are in the project's 2560x1440 design space, which the window
## scales to fit, so the numbers are roughly twice what they look on a 1080p
## screen. The look (font, colours, glass text) comes from UiStyle, the same
## place the menus get theirs.
const READOUT_FONT_SIZE: int = 36
const WIN_HEADING_FONT_SIZE: int = 104
const WIN_TIME_FONT_SIZE: int = 66
## Gap between the marble bag and the bottom-right corner of the screen.
const BAG_MARGIN := Vector2(40.0, 16.0)
## How far the catch count sits down into the bag's box (its top is empty
## space above the neck).
const COUNT_DROP: float = 70.0
const HINT_FONT_SIZE: int = 64
## How far down from the top of the screen the hint sits: a little above
## the crosshair (720), close to where you're looking without covering it.
const HINT_TOP: float = 460.0
const HINT_FADE: float = 0.25


func _ready() -> void:
	# Lets the pause menu find and hide the HUD without a hard-coded path.
	add_to_group("hud")
	# The corner readouts, in the same glass text as the menus.
	for label: Label in [_lift_label, _timer_label, _ping_label]:
		label.add_theme_font_override("font", UiStyle.font())
		label.add_theme_font_size_override("font_size", READOUT_FONT_SIZE)
		label.add_theme_color_override("font_color", UiStyle.CREAM)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiStyle.marble_label(label)
	# Furniture is fixed and everything else is light, so there's no lift
	# limit worth showing.
	_lift_label.visible = false
	_build_bag()
	_build_count()
	_build_hint()
	# Built after the bag, so the win screen's dimming covers it.
	_build_win_screen()


func _build_bag() -> void:
	_bag = MarbleBag.new()
	_bag.name = "MarbleBag"
	# Pinned to the bottom-right corner: all four anchors at (1, 1), so the
	# offsets are measured back from that corner.
	_bag.anchor_left = 1.0
	_bag.anchor_top = 1.0
	_bag.anchor_right = 1.0
	_bag.anchor_bottom = 1.0
	_bag.offset_left = -BAG_MARGIN.x - MarbleBag.DISPLAY_SIZE.x
	_bag.offset_top = -BAG_MARGIN.y - MarbleBag.DISPLAY_SIZE.y
	_bag.offset_right = -BAG_MARGIN.x
	_bag.offset_bottom = -BAG_MARGIN.y
	add_child(_bag)


func _build_count() -> void:
	_count_label = UiStyle.label("", READOUT_FONT_SIZE, UiStyle.CREAM)
	_count_label.name = "CountLabel"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Same column as the bag, sitting on top of it.
	_count_label.anchor_left = 1.0
	_count_label.anchor_top = 1.0
	_count_label.anchor_right = 1.0
	_count_label.anchor_bottom = 1.0
	_count_label.offset_left = _bag.offset_left
	_count_label.offset_right = _bag.offset_right
	_count_label.offset_bottom = _bag.offset_top + COUNT_DROP
	_count_label.offset_top = _count_label.offset_bottom - READOUT_FONT_SIZE * 1.6
	add_child(_count_label)


func _build_hint() -> void:
	# Full width, centred, so any length of hint fits.
	_hint_label = UiStyle.label("", HINT_FONT_SIZE, UiStyle.CREAM)
	_hint_label.name = "Hint"
	_hint_label.anchor_right = 1.0
	_hint_label.offset_top = HINT_TOP
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate.a = 0.0
	_hint_label.visible = false
	add_child(_hint_label)


## Shows a lesson prompt, fading out the old one first if there was one.
func show_hint(text: String) -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	# A Tween animates properties over time; its steps run one after another.
	_hint_tween = create_tween()
	if _hint_label.visible and _hint_label.modulate.a > 0.0:
		_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, HINT_FADE)
	_hint_tween.tween_callback(func() -> void:
		_hint_label.text = text
		_hint_label.visible = true)
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, HINT_FADE)


func hide_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, HINT_FADE)
	_hint_tween.tween_callback(func() -> void: _hint_label.visible = false)


## What the hint says, or "" when it's hidden. For tests.
func hint_text() -> String:
	return _hint_label.text if _hint_label.visible else ""


## Drops a ball of this colour and face into the bag. Called by main.gd on
## each catch.
func add_to_bag(color: Color, face: DoodleFace) -> void:
	_bag.drop(color, face)


func _build_win_screen() -> void:
	_win_panel = Control.new()
	_win_panel.name = "WinPanel"
	_win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.visible = false
	add_child(_win_panel)

	# Dims the room so the glass words read, and catches stray clicks, so
	# clicking beside the words doesn't fire the grab beam.
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.08, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(centre)

	# The bag on the left, the words on the right.
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 80)
	centre.add_child(content)

	# Empty until show_win moves the bag in from the corner.
	_win_bag_slot = CenterContainer.new()
	_win_bag_slot.name = "BagSlot"
	_win_bag_slot.custom_minimum_size = MarbleBag.DISPLAY_SIZE
	content.add_child(_win_bag_slot)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(column)

	_win_heading = UiStyle.label("", WIN_HEADING_FONT_SIZE, UiStyle.CREAM)
	_win_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.set_marble_drift(_win_heading)
	column.add_child(_win_heading)

	_win_label = UiStyle.label("", WIN_TIME_FONT_SIZE, UiStyle.CREAM_SOFT)
	_win_label.name = "WinLabel"
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_win_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 30.0)
	column.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	column.add_child(row)

	_play_again = MenuPanel.make_text("Play again", 96)
	_play_again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	row.add_child(_play_again)

	var to_title := MenuPanel.make_text("Title", 96)
	to_title.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn"))
	row.add_child(to_title)

	var hint := UiStyle.label("or press R", UiStyle.HINT_FONT_SIZE, UiStyle.CREAM_SOFT, 400)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## Only the crosshair shows the aim now; the text under it was removed.
func set_aim(state: Beam.AimState, _detail: String) -> void:
	_crosshair.set_state(state)


func set_lift_limit(kg: float) -> void:
	_lift_label.text = "Lift: %.0f kg" % kg


func set_caught(caught: int, total: int) -> void:
	_bag.set_count(caught, total)
	# Coiny draws "/" leaning back, so the label says "of".
	_count_label.text = "%d of %d" % [caught, total]


## What the catch counter currently says, e.g. "12 / 25". For tests.
func caught_text() -> String:
	return _bag.count_text()


func set_time(seconds: float) -> void:
	_timer_label.text = format_time(seconds)


func set_ping_cooldown(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_ping_label.text = "Ping ready  [Q]"
		_ping_label.modulate = Color(1, 1, 1, 1)
	else:
		_ping_label.text = "Ping  %.0fs" % ceilf(seconds_left)
		_ping_label.modulate = Color(1, 1, 1, 0.5)


## A short message near the top of the screen that fades out by itself.
func show_win(seconds: float, total: int) -> void:
	_win_heading.text = "All %d caught!" % total
	_win_label.text = "Time  %s" % format_time(seconds)
	# Move the bag, balls and all, from the corner onto the win screen. reparent()
	# keeps its whole subtree, including its own little physics world, so any
	# balls still queued keep dropping in there.
	_bag.reparent(_win_bag_slot, false)
	_count_label.visible = false
	_win_panel.visible = true
	# Nothing floats over the words: no lesson hint, no crosshair.
	_hint_label.visible = false
	_crosshair.visible = false
	# Hand the cursor back so the words can be clicked. main.gd stops the
	# player grabbing it again on the next click.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 125.34 -> "2:05.3"
static func format_time(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60]
