class_name Hud
extends CanvasLayer
## On-screen display. A CanvasLayer draws 2D UI on top of the 3D view.
## It only displays what it's told; it holds no game state of its own.
##
## Every Control here has mouse_filter = Ignore, so none of them can swallow
## mouse clicks meant for the beam.

const TOAST_SECONDS: float = 3.5

var _toast_left: float = 0.0

@onready var _crosshair: Crosshair = $Crosshair
@onready var _aim_label: Label = $AimLabel
@onready var _lift_label: Label = $LiftLabel
@onready var _caught_label: Label = $CaughtLabel
@onready var _timer_label: Label = $TimerLabel
@onready var _ping_label: Label = $PingLabel
@onready var _toast_label: Label = $ToastLabel
@onready var _win_panel: PanelContainer = $WinPanel
@onready var _win_label: Label = $WinPanel/WinLabel


## Sizes here are in the project's 2560x1440 design space, which the window
## scales to fit, so the numbers are roughly twice what they look on a 1080p
## screen. The look (font, colours, pill backgrounds) comes from UiStyle, the
## same place the menus get theirs.
const READOUT_FONT_SIZE: int = 36
const AIM_FONT_SIZE: int = 34
const TOAST_FONT_SIZE: int = 44
const WIN_FONT_SIZE: int = 50


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
	for label: Label in [_toast_label, _win_label]:
		label.add_theme_font_override("font", UiStyle.font(700))
	_toast_label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	_toast_label.add_theme_color_override("font_color", UiStyle.AMBER)
	_toast_label.add_theme_constant_override("outline_size", 12)
	_win_label.add_theme_font_size_override("font_size", WIN_FONT_SIZE)
	_win_label.add_theme_color_override("font_color", UiStyle.CREAM)
	_win_panel.add_theme_stylebox_override("panel", UiStyle.panel_box(
		Color(0.06, 0.12, 0.14, 0.92), 28, 20.0))


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
	_win_label.text = "All %d caught!\n\nTime  %s\n\nPress R to play again" % [total, format_time(seconds)]
	_win_panel.visible = true


## 125.34 -> "2:05.3"
static func format_time(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60]
