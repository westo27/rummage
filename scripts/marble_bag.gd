class_name MarbleBag
extends SubViewportContainer
## A drawstring bag in the corner of the HUD. Every creature you catch drops
## into it as a ball with eyes (BagMarble) and piles up with the others, like
## a bag of marbles.
##
## It's a little world of its own. A SubViewport renders its own scene and,
## importantly, has its own 2D physics space, so the marbles can tumble about
## without touching the 3D game. The SubViewportContainer shows that render
## as an ordinary UI element, anchored like any other Control.
##
## Drawing order inside the viewport, back to front:
##   _back     the inside of the bag (dark), and the far rim of the opening
##   _marbles  the balls
##   _front    the see-through net body, the gathered neck, the flared top
##             (whose near rim hides a ball as it drops in), and the bow
##
## The bag's shape is one function, _outline(), used both for drawing and for
## the walls the marbles collide with, so the two can't disagree.

const VIEW_SIZE := Vector2(360.0, 470.0)
const CENTRE_X: float = 180.0
## Where the neck (the drawstring) sits, and how tall the body below it is.
const NECK_Y: float = 158.0
const BODY_HEIGHT: float = 290.0
const BODY_HALF_WIDTH: float = 150.0
## Half the neck's width when tied, and when loosened to let a ball in.
const NECK_CLOSED: float = 46.0
const NECK_OPEN: float = 76.0
## How far above the neck the flared top reaches, and how far it flares out.
const FRILL_HEIGHT: float = 44.0
const FRILL_FLARE: float = 30.0
## Several catches at once queue up and drop this many seconds apart, so the
## balls don't spawn on top of each other.
const DROP_INTERVAL: float = 0.16
## How long the neck stays loose after the last drop.
const OPEN_HOLD: float = 0.55

const FABRIC := Color(0.82, 0.66, 0.44)
const FABRIC_DARK := Color(0.52, 0.37, 0.22)
const INSIDE := Color(0.20, 0.13, 0.08)
const STITCH := Color(0.34, 0.22, 0.12)

var _viewport: SubViewport
var _back: Node2D
var _marbles: Node2D
var _front: Node2D

## 0 = tied shut, 1 = loosened. Eased toward its target every frame.
var _open: float = 0.0
var _open_hold_left: float = 0.0
var _queue: Array[Color] = []
var _next_drop_in: float = 0.0
var _squash: Tween


func _ready() -> void:
	# Never swallow clicks meant for the beam.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# stretch: the SubViewport is resized to fill this container.
	stretch = true
	custom_minimum_size = VIEW_SIZE
	# Squash from the bottom middle, so it sits down rather than shrinking.
	pivot_offset = Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.size = Vector2i(VIEW_SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	# Each layer draws through its `draw` signal, which fires just as the node
	# is about to draw, so these functions can call _back.draw_* directly.
	_back = Node2D.new()
	_back.draw.connect(_draw_back)
	_viewport.add_child(_back)
	_marbles = Node2D.new()
	_viewport.add_child(_marbles)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	_viewport.add_child(_front)

	_build_walls()


## Queues a ball of this colour to drop into the bag.
func drop(color: Color) -> void:
	_queue.append(color)


func marble_count() -> int:
	return _marbles.get_child_count()


## True if every ball is somewhere inside the bag's outline. Used by tests.
func all_inside() -> bool:
	var shape: PackedVector2Array = _outline(1.0)
	for marble in _marbles.get_children():
		if not Geometry2D.is_point_in_polygon((marble as Node2D).position, shape):
			return false
	return true


func _process(delta: float) -> void:
	_next_drop_in -= delta
	if not _queue.is_empty():
		# Loosen the neck first; the ball drops once it's mostly open.
		_open_hold_left = OPEN_HOLD
		if _next_drop_in <= 0.0 and _open > 0.6:
			_spawn_marble(_queue.pop_front())
			_next_drop_in = DROP_INTERVAL
	_open_hold_left -= delta
	var target: float = 1.0 if _open_hold_left > 0.0 else 0.0
	var before: float = _open
	_open = move_toward(_open, target, delta * 6.0)
	if not is_equal_approx(before, _open):
		_back.queue_redraw()
		_front.queue_redraw()


func _spawn_marble(color: Color) -> void:
	var marble := BagMarble.new()
	marble.color = color
	# Just above the opening, a little off-centre, so the pile isn't a tower.
	marble.position = Vector2(CENTRE_X + randf_range(-14.0, 14.0), NECK_Y - FRILL_HEIGHT - 50.0)
	marble.linear_velocity = Vector2(randf_range(-40.0, 40.0), 160.0)
	marble.angular_velocity = randf_range(-8.0, 8.0)
	marble.landed.connect(_on_marble_landed)
	_marbles.add_child(marble)


## The bag gives a little when a ball lands in it: wider and shorter, then
## springing back. Harder landings squash it more.
func _on_marble_landed(speed: float) -> void:
	var amount: float = clampf(speed / 500.0, 0.25, 1.0)
	if _squash != null and _squash.is_valid():
		_squash.kill()
	_squash = create_tween()
	_squash.tween_property(self, "scale", Vector2(1.0 + 0.05 * amount, 1.0 - 0.06 * amount), 0.07)
	_squash.tween_property(self, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- shape

## The bag's body as points: down the right side from the neck, round the
## bottom, and up the left side. Open at the top (no edge across the neck).
func _outline(open: float) -> PackedVector2Array:
	var neck: float = lerpf(NECK_CLOSED, NECK_OPEN, open)
	const STEPS: int = 30
	var right := PackedVector2Array()
	for i in STEPS + 1:
		var t: float = float(i) / STEPS
		right.append(Vector2(CENTRE_X + _half_width(t, neck), NECK_Y + t * BODY_HEIGHT))
	var points: PackedVector2Array = right.duplicate()
	# Mirror for the left side, skipping the bottom point (already there).
	for i in range(STEPS - 1, -1, -1):
		points.append(Vector2(CENTRE_X * 2.0 - right[i].x, right[i].y))
	return points


## How wide the bag is `t` of the way down (0 = neck, 1 = bottom): flares out
## from the neck over the top half, then rounds off at the bottom.
func _half_width(t: float, neck: float) -> float:
	var flare: float = sin(clampf(t / 0.5, 0.0, 1.0) * PI * 0.5)
	var width: float = lerpf(neck, BODY_HALF_WIDTH, flare)
	if t > 0.68:
		var u: float = (t - 0.68) / 0.32
		width *= sqrt(maxf(1.0 - u * u, 0.0))
	return width


## The walls the marbles roll against: the outline at its most open, as a
## chain of line segments. ConcavePolygonShape2D takes them as pairs of
## points and, unlike a polygon, doesn't close the loop across the top.
func _build_walls() -> void:
	var outline: PackedVector2Array = _outline(1.0)
	var segments := PackedVector2Array()
	for i in outline.size() - 1:
		segments.append(outline[i])
		segments.append(outline[i + 1])
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var walls := StaticBody2D.new()
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.1
	walls.physics_material_override = material
	walls.add_child(collision)
	_viewport.add_child(walls)


# ---------------------------------------------------------------- drawing

## The opening at the top of the flared part, as an ellipse: centre and radii.
func _mouth() -> Array:
	var neck: float = lerpf(NECK_CLOSED, NECK_OPEN, _open)
	return [Vector2(CENTRE_X, NECK_Y - FRILL_HEIGHT), Vector2(neck + FRILL_FLARE, 11.0 + 5.0 * _open)]


func _draw_back() -> void:
	# A soft shadow under the bag, so it sits on the screen instead of
	# floating, and stands out from the brown floor behind it.
	for i in 4:
		var spread: float = 1.0 - i * 0.18
		_back.draw_colored_polygon(_ellipse(
			Vector2(CENTRE_X, NECK_Y + BODY_HEIGHT - 4.0),
			Vector2(BODY_HALF_WIDTH * 0.95 * spread, 18.0 * spread), 0.0, TAU),
			Color(0.0, 0.0, 0.0, 0.14))
	var outline: PackedVector2Array = _outline(_open)
	# The inside of the bag, seen through the net.
	_back.draw_polygon(outline, UiStyle.vertical_ramp(outline,
		Rect2(0.0, NECK_Y, VIEW_SIZE.x, BODY_HEIGHT), INSIDE.lightened(0.15), INSIDE))
	# The far side of the opening: the dark hole and its back rim.
	var mouth: Array = _mouth()
	var hole: PackedVector2Array = _ellipse(mouth[0], mouth[1], 0.0, TAU)
	_back.draw_colored_polygon(hole, INSIDE.darkened(0.3))
	_back.draw_polyline(_ellipse(mouth[0], mouth[1], PI, TAU), FABRIC_DARK, 4.0, true)


func _draw_front() -> void:
	var outline: PackedVector2Array = _outline(_open)
	var neck: float = lerpf(NECK_CLOSED, NECK_OPEN, _open)

	# Net body: a thin wash of fabric, darker toward the bottom, then a
	# diagonal mesh clipped to the bag's shape.
	_front.draw_polygon(outline, UiStyle.vertical_ramp(outline,
		Rect2(0.0, NECK_Y, VIEW_SIZE.x, BODY_HEIGHT),
		Color(FABRIC, 0.18), Color(FABRIC_DARK, 0.42)))
	var mesh_colour := Color(STITCH, 0.45)
	for i in range(-14, 22):
		var x: float = i * 24.0
		for line: PackedVector2Array in [
			PackedVector2Array([Vector2(x, NECK_Y), Vector2(x + BODY_HEIGHT, NECK_Y + BODY_HEIGHT)]),
			PackedVector2Array([Vector2(x, NECK_Y), Vector2(x - BODY_HEIGHT, NECK_Y + BODY_HEIGHT)]),
		]:
			# Keeps only the parts of the line that are inside the bag.
			for piece in Geometry2D.intersect_polyline_with_polygon(line, outline):
				_front.draw_polyline(piece, mesh_colour, 2.0, true)

	# A soft sheen down the left side, so the net reads as round, not flat.
	var sheen := PackedVector2Array()
	for i in 13:
		var t: float = 0.12 + 0.7 * float(i) / 12.0
		sheen.append(Vector2(CENTRE_X - _half_width(t, neck) * 0.72, NECK_Y + t * BODY_HEIGHT))
	_front.draw_polyline(sheen, Color(1.0, 1.0, 1.0, 0.16), 10.0, true)

	# Seam round the body.
	_front.draw_polyline(outline, STITCH, 5.0, true)

	# The flared top: from the neck up to the near rim of the opening. Its top
	# edge is the front half of the mouth's ellipse, so a ball dropping in
	# disappears behind it.
	var mouth: Array = _mouth()
	var rim: PackedVector2Array = _ellipse(mouth[0], mouth[1], 0.0, PI)
	var neck_right := Vector2(CENTRE_X + neck + 2.0, NECK_Y - 4.0)
	var neck_left := Vector2(CENTRE_X - neck - 2.0, NECK_Y - 4.0)
	# Filled as a strip of small four-sided pieces between the rim and the
	# neck. draw_polygon would try to triangulate the whole shape and give up
	# on the thin slivers at each end; draw_primitive draws a four-point
	# piece directly as two triangles, with no checks to fail.
	var light: Color = FABRIC.lightened(0.12)
	for i in rim.size() - 1:
		var t0: float = float(i) / (rim.size() - 1)
		var t1: float = float(i + 1) / (rim.size() - 1)
		_front.draw_primitive(
			PackedVector2Array([rim[i], rim[i + 1], neck_right.lerp(neck_left, t1), neck_right.lerp(neck_left, t0)]),
			PackedColorArray([light, light, FABRIC, FABRIC]), PackedVector2Array())
	var frill := PackedVector2Array([neck_right])
	frill.append_array(rim)
	frill.append(neck_left)
	# Gathers: folds running from the neck up to the rim.
	for i in 5:
		var f: float = lerpf(-0.7, 0.7, float(i) / 4.0)
		_front.draw_line(Vector2(CENTRE_X + neck * f, NECK_Y - 6.0),
			mouth[0] + Vector2(mouth[1].x * f, mouth[1].y * sqrt(1.0 - f * f) - 2.0),
			Color(FABRIC_DARK, 0.6), 2.0, true)
	var closed_frill: PackedVector2Array = frill.duplicate()
	closed_frill.append(frill[0])
	_front.draw_polyline(closed_frill, STITCH, 4.0, true)

	# The gathered neck band, with pleats.
	var band := Rect2(CENTRE_X - neck - 10.0, NECK_Y - 14.0, (neck + 10.0) * 2.0, 26.0)
	var band_points: PackedVector2Array = UiStyle.rounded_points(band, 12.0)
	_front.draw_polygon(band_points, UiStyle.vertical_ramp(band_points, band, FABRIC, FABRIC_DARK))
	for i in 7:
		var x: float = lerpf(band.position.x + 10.0, band.end.x - 10.0, float(i) / 6.0)
		_front.draw_line(Vector2(x, band.position.y + 4.0), Vector2(x, band.end.y - 4.0),
			Color(STITCH, 0.5), 2.0, true)

	_draw_bow(Vector2(CENTRE_X + neck * 0.35, NECK_Y))


## The drawstring: a cord across the neck tied in a bow, which droops a little
## when the neck is loosened.
func _draw_bow(knot: Vector2) -> void:
	var cord: Color = UiStyle.CORAL.darkened(0.12)
	var cord_dark: Color = cord.darkened(0.3)
	var neck: float = lerpf(NECK_CLOSED, NECK_OPEN, _open)
	_front.draw_line(Vector2(CENTRE_X - neck - 10.0, NECK_Y), Vector2(CENTRE_X + neck + 10.0, NECK_Y),
		cord, 6.0, true)
	var droop: float = 6.0 * _open
	for side: float in [-1.0, 1.0]:
		# A loop each side of the knot.
		var loop_centre := knot + Vector2(18.0 * side, -8.0 + droop)
		var loop: PackedVector2Array = _ellipse(loop_centre, Vector2(17.0, 10.0), 0.0, TAU)
		loop.append(loop[0])
		_front.draw_polyline(loop, cord_dark, 9.0, true)
		_front.draw_polyline(loop, cord, 5.0, true)
		# A tail hanging down, curving outward.
		var tail := PackedVector2Array()
		for i in 7:
			var t: float = float(i) / 6.0
			tail.append(knot + Vector2(side * (4.0 + 16.0 * t * t), 6.0 + 40.0 * t + droop))
		_front.draw_polyline(tail, cord_dark, 8.0, true)
		_front.draw_polyline(tail, cord, 4.5, true)
	_front.draw_circle(knot, 8.0, cord_dark)
	_front.draw_circle(knot + Vector2(-1.0, -1.0), 6.0, cord)


## Points along an ellipse from angle `from` to `to` (radians, 0 = right,
## PI/2 = down in screen space).
func _ellipse(centre: Vector2, radii: Vector2, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	const STEPS: int = 24
	for i in STEPS + 1:
		var a: float = lerpf(from, to, float(i) / STEPS)
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
