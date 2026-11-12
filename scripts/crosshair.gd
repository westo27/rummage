class_name Crosshair
extends Control
## Draws the crosshair in a shape and colour per beam state.
##
## _draw() is Godot's immediate-mode drawing hook for UI nodes. It only runs when
## queue_redraw() is called, not every frame.

var state: Beam.AimState = Beam.AimState.IDLE


func set_state(new_state: Beam.AimState) -> void:
	state = new_state
	queue_redraw()


func _draw() -> void:
	# This Control is centred on screen; its own centre is size / 2.
	var c: Vector2 = size * 0.5
	match state:
		Beam.AimState.IDLE:
			draw_circle(c, 2.5, Color(1, 1, 1, 0.75))
		Beam.AimState.CAN_GRAB:
			draw_arc(c, 11.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.45), 2.5)
			draw_circle(c, 2.0, Color(0.4, 1.0, 0.45))
		Beam.AimState.HOLDING:
			draw_arc(c, 15.0, 0.0, TAU, 32, Color(0.35, 0.85, 1.0), 3.0)
		Beam.AimState.TOO_HEAVY:
			var red := Color(1.0, 0.25, 0.2)
			draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), red, 3.5)
			draw_line(c + Vector2(-10, 10), c + Vector2(10, -10), red, 3.5)
		Beam.AimState.CREATURE:
			var yellow := Color(1.0, 0.9, 0.2)
			var pts := PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, 0), c + Vector2(0, 13), c + Vector2(-13, 0), c + Vector2(0, -13)])
			draw_polyline(pts, yellow, 3.0)
			draw_circle(c, 3.0, yellow)
