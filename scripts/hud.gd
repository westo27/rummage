class_name Hud
extends CanvasLayer
## On-screen display. A CanvasLayer draws 2D UI on top of the 3D view.
## It only displays what it's told; it holds no game state of its own.

@onready var _crosshair: Crosshair = $Crosshair
@onready var _aim_label: Label = $AimLabel
@onready var _lift_label: Label = $LiftLabel


func set_aim(state: Beam.AimState, detail: String) -> void:
	_crosshair.set_state(state)
	_aim_label.text = detail
	_aim_label.modulate = Color(1, 0.35, 0.3) if state == Beam.AimState.TOO_HEAVY else Color(1, 1, 1, 0.8)


func set_lift_limit(kg: float) -> void:
	_lift_label.text = "Lift: %.0f kg" % kg
