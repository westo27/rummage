class_name MarbleBag
extends Control
## A clear drawstring bag in the corner of the HUD. Every creature you catch
## drops into it as a glass marble with eyes (BagMarble) and piles up with the
## others, like a bag of marbles.
##
## It's a little world of its own. A SubViewport renders its own scene and,
## importantly, has its own 2D physics space, so the marbles can tumble about
## without touching the 3D game. A SubViewportContainer (_view) shows that
## render as an ordinary UI element. Its background is transparent, so the
## room shows through the bag.
##
## The bag is held in your hand: turning the camera or moving swings it from
## its neck like a pendulum, and the marbles slosh about inside. The swing is
## the _sway control's rotation (around the neck); the slosh is the marbles'
## gravity tilted to match plus a push opposite to the hand's movement. The
## bag's own node stays put, so the HUD and the win card can lay it out.
##
## Drawing order inside the viewport, back to front:
##   _back     the far side of the bag (a faint film) and the far rim of the
##             opening
##   _marbles  the balls
##   _front    the near side: a faint film, light along the edges and a
##             reflection, the gathered neck and the flared top (whose near
##             rim covers a ball as it drops in)
##
## The bag's shape is one function, _outline(), used both for drawing and for
## the walls the marbles collide with, so the two can't disagree.

const VIEW_SIZE := Vector2(360.0, 470.0)
## How big it's shown on screen. The bag is drawn (and its physics runs) in
## VIEW_SIZE coordinates and scaled to this.
const DISPLAY_SIZE := VIEW_SIZE * 0.75
const CENTRE_X: float = 180.0
## Where the neck sits, and how tall the body below it is.
const NECK_Y: float = 158.0
const BODY_HEIGHT: float = 290.0
const BODY_HALF_WIDTH: float = 150.0
## Half the neck's width when gathered shut, and when loosened to let a ball in.
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

## The clear film: barely there at the top, a little cloudier at the bottom
## where it's seen at more of a slant.
const FILM_TOP := Color(0.85, 0.93, 1.0, 0.05)
const FILM_BOTTOM := Color(0.75, 0.86, 0.97, 0.14)
## Light along the edges and in the reflections.
const LIGHT := Color(1.0, 1.0, 1.0)

## How the hand's movement reaches the bag. Turning the camera moves the hand
## this many bag pixels per second for each radian per second of turn, and
## walking this many for each metre per second.
const HAND_PER_TURN: float = 150.0
const HAND_PER_METRE: float = 30.0
## How hard a change in the hand's speed kicks the swing (radians per second
## per bag pixel per second), and the swing's spring and friction.
const SWING_KICK: float = 0.0035
const SWING_SPRING: float = 30.0
const SWING_DAMP: float = 3.2
const SWING_MAX: float = 0.4
## How much of a change in the hand's speed the marbles feel (they keep going
## while the bag moves), and the most they're pushed upward in one go, so a
## flick can't throw them out of the open top.
const SLOSH: float = 0.9
const SLOSH_UP_MAX: float = 120.0
const SLOSH_MAX: float = 400.0
## The fastest the hand counts as moving (bag pixels per second), and the
## fastest a marble may go, so even a wild flick can't fire one through a wall.
const HAND_MAX: float = 1500.0
const MARBLE_MAX_SPEED: float = 700.0
## The fastest a marble may rise: at this it climbs about 30 px, well inside.
const MARBLE_MAX_RISE: float = 250.0

var _sway: Control
var _view: SubViewportContainer
var _viewport: SubViewport
var _back: Node2D
var _marbles: Node2D
var _front: Node2D

## 0 = gathered shut, 1 = loosened. Eased toward its target every frame.
var _open: float = 0.0
var _open_hold_left: float = 0.0
var _queue: Array[Color] = []
var _next_drop_in: float = 0.0
var _squash: Tween

## The catch count. Nothing on screen shows it (the bag's marbles are the
## count); tests read it through Hud.caught_text().
var _caught: int = 0
var _total: int = 0

## The swing angle (radians, positive swings the bottom left) and its speed.
var _swing: float = 0.0
var _swing_speed: float = 0.0
## The hand's speed in bag pixels per second, smoothed, and last frame's.
var _hand_velocity: Vector2 = Vector2.ZERO
## The camera as it was last frame, to work out how it's moving.
var _last_camera: Transform3D
var _has_last_camera: bool = false
## The walls' shape, kept for the safety net in _physics_process.
var _walls_outline: PackedVector2Array


func _ready() -> void:
	# Never swallow clicks meant for the beam.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = DISPLAY_SIZE

	# Two layers, so swinging and squashing each get their own pivot: _sway
	# turns around the neck, _view squashes from the bottom middle.
	_sway = Control.new()
	_sway.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sway.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sway.pivot_offset = Vector2(CENTRE_X, NECK_Y) * DISPLAY_SIZE / VIEW_SIZE
	add_child(_sway)
	_view = SubViewportContainer.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	# stretch: the SubViewport is resized to fill this container.
	_view.stretch = true
	_view.pivot_offset = Vector2(DISPLAY_SIZE.x * 0.5, DISPLAY_SIZE.y)
	_sway.add_child(_view)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.size = Vector2i(DISPLAY_SIZE)
	# Draws the whole VIEW_SIZE world into the render, whatever its size.
	_viewport.size_2d_override = Vector2i(VIEW_SIZE)
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.add_child(_viewport)

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


## Remembers the catch count.
func set_count(caught: int, total: int) -> void:
	_caught = caught
	_total = total


## The count as text, e.g. "12 / 25".
func count_text() -> String:
	return "%d / %d" % [_caught, _total]


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
	_squash.tween_property(_view, "scale", Vector2(1.0 + 0.05 * amount, 1.0 - 0.06 * amount), 0.07)
	_squash.tween_property(_view, "scale", Vector2.ONE, 0.35) \
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
	_walls_outline = outline
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


# ---------------------------------------------------------------- swaying

func _physics_process(delta: float) -> void:
	var hand: Vector2 = _hand_velocity_now(delta)
	var change: Vector2 = hand - _hand_velocity
	_hand_velocity = hand

	# The bag hangs from the hand: when the hand speeds up to the right, the
	# bottom lags behind to the left, then swings back on a damped spring.
	_swing_speed += change.x * SWING_KICK
	_swing_speed += (-SWING_SPRING * _swing - SWING_DAMP * _swing_speed) * delta
	_swing = clampf(_swing + _swing_speed * delta, -SWING_MAX, SWING_MAX)
	_sway.rotation = _swing

	# The marbles: "down" tilts with the bag, so they roll to its low side...
	var down := Vector2.DOWN.rotated(-_swing)
	PhysicsServer2D.area_set_param(_viewport.world_2d.space,
		PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, down)
	# ...and they carry on as they were while the bag moves under them, so
	# they get the hand's change in speed backwards, in the bag's own frame.
	var push: Vector2 = (-change * SLOSH).rotated(-_swing).limit_length(SLOSH_MAX)
	push.y = maxf(push.y, -SLOSH_UP_MAX)
	var moving: bool = push.length() > 4.0 or absf(_swing_speed) > 0.05
	for marble: BagMarble in _marbles.get_children():
		# One still dropping in, above the neck, falls straight so it can't
		# miss the opening.
		if marble.position.y < NECK_Y:
			continue
		# A safety net: a marble that somehow squeezes out through a wall
		# (the physics can slip under a lot of shaking) is put back in. A
		# rigid body is moved through the physics server, or the physics
		# would just put it back where it was.
		if not Geometry2D.is_point_in_polygon(marble.position, _walls_outline):
			PhysicsServer2D.body_set_state(marble.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
				Transform2D(0.0, Vector2(CENTRE_X, NECK_Y + 20.0)))
			marble.linear_velocity = Vector2.ZERO
			continue
		if moving:
			marble.sleeping = false
			var v: Vector2 = (marble.linear_velocity + push).limit_length(MARBLE_MAX_SPEED)
			# Never fast enough upward to leave through the open top.
			v.y = maxf(v.y, -MARBLE_MAX_RISE)
			marble.linear_velocity = v


## How fast the hand holding the bag is moving, in bag pixels per second
## (x right, y down on screen), from how the camera moved since last tick.
func _hand_velocity_now(delta: float) -> Vector2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or delta <= 0.0:
		_has_last_camera = false
		return Vector2.ZERO
	var now: Transform3D = camera.global_transform
	if not _has_last_camera:
		_last_camera = now
		_has_last_camera = true
		return _hand_velocity
	var before: Transform3D = _last_camera
	_last_camera = now
	# Turning: the hand swings with the view. A turn to the right (negative
	# about up) moves it right; looking up moves it up.
	var forward_before: Vector3 = -before.basis.z
	var forward_now: Vector3 = -now.basis.z
	var flat_before := Vector3(forward_before.x, 0.0, forward_before.z)
	var flat_now := Vector3(forward_now.x, 0.0, forward_now.z)
	var yaw: float = 0.0
	if flat_before.length() > 0.01 and flat_now.length() > 0.01:
		yaw = flat_before.signed_angle_to(flat_now, Vector3.UP)
	var pitch: float = asin(clampf(forward_now.y, -1.0, 1.0)) - asin(clampf(forward_before.y, -1.0, 1.0))
	# A big jump in one tick is the camera being placed (a restart, a
	# test), not the player turning.
	if absf(yaw) > 0.5 or absf(pitch) > 0.5:
		yaw = 0.0
		pitch = 0.0
	# Moving: sideways and up/down, as the camera sees it. A jump to the
	# respawn point isn't movement.
	var moved: Vector3 = now.origin - before.origin
	if moved.length() > 1.0:
		moved = Vector3.ZERO
	var side: float = moved.dot(now.basis.x)
	var up: float = moved.dot(now.basis.y)
	var target := Vector2(-yaw * HAND_PER_TURN + side * HAND_PER_METRE,
		-pitch * HAND_PER_TURN - up * HAND_PER_METRE) / delta
	target = target.limit_length(HAND_MAX)
	# Mouse movement arrives in uneven steps, so smooth it a little.
	return _hand_velocity.lerp(target, 0.5)


# ---------------------------------------------------------------- drawing

## The opening at the top of the flared part, as an ellipse: centre and radii.
func _mouth() -> Array:
	var neck: float = lerpf(NECK_CLOSED, NECK_OPEN, _open)
	return [Vector2(CENTRE_X, NECK_Y - FRILL_HEIGHT), Vector2(neck + FRILL_FLARE, 11.0 + 5.0 * _open)]


## A point on the bag's edge `t` of the way down (0 = neck, 1 = bottom), on
## the left (side -1) or right (side 1), pulled `inset` of the way to the middle.
func _edge_point(t: float, side: float, neck: float, inset: float = 0.0) -> Vector2:
	return Vector2(CENTRE_X + side * _half_width(t, neck) * (1.0 - inset), NECK_Y + t * BODY_HEIGHT)


func _draw_back() -> void:
	var outline: PackedVector2Array = _outline(_open)
	var body := Rect2(0.0, NECK_Y, VIEW_SIZE.x, BODY_HEIGHT)
	# The far side of the bag, seen through the near side.
	_back.draw_polygon(outline, UiStyle.vertical_ramp(outline, body, FILM_TOP, FILM_BOTTOM))
	# The opening: a faint shadow inside, and the far rim catching the light.
	var mouth: Array = _mouth()
	_back.draw_colored_polygon(_ellipse(mouth[0], mouth[1], 0.0, TAU), Color(0.0, 0.02, 0.05, 0.12))
	_back.draw_polyline(_ellipse(mouth[0], mouth[1], PI, TAU), Color(LIGHT, 0.4), 2.0, true)


func _draw_front() -> void:
	var outline: PackedVector2Array = _outline(_open)
	var neck: float = lerpf(NECK_CLOSED, NECK_OPEN, _open)
	var body := Rect2(0.0, NECK_Y, VIEW_SIZE.x, BODY_HEIGHT)

	# The near side: the same faint film.
	_front.draw_polygon(outline, UiStyle.vertical_ramp(outline, body, FILM_TOP, FILM_BOTTOM))

	# Edges: a soft glow and a fine bright line, where the film turns away
	# from you and you see more of it.
	_front.draw_polyline(outline, Color(LIGHT, 0.07), 12.0, true)
	_front.draw_polyline(outline, Color(LIGHT, 0.4), 2.0, true)

	# Reflections: a long soft streak down the left (the light's side), a fine
	# bright line inside it, and a short one high on the right.
	var streak := PackedVector2Array()
	var line := PackedVector2Array()
	for i in 17:
		var t: float = lerpf(0.14, 0.8, float(i) / 16.0)
		streak.append(_edge_point(t, -1.0, neck, 0.2))
		line.append(_edge_point(t, -1.0, neck, 0.27))
	_front.draw_polyline(streak, Color(LIGHT, 0.12), 16.0, true)
	_front.draw_polyline(line.slice(2, 12), Color(LIGHT, 0.45), 2.5, true)
	var right := PackedVector2Array()
	for i in 7:
		right.append(_edge_point(lerpf(0.22, 0.42, float(i) / 6.0), 1.0, neck, 0.16))
	_front.draw_polyline(right, Color(LIGHT, 0.3), 3.0, true)

	# Soft creases running down from the gathered neck.
	for f: float in [-0.55, -0.15, 0.3, 0.65]:
		var crease := PackedVector2Array()
		for i in 7:
			var t: float = lerpf(0.02, 0.32, float(i) / 6.0)
			crease.append(Vector2(CENTRE_X + f * _half_width(t, neck) * 0.85, NECK_Y + t * BODY_HEIGHT))
		_front.draw_polyline(crease, Color(LIGHT, 0.12), 2.0, true)

	# The flared top: from the neck up to the near rim of the opening. Its top
	# edge is the front half of the mouth's ellipse, so a ball dropping in
	# passes behind it.
	var mouth: Array = _mouth()
	var rim: PackedVector2Array = _ellipse(mouth[0], mouth[1], 0.0, PI)
	var neck_right := Vector2(CENTRE_X + neck + 2.0, NECK_Y - 4.0)
	var neck_left := Vector2(CENTRE_X - neck - 2.0, NECK_Y - 4.0)
	# Filled as a strip of small four-sided pieces between the rim and the
	# neck. draw_polygon would try to triangulate the whole shape and give up
	# on the thin slivers at each end; draw_primitive draws a four-point
	# piece directly as two triangles, with no checks to fail.
	var film_top := Color(LIGHT, 0.14)
	for i in rim.size() - 1:
		var t0: float = float(i) / (rim.size() - 1)
		var t1: float = float(i + 1) / (rim.size() - 1)
		_front.draw_primitive(
			PackedVector2Array([rim[i], rim[i + 1], neck_right.lerp(neck_left, t1), neck_right.lerp(neck_left, t0)]),
			PackedColorArray([film_top, film_top, FILM_TOP, FILM_TOP]), PackedVector2Array())
	# Gathers: folds running from the neck up to the rim.
	for i in 5:
		var f: float = lerpf(-0.7, 0.7, float(i) / 4.0)
		_front.draw_line(Vector2(CENTRE_X + neck * f, NECK_Y - 6.0),
			mouth[0] + Vector2(mouth[1].x * f, mouth[1].y * sqrt(1.0 - f * f) - 2.0),
			Color(LIGHT, 0.18), 2.0, true)
	_front.draw_polyline(rim, Color(LIGHT, 0.55), 2.5, true)
	_front.draw_line(rim[0], neck_right, Color(LIGHT, 0.35), 2.0, true)
	_front.draw_line(rim[rim.size() - 1], neck_left, Color(LIGHT, 0.35), 2.0, true)

	# The gathered neck: a narrow band where the film bunches up, so it's a
	# little whiter, with a bright line along its top.
	var band := Rect2(CENTRE_X - neck - 6.0, NECK_Y - 10.0, (neck + 6.0) * 2.0, 16.0)
	var band_points: PackedVector2Array = UiStyle.rounded_points(band, 8.0)
	_front.draw_polygon(band_points, UiStyle.vertical_ramp(band_points, band,
		Color(LIGHT, 0.3), Color(0.8, 0.88, 0.96, 0.18)))
	_front.draw_line(band.position + Vector2(8.0, 2.0), Vector2(band.end.x - 8.0, band.position.y + 2.0),
		Color(LIGHT, 0.6), 2.0, true)
	for i in 6:
		var x: float = lerpf(band.position.x + 12.0, band.end.x - 12.0, float(i) / 5.0)
		_front.draw_line(Vector2(x, band.position.y + 4.0), Vector2(x, band.end.y - 3.0),
			Color(LIGHT, 0.2), 1.5, true)


## Points along an ellipse from angle `from` to `to` (radians, 0 = right,
## PI/2 = down in screen space).
func _ellipse(centre: Vector2, radii: Vector2, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	const STEPS: int = 24
	for i in STEPS + 1:
		var a: float = lerpf(from, to, float(i) / STEPS)
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
