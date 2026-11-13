class_name FlyingBall
extends Node2D
## For the "flies into the bag" catch style: a ball in the caught creature's
## colour that arcs across the screen, from where it was caught up into the
## marble bag's neck, then lets the bag take over.
##
## It looks up the bag's neck every frame rather than once at the start,
## because the bag can move while it flies (the last catch moves the bag onto
## the win card).

signal arrived

const FLIGHT_SECONDS: float = 0.5
## How high the arc rises above a straight line, in design pixels.
const ARC_HEIGHT: float = 260.0
## Starts bigger, as if close to you in the room, and shrinks to bag size.
const START_SCALE: float = 1.8

var _from: Vector2
var _target: Callable
var _color: Color
var _t: float = 0.0
var _spin_speed: float = 0.0


## `target` is called each frame and returns where the bag's neck is now.
func setup(from: Vector2, target: Callable, color: Color) -> void:
	_from = from
	_target = target
	_color = color
	_spin_speed = randf_range(6.0, 10.0) * (1.0 if randf() < 0.5 else -1.0)
	position = from
	scale = Vector2.ONE * START_SCALE


func _process(delta: float) -> void:
	_t = minf(_t + delta / FLIGHT_SECONDS, 1.0)
	# Ease in and out, so it leaps off and settles into the bag.
	var eased: float = _t * _t * (3.0 - 2.0 * _t)
	var to: Vector2 = _target.call()
	# A quadratic curve whose middle point is lifted above the straight line.
	var control: Vector2 = (_from + to) * 0.5 + Vector2.UP * ARC_HEIGHT
	var u: float = 1.0 - eased
	position = u * u * _from + 2.0 * u * eased * control + eased * eased * to
	scale = Vector2.ONE * lerpf(START_SCALE, 1.0, eased)
	rotation += _spin_speed * delta
	queue_redraw()
	if _t >= 1.0:
		arrived.emit()
		queue_free()


func _draw() -> void:
	BagMarble.paint(self, _color, BagMarble.RADIUS, rotation)
