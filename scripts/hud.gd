class_name Hud
extends CanvasLayer
## On-screen display. A CanvasLayer draws 2D UI on top of the 3D view.
## It only displays what it's told; it holds no game state of its own.
##
## Every in-play Control here has mouse_filter = Ignore, so none of them can
## swallow mouse clicks meant for the beam. The win screen is the exception:
## it's only shown once play is over, and its buttons need the clicks.

const TOAST_SECONDS: float = 3.5

var _toast_left: float = 0.0

@onready var _crosshair: Crosshair = $Crosshair
@onready var _aim_label: Label = $AimLabel
@onready var _lift_label: Label = $LiftLabel
@onready var _caught_label: Label = $CaughtLabel
@onready var _timer_label: Label = $TimerLabel
@onready var _ping_label: Label = $PingLabel
@onready var _toast_label: Label = $ToastLabel

## The win screen, built in code by _build_win_screen: a dimmed backdrop with a
## glossy card holding the heading, the time and two pills. Named WinPanel and
## WinLabel so tests can find them.
var _win_panel: Control
var _win_heading: Label
var _win_label: Label
var _play_again: MenuPanel


## Sizes here are in the project's 2560x1440 design space, which the window
## scales to fit, so the numbers are roughly twice what they look on a 1080p
## screen. The look (font, colours, pill backgrounds) comes from UiStyle, the
## same place the menus get theirs.
const READOUT_FONT_SIZE: int = 36
const AIM_FONT_SIZE: int = 34
const TOAST_FONT_SIZE: int = 44
const WIN_HEADING_FONT_SIZE: int = 104
const WIN_TIME_FONT_SIZE: int = 66


func _ready() -> void:
	# Lets the pause menu find and hide the HUD without a hard-coded path.
	add_to_group("hud")
	# The four corner readouts. They keep their dark outline rather than getting
	# a panel behind them: during play the walls are pale and the floor is dark,
	# and an outline survives both without putting boxes on screen.
	for label: Label in [_lift_label, _caught_label, _timer_label, _ping_label]:
		label.add_theme_font_override("font", UiStyle.font(600))
		label.add_theme_font_size_override("font_size", READOUT_FONT_SIZE)
		label.add_theme_color_override("font_color", UiStyle.CREAM)
		label.add_theme_constant_override("outline_size", 10)
	_aim_label.add_theme_constant_override("outline_size", 10)
	_aim_label.add_theme_font_override("font", UiStyle.font(600))
	_aim_label.add_theme_font_size_override("font_size", AIM_FONT_SIZE)
	_toast_label.add_theme_font_override("font", UiStyle.font(700))
	_toast_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	_toast_label.add_theme_color_override("font_color", UiStyle.AMBER)
	_toast_label.add_theme_constant_override("outline_size", 12)
	_build_win_screen()


func _build_win_screen() -> void:
	_win_panel = Control.new()
	_win_panel.name = "WinPanel"
	_win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.visible = false
	add_child(_win_panel)

	# Dims the room and catches stray clicks, so clicking beside the card
	# doesn't fire the grab beam.
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_panel.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(centre)

	var card := GlossyCard.new()
	card.name = "Card"
	card.accent = UiStyle.AMBER
	centre.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)

	_win_heading = UiStyle.label("", WIN_HEADING_FONT_SIZE, UiStyle.INK)
	_win_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_win_heading)

	_win_label = UiStyle.label("", WIN_TIME_FONT_SIZE, UiStyle.INK_SOFT, 600)
	_win_label.name = "WinLabel"
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_win_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 44.0)
	column.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	column.add_child(row)

	_play_again = MenuPanel.make_pill("loop", "Play again", UiStyle.AMBER)
	_play_again.custom_minimum_size = Vector2(600.0, 140.0)
	_play_again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	row.add_child(_play_again)

	var to_title := MenuPanel.make_pill("house", "Title", UiStyle.CORAL)
	to_title.custom_minimum_size = Vector2(600.0, 140.0)
	to_title.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn"))
	row.add_child(to_title)

	var hint := UiStyle.label("or press R", UiStyle.HINT_FONT_SIZE, UiStyle.INK_SOFT, 400)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		# Fade out over the last second.
		_toast_label.modulate.a = clampf(_toast_left, 0.0, 1.0)


func set_aim(state: Beam.AimState, detail: String) -> void:
	_crosshair.set_state(state)
	_aim_label.text = detail
	_aim_label.modulate = Color(1, 0.35, 0.3) if state == Beam.AimState.TOO_HEAVY else Color(1, 1, 1, 0.8)


func set_lift_limit(kg: float) -> void:
	_lift_label.text = "Lift: %.0f kg" % kg


func set_caught(caught: int, total: int) -> void:
	_caught_label.text = "Caught: %d / %d" % [caught, total]


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
func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_left = TOAST_SECONDS


func show_win(seconds: float, total: int) -> void:
	_win_heading.text = "All %d caught!" % total
	_win_label.text = "Time  %s" % format_time(seconds)
	_win_panel.visible = true
	# Hand the cursor back so the pills can be clicked. main.gd stops the
	# player grabbing it again on the next click.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_again.grab_focus.call_deferred()


## 125.34 -> "2:05.3"
static func format_time(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60]
