class_name Crosshair
extends Control
## Draws the crosshair in a shape and colour per beam state.
##
## _draw() is Godot's immediate-mode drawing hook for UI nodes. It only runs when
## queue_redraw() is called, not every frame.
##
## Sizes are in the project's 2560x1440 design space (see Project Settings >
## Display), which the window scales to fit, so they look much bigger here than
## the pixel counts suggest.

## Every shape is drawn relative to this, so the whole crosshair can be scaled
## by changing one number.
const SCALE: float = 1.9

var state: Beam.AimState = Beam.AimState.IDLE


func set_state(new_state: Beam.AimState) -> void:
	state = new_state
	queue_redraw()


func _draw() -> void:
	# This Control is centred on screen; its own centre is size / 2.
	var c: Vector2 = size * 0.5
	var s: float = SCALE
	match state:
		Beam.AimState.IDLE:
			draw_circle(c, 2.5 * s, Color(1, 1, 1, 0.75))
		Beam.AimState.CAN_GRAB:
			draw_arc(c, 11.0 * s, 0.0, TAU, 32, UiStyle.MINT, 2.5 * s, true)
			draw_circle(c, 2.0 * s, UiStyle.MINT)
		Beam.AimState.HOLDING:
			draw_arc(c, 15.0 * s, 0.0, TAU, 32, UiStyle.SKY, 3.0 * s, true)
		Beam.AimState.TOO_HEAVY:
			draw_line(c + Vector2(-10, -10) * s, c + Vector2(10, 10) * s, UiStyle.CORAL, 3.5 * s, true)
			draw_line(c + Vector2(-10, 10) * s, c + Vector2(10, -10) * s, UiStyle.CORAL, 3.5 * s, true)
		Beam.AimState.CREATURE:
			var pts := PackedVector2Array([
				c + Vector2(0, -13) * s, c + Vector2(13, 0) * s, c + Vector2(0, 13) * s,
				c + Vector2(-13, 0) * s, c + Vector2(0, -13) * s])
			draw_polyline(pts, UiStyle.AMBER, 3.0 * s, true)
			draw_circle(c, 3.0 * s, UiStyle.AMBER)
