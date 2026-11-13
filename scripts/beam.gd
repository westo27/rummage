class_name Beam
extends Node3D
## The grab beam: aim, grab, hold, throw, and the lift limit.
##
## Lives under the camera in player.tscn. It never reparents or teleports the
## held object. It holds the exact spot you clicked on (the grab point), and
## each physics tick it gives that spot a push towards a hold point in front of
## the camera. Because the push is at that spot rather than at the object's
## centre, the rest of the object turns about it the way it would in a hand:
## grab the top of the bookcase and pull down and it topples; grab the middle
## and it lifts level; grab a corner and it hangs from it. Walls and other
## objects still stop it, because it's only ever pushed, never placed.

## Signals are Godot's events: the beam announces changes and doesn't care who
## listens. main.gd connects these to the HUD. Like dispatching a Laravel event.
signal aim_changed(state: AimState, detail: String)
signal lift_limit_changed(kg: float)

enum AimState { IDLE, CAN_GRAB, TOO_HEAVY, HOLDING, CREATURE }

## Collision layers are bit flags: layer 1 = value 1, layer 2 = 2, layer 3 = 4,
## layer 4 = 8. The ray only "sees" bodies on layers included in its mask.
const MASK_WORLD_AND_PROPS: int = 1 | 4 | 16  # world, props, clutter
const MASK_WORLD: int = 1
const MASK_CREATURES: int = 8

## Where the beam visibly starts, relative to the camera (lower right, like a hand).
const BEAM_ORIGIN_LOCAL := Vector3(0.22, -0.2, -0.35)
const ARC_SEGMENTS: int = 20
const ARC_HALF_WIDTH: float = 0.012

var lift_limit: float = 0.0
var held: Prop = null

## How far in front of the camera the grab point is held.
var _hold_distance: float = 0.0
## The grab point, in the held object's own coordinates, so it moves and turns
## with the object.
var _grab_local: Vector3 = Vector3.ZERO
var _aimed: Prop = null
## Where the crosshair ray hit the aimed prop, in world space.
var _aimed_point: Vector3 = Vector3.ZERO
## For a too-heavy object: where on it the red beam is latched, in its own
## coordinates.
var _rejected_local: Vector3 = Vector3.ZERO
var _aimed_creature: Creature = null
var _capture_sound := AudioStreamPlayer.new()
## The grab button only counts if its press reached this script as an event.
## The click that recaptures the mouse is swallowed by player.gd, so it can't
## accidentally grab something.
var _grab_armed: bool = false
## A too-heavy object the beam is straining against. Set when you press on it,
## cleared when you let go of the button: the red beam stays latched to it and
## it keeps shuddering the whole time.
var _rejected: Prop = null
var _state: AimState = AimState.IDLE
var _detail: String = ""

@onready var _camera: Camera3D = get_parent() as Camera3D
## `owner` is the root of the scene file this node was saved in (here, the
## Player node in player.tscn), however deep the node sits in that tree.
@onready var _player: CharacterBody3D = owner as CharacterBody3D
@onready var _beam_mesh: MeshInstance3D = $BeamMesh
@onready var _beam_material: StandardMaterial3D = _beam_mesh.material_override as StandardMaterial3D


func _ready() -> void:
	lift_limit = Game.tune.start_lift_limit
	# top_level makes the beam mesh ignore its parent's transform, so its vertices
	# can be world positions without the camera's movement being added on top.
	# It keeps whatever world transform it had at that moment, so reset it.
	_beam_mesh.top_level = true
	_beam_mesh.global_transform = Transform3D.IDENTITY
	_beam_mesh.visible = false
	# Non-positional player for the capture sound. A node created in code must be
	# added to the tree with add_child before it does anything.
	_capture_sound.stream = Tones.slurp()
	_capture_sound.volume_db = -6.0
	add_child(_capture_sound)


# The beam line is purely visual, so it's redrawn every rendered frame (_process)
# rather than every physics tick; on a 144 Hz monitor that keeps the hand end
# glued to the camera instead of stepping at 60 Hz.
func _process(_delta: float) -> void:
	_update_beam_mesh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("grab"):
		_grab_armed = true
	elif event.is_action_released("grab"):
		_grab_armed = false

	if held == null:
		return
	if event.is_action_pressed("throw"):
		_throw()
	elif event.is_action_pressed("beam_further"):
		_hold_distance = minf(_hold_distance + Game.tune.hold_distance_step, Game.tune.beam_reach)
	elif event.is_action_pressed("beam_nearer"):
		_hold_distance = maxf(_hold_distance - Game.tune.hold_distance_step, _min_hold_distance(held))


func _physics_process(_delta: float) -> void:
	if held != null:
		if _grab_armed:
			_drive_held()
		else:
			_release()

	if held == null:
		# Creatures are checked first, and only if nothing is found do we look
		# for a prop, so a creature beside the sofa is never blocked by the sofa.
		_aimed_creature = _find_aimed_creature() if _rejected == null else null
		_aimed = _find_aimed_prop() if _aimed_creature == null else null
		if _rejected != null:
			_strain_against_rejected()
		elif _grab_armed and _aimed_creature != null:
			_capture(_aimed_creature)
		elif _grab_armed and _aimed != null:
			if _aimed.mass <= lift_limit:
				_grab(_aimed, _aimed_point)
			else:
				_rejected = _aimed
				_rejected_local = _rejected.to_local(_aimed_point)
				_rejected.shudder()

	_update_aim_state()


## While latched onto something too heavy: keep it shuddering until the button
## is released (or you walk out of reach). While latched, sweeping the crosshair
## over other objects doesn't grab them; let go and click again for that.
func _strain_against_rejected() -> void:
	var too_far: bool = _camera.global_position.distance_to(_rejected.global_position) \
		> Game.tune.beam_reach + _rejected.hold_radius
	if not _grab_armed or too_far:
		_rejected = null
		_grab_armed = false  # a fresh click is needed after letting go
		return
	_rejected.shudder()


## Raises the lift limit. main.gd calls this on each capture.
func add_lift(kg: float) -> void:
	lift_limit += kg
	lift_limit_changed.emit(lift_limit)


## Looks for an exposed creature under the crosshair. Two rays:
## 1. Only the creatures layer, hitting only Areas (each exposed creature's
##    PickZone, a sphere bigger than its body, so aiming can be a bit sloppy).
## 2. A line-of-sight check against walls and floor only. Furniture is ignored
##    on purpose: being generous here matters more than being exact.
func _find_aimed_creature() -> Creature:
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from + _forward() * Game.tune.beam_reach
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_CREATURES)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return null
	# The ray hit the PickZone; its parent node is the creature.
	var creature := (hit.collider as Node).get_parent() as Creature
	if creature == null:
		return null
	var sight := PhysicsRayQueryParameters3D.create(from, creature.global_position, MASK_WORLD, [_player.get_rid()])
	if not space.intersect_ray(sight).is_empty():
		return null
	return creature


func _capture(creature: Creature) -> void:
	creature.capture(_camera.to_global(BEAM_ORIGIN_LOCAL))
	_capture_sound.play()
	# Need a fresh click before grabbing anything else, so a capture with the
	# button held doesn't immediately grab the crate behind it.
	_grab_armed = false


func _find_aimed_prop() -> Prop:
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from + _forward() * Game.tune.beam_reach
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD_AND_PROPS, [_player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	_aimed_point = hit.position
	# `as Prop` gives null if the ray hit a wall rather than a prop.
	return hit.collider as Prop


func _grab(prop: Prop, point: Vector3) -> void:
	held = prop
	_rejected = null
	_grab_local = prop.to_local(point)
	# Hold the grab point where it is now, so nothing jumps when you click.
	var distance: float = _camera.global_position.distance_to(point)
	_hold_distance = clampf(distance, _min_hold_distance(prop), Game.tune.beam_reach)
	prop.start_hold(_player)
	# A sleeping body ignores velocity changes, so make sure it's awake.
	prop.sleeping = false


## The grab point in world space, where it is right now.
func grab_point() -> Vector3:
	return held.global_transform * _grab_local


func _drive_held() -> void:
	var point: Vector3 = grab_point()
	var target: Vector3 = _camera.global_position + _forward() * _hold_distance
	var error: Vector3 = target - point
	if error.length() > Game.tune.beam_break_distance:
		_release()
		_grab_armed = false  # need a fresh click to grab again
		return
	var top_speed: float = Game.tune.hold_speed_base / (1.0 + held.mass / Game.tune.hold_speed_mass_scale)
	var wanted: Vector3 = (error * Game.tune.hold_stiffness).limit_length(top_speed)
	_push_point_to_velocity(point, wanted)


## Gives the held object the one push (impulse), applied at `point`, that makes
## that point move at `wanted` velocity. This is the maths a physics engine uses
## for a pin joint.
##
## A push away from the centre both moves the object and turns it, so how much
## the point speeds up depends on the object's mass, how hard it is to turn
## (its inertia) and how far the point is from its centre of mass (r). That
## relationship is a 3x3 matrix K:  point velocity change = K * impulse.
## Inverting K gives the impulse for the velocity change we want.
func _push_point_to_velocity(point: Vector3, wanted: Vector3) -> void:
	# The direct body state exposes the values the solver itself uses.
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(held.get_rid())
	var centre: Vector3 = held.global_position + state.center_of_mass
	var r: Vector3 = point - centre
	var current: Vector3 = state.linear_velocity + state.angular_velocity.cross(r)
	var change: Vector3 = wanted - current

	# K = (1/m)·I − [r]× · I⁻¹ · [r]×, where [r]× is the matrix that does
	# "cross product with r". Basis is Godot's 3x3 matrix, built from columns.
	var r_cross := Basis(Vector3(0.0, r.z, -r.y), Vector3(-r.z, 0.0, r.x), Vector3(r.y, -r.x, 0.0))
	var turn: Basis = r_cross * state.inverse_inertia_tensor * r_cross
	var inv_mass: float = state.inverse_mass
	var k := Basis(
		Vector3(inv_mass, 0.0, 0.0) - turn.x,
		Vector3(0.0, inv_mass, 0.0) - turn.y,
		Vector3(0.0, 0.0, inv_mass) - turn.z)
	var impulse: Vector3 = k.inverse() * change

	# What that push does: it changes the velocity by impulse / mass and the
	# spin by I⁻¹ · (r × impulse). Applied by setting the velocities directly
	# rather than through apply_impulse, so the result is exact and in place
	# before the damping below.
	var linear: Vector3 = state.linear_velocity + impulse * inv_mass
	var angular: Vector3 = state.angular_velocity + state.inverse_inertia_tensor * r.cross(impulse)
	# Then take some spin off, so an object hanging from a corner settles
	# after a swing or two instead of swinging on. Done after the push so the
	# push can't put it back. The grab point drifts a hair as a result, which
	# the next tick corrects.
	held.linear_velocity = linear
	held.angular_velocity = angular * (1.0 - Game.tune.held_spin_damping)


## Letting go just stops driving the object; it keeps whatever velocity it had,
## which is what makes swing-and-release flings work.
func _release() -> void:
	held.end_hold()
	held = null


func _throw() -> void:
	var speed: float = Game.tune.throw_speed_base / (1.0 + held.mass / Game.tune.throw_speed_mass_scale)
	held.linear_velocity = _forward() * speed
	_release()
	# Without this, still holding the left button would instantly re-grab the
	# object you just threw.
	_grab_armed = false


## The grab point is on the object's surface, not its middle, so it can come a
## bit closer than the centre used to; half the object's size keeps a big one
## from filling the view.
func _min_hold_distance(prop: Prop) -> float:
	return Game.tune.min_hold_distance + prop.hold_radius * 0.5


## The camera looks down its own -Z axis (a Godot convention).
func _forward() -> Vector3:
	return -_camera.global_transform.basis.z


func _update_aim_state() -> void:
	var state: AimState = AimState.IDLE
	var detail: String = ""
	if held != null:
		state = AimState.HOLDING
		detail = "%.1f kg" % held.mass
	elif _aimed_creature != null:
		state = AimState.CREATURE
		detail = "Catch!"
	elif _rejected != null:
		state = AimState.TOO_HEAVY
		detail = "TOO HEAVY  %.0f kg  (lift %.0f kg)" % [_rejected.mass, lift_limit]
	elif _aimed != null:
		if _aimed.mass <= lift_limit:
			state = AimState.CAN_GRAB
			detail = "%.1f kg" % _aimed.mass
		else:
			state = AimState.TOO_HEAVY
			detail = "TOO HEAVY  %.0f kg  (lift %.0f kg)" % [_aimed.mass, lift_limit]
	# Only announce real changes, so the HUD isn't redrawn 60 times a second.
	if state != _state or detail != _detail:
		_state = state
		_detail = detail
		aim_changed.emit(state, detail)


func _update_beam_mesh() -> void:
	var end_body: Prop = held
	var end_local: Vector3 = _grab_local
	var color := Color(0.35, 0.85, 1.0)
	if end_body == null and _rejected != null:
		end_body = _rejected
		end_local = _rejected_local
		color = Color(1.0, 0.2, 0.15)
	if end_body == null:
		_beam_mesh.visible = false
		return
	var start: Vector3 = _camera.to_global(BEAM_ORIGIN_LOCAL)
	# The grab point on the object as it's *drawn* this frame (see physics
	# interpolation in player.gd), so the beam stays attached to the spot you
	# grabbed instead of wobbling against it.
	var end: Vector3 = end_body.get_global_transform_interpolated() * end_local
	# The bend: aim_point is where you're pulling the object to (the hold point,
	# or for a too-heavy object, the spot on your aim at the object's distance).
	# The curve is pulled toward a point part-way from the hand to aim_point. When
	# the object is at aim_point that point lies on the straight line and the beam
	# is straight; when the object lags behind a swing, the beam bows toward it.
	var aim_distance: float = _hold_distance if held != null else _camera.global_position.distance_to(end)
	var aim_point: Vector3 = _camera.global_position + _forward() * aim_distance
	var control: Vector3 = start.lerp(aim_point, Game.tune.beam_arc_bend)
	_draw_arc(start, control, end)
	_beam_material.albedo_color = color
	_beam_mesh.visible = true


## Draws a thin ribbon along a quadratic Bézier curve (start → end, pulled
## toward control). ImmediateMesh is a mesh you rebuild from scratch each frame,
## like drawing on a canvas. The mesh node is top_level with no transform, so
## these vertices are plain world positions.
func _draw_arc(start: Vector3, control: Vector3, end: Vector3) -> void:
	var mesh := _beam_mesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	# A triangle strip turns each new pair of points into two more triangles.
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _beam_material)
	var eye: Vector3 = _camera.global_position
	for i in ARC_SEGMENTS + 1:
		var t: float = float(i) / ARC_SEGMENTS
		var u: float = 1.0 - t
		var point: Vector3 = u * u * start + 2.0 * u * t * control + t * t * end
		var tangent: Vector3 = 2.0 * u * (control - start) + 2.0 * t * (end - control)
		# Spread the ribbon sideways, perpendicular to both the curve and the
		# line to the eye, so it always faces the camera and never looks edge-on.
		var side: Vector3 = tangent.cross(eye - point).normalized() * ARC_HALF_WIDTH
		mesh.surface_add_vertex(point - side)
		mesh.surface_add_vertex(point + side)
	mesh.surface_end()
