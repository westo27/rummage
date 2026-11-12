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
