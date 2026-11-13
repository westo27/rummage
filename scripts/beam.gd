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
const MASK_WORLD_AND_PROPS: int = 1 | 4 | 16 | 32  # world, props, clutter, rug
const MASK_WORLD: int = 1
const MASK_CREATURES: int = 8

## Where the beam starts, relative to the camera: just below the bottom edge
## of the screen, a little right of centre, so the beam runs in from off the
## bottom of the view (the camera sees about 0.19 m either side of centre
## vertically at this distance, so -0.32 is out of sight).
const BEAM_ORIGIN_LOCAL := Vector3(0.1, -0.32, -0.25)
const ARC_SEGMENTS: int = 32
## Half the width of the glowing ribbon: the bright core is a thin line down
## its middle (drawn by shaders/beam.gdshader) and the rest is soft halo.
const GLOW_HALF_WIDTH: float = 0.05
## The crackling filament that twitches around the core, like a live wire.
const FILAMENT_HALF_WIDTH: float = 0.006
## How far the filament strays from the beam's line, in metres, calm and
## straining. It picks a new shape this many times a second.
const FILAMENT_JITTER: float = 0.018
const FILAMENT_JITTER_STRAINING: float = 0.05
const CRACKLES_PER_SECOND: float = 30.0
const HOLD_COLOR := Color(0.35, 0.85, 1.0)
const STRAIN_COLOR := Color(1.0, 0.22, 0.15)
## The lights the beam casts: one where it meets the object, a softer one
## halfway along. Range in metres and brightness.
const END_LIGHT_RANGE: float = 2.6
const END_LIGHT_ENERGY: float = 0.8
const MID_LIGHT_RANGE: float = 2.2
const MID_LIGHT_ENERGY: float = 0.45
## Size of the glowing dot where the beam meets the object.
const CONTACT_GLOW_SIZE: float = 0.28

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
## A creature being sucked in: the beam latches onto it, in its colour, and
## reels it in. Cleared when the creature is gone.
var _catching: Creature = null
var _catch_started: float = 0.0
## How long the beam takes to shoot out and reach the creature, in seconds.
const CATCH_REACH_TIME: float = 0.06
var _aimed_creature: Creature = null
var _capture_sound := AudioStreamPlayer.new()
## The beam's sounds: a warm whirr while holding something (rising and
## swelling as you swing it) and a crackle while straining against
## something too heavy. Both are loops, faded in and out rather than
## started and stopped, so they never click. They play from your hand, so
## they're not placed in 3D. See Tones.whirr() and Tones.strain_crackle().
var _hum := AudioStreamPlayer.new()
var _strain := AudioStreamPlayer.new()
## The object currently wearing the beam's glowing aura, if any.
var _aura_prop: Prop = null
## Each sound's current loudness (0 to 1), eased toward where it should be.
var _hum_gain: float = 0.0
var _strain_gain: float = 0.0
## How hard you're swinging what you hold, 0 (still) to 1 (flinging),
## eased so it swells and settles rather than jumping.
var _swing: float = 0.0
## How fast the grab point moved last physics tick, and where it was.
var _point_speed: float = 0.0
var _last_point: Vector3 = Vector3.ZERO

## The whirr's loudness when the held thing is still, and when it's being
## swung at full speed (decibels; the creature squeaks are at -4).
const HUM_STILL_DB: float = -18.0
const HUM_SWINGING_DB: float = -9.0
## How much higher the whirr goes at a full swing (1.6 = 60% higher).
const HUM_SWING_PITCH: float = 1.6
## A grab point moving this fast (m/s) counts as a full swing.
const SWING_FULL_SPEED: float = 6.0
const STRAIN_DB: float = -13.0
## How quickly the sounds fade in and out (higher is snappier).
const SOUND_EASE: float = 14.0
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

## The look of the beam, built in _ready: see shaders/beam.gdshader.
var _beam_material: ShaderMaterial
var _filament: MeshInstance3D
var _filament_material: ShaderMaterial
var _contact_glow: MeshInstance3D
var _contact_material: ShaderMaterial
var _end_light: OmniLight3D
var _mid_light: OmniLight3D


func _ready() -> void:
	lift_limit = Game.tune.start_lift_limit
	# top_level makes the beam mesh ignore its parent's transform, so its vertices
	# can be world positions without the camera's movement being added on top.
	# It keeps whatever world transform it had at that moment, so reset it.
	_beam_mesh.top_level = true
	_beam_mesh.global_transform = Transform3D.IDENTITY
	_build_beam_look()
	_hide_beam()
	# Non-positional player for the capture sound. A node created in code must be
	# added to the tree with add_child before it does anything.
	_capture_sound.stream = Tones.slurp()
	_capture_sound.volume_db = -6.0
	add_child(_capture_sound)
	_hum.stream = Tones.whirr()
	add_child(_hum)
	_strain.stream = Tones.strain_crackle()
	add_child(_strain)


# The beam line is purely visual, so it's redrawn every rendered frame (_process)
# rather than every physics tick; on a 144 Hz monitor that keeps the hand end
# glued to the camera instead of stepping at 60 Hz.
func _process(delta: float) -> void:
	_update_beam_mesh()
	_update_sound(delta)
	_update_aura()


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


func _physics_process(delta: float) -> void:
	if held != null:
		if _grab_armed:
			_drive_held()
		else:
			_release()

	if held == null:
		# Creatures are checked first, and only if nothing is found do we look
		# for a prop, so a creature beside the bed is never blocked by the bed.
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

	# How fast the grab point is moving: what the whirr follows.
	if held != null:
		var point: Vector3 = grab_point()
		_point_speed = point.distance_to(_last_point) / maxf(delta, 0.0001)
		_last_point = point
	else:
		_point_speed = 0.0


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
	_catching = creature
	_catch_started = Time.get_ticks_msec() / 1000.0
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
	_last_point = point  # so the first tick doesn't read as a jump


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
	# A creature is removed the moment it reaches the hand, which ends the
	# catch beam by itself.
	if _catching != null and not is_instance_valid(_catching):
		_catching = null
	if _catching != null and held == null:
		_draw_catch_beam()
		return
	var end_body: Prop = held
	var end_local: Vector3 = _grab_local
	var color: Color = HOLD_COLOR
	var agitation: float = 0.0
	if end_body == null and _rejected != null:
		end_body = _rejected
		end_local = _rejected_local
		color = STRAIN_COLOR
		agitation = 1.0
	if end_body == null:
		_hide_beam()
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
	_show_beam(start, control, end, color, agitation)


## The beam while a creature is being sucked in: from the hand to the
## creature as it's drawn this frame, in the creature's colour. For the first
## few hundredths of a second it shoots out from the hand and hasn't reached
## the creature yet; after that it reels the creature in, so it shortens as
## the creature comes. A slight bow keeps it looking like the same beam.
func _draw_catch_beam() -> void:
	var start: Vector3 = _camera.to_global(BEAM_ORIGIN_LOCAL)
	var target: Vector3 = _catching._visual.get_global_transform_interpolated().origin
	var reach: float = clampf((Time.get_ticks_msec() / 1000.0 - _catch_started) / CATCH_REACH_TIME, 0.0, 1.0)
	var end: Vector3 = start.lerp(target, reach)
	var control: Vector3 = start.lerp(end, 0.5) + Vector3.UP * start.distance_to(end) * 0.08
	_show_beam(start, control, end, _catching.body_color, 0.4)


## The beam's current colour, for tests.
func beam_color() -> Color:
	return _beam_material.get_shader_parameter("beam_color")


# ---------------------------------------------------------------- the look

## Builds the parts of the beam that aren't in player.tscn: the shader
## materials, the crackling filament, the glow where it meets the object,
## and the two lights it casts. They're all top_level and placed by hand
## every frame, like the ribbon, so they ignore the camera's own movement.
## They're never moved in physics ticks, so physics interpolation is off.
func _build_beam_look() -> void:
	var beam_shader: Shader = load("res://shaders/beam.gdshader")
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = beam_shader
	_beam_mesh.material_override = _beam_material
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_filament_material = ShaderMaterial.new()
	_filament_material.shader = beam_shader
	_filament_material.set_shader_parameter("filament", 1.0)
	_filament_material.set_shader_parameter("intensity", 1.5)
	_filament = MeshInstance3D.new()
	_filament.mesh = ImmediateMesh.new()
	_filament.material_override = _filament_material
	_filament.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_floating(_filament)

	_contact_material = ShaderMaterial.new()
	_contact_material.shader = load("res://shaders/glow_dot.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * CONTACT_GLOW_SIZE
	_contact_glow = MeshInstance3D.new()
	_contact_glow.mesh = quad
	_contact_glow.material_override = _contact_material
	_contact_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_floating(_contact_glow)

	_end_light = _make_light(END_LIGHT_RANGE)
	_mid_light = _make_light(MID_LIGHT_RANGE)


func _make_light(light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.omni_range = light_range
	# No shadows: cheaper, and a soft glow spilling everywhere reads better.
	light.shadow_enabled = false
	_add_floating(light)
	return light


func _add_floating(node: Node3D) -> void:
	node.top_level = true
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)


func _hide_beam() -> void:
	for node: Node3D in [_beam_mesh, _filament, _contact_glow, _end_light, _mid_light]:
		node.visible = false


## Draws the whole beam along the curve start → end (bent toward control):
## the glowing ribbon, the crackling filament, the glow at the far end and the
## lights. `agitation` is 0 when calm and 1 when straining against something
## too heavy: faster pulses, more flicker, a wilder filament.
func _show_beam(start: Vector3, control: Vector3, end: Vector3, color: Color, agitation: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_draw_ribbon(_beam_mesh.mesh as ImmediateMesh, start, control, end, GLOW_HALF_WIDTH, 0.0, 0)
	# The filament takes a new random shape a few dozen times a second. The
	# seed only changes that often, so it jumps between shapes like a spark
	# rather than wriggling smoothly.
	var crackle: int = int(now * CRACKLES_PER_SECOND)
	var jitter: float = lerpf(FILAMENT_JITTER, FILAMENT_JITTER_STRAINING, agitation)
	_draw_ribbon(_filament.mesh as ImmediateMesh, start, control, end, FILAMENT_HALF_WIDTH, jitter, crackle)

	for material: ShaderMaterial in [_beam_material, _filament_material]:
		material.set_shader_parameter("beam_color", color)
		material.set_shader_parameter("agitation", agitation)
	_contact_material.set_shader_parameter("glow_color", color)

	# The glow where the beam meets the object, swelling slightly with the pulse.
	_contact_glow.global_position = end
	_contact_glow.scale = Vector3.ONE * (1.0 + 0.12 * sin(now * 18.0))

	# The lights flicker with the beam, more when straining.
	var flicker: float = 1.0 - lerpf(0.15, 0.4, agitation) * (0.5 + 0.5 * sin(now * 53.0) * sin(now * 37.0))
	# Just off the surface, toward the hand, so it lights the object's face.
	_end_light.global_position = end + (start - end).normalized() * 0.15
	_end_light.light_color = color
	_end_light.light_energy = END_LIGHT_ENERGY * flicker
	# Halfway along the curve.
	_mid_light.global_position = 0.25 * start + 0.5 * control + 0.25 * end
	_mid_light.light_color = color
	_mid_light.light_energy = MID_LIGHT_ENERGY * flicker

	for node: Node3D in [_beam_mesh, _filament, _contact_glow, _end_light, _mid_light]:
		node.visible = true


## Builds one ribbon along a quadratic Bezier curve (start → end, pulled
## toward control) into `mesh`. ImmediateMesh is a mesh you rebuild from
## scratch each frame, like drawing on a canvas. The mesh node is top_level
## with no transform, so these vertices are plain world positions.
##
## Each vertex gets a UV: x across the ribbon (0 or 1), y along it (0 at the
## hand, 1 at the far end). The shader uses those to draw the core, the halo
## and the pulses. `jitter` pushes each point sideways by a random amount
## (none at the two ends) for the crackling filament; `seed` picks which
## random shape.
func _draw_ribbon(mesh: ImmediateMesh, start: Vector3, control: Vector3, end: Vector3,
		half_width: float, jitter: float, seed: int) -> void:
	mesh.clear_surfaces()
	# A triangle strip turns each new pair of points into two more triangles.
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var eye: Vector3 = _camera.global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in ARC_SEGMENTS + 1:
		var t: float = float(i) / ARC_SEGMENTS
		var u: float = 1.0 - t
		var point: Vector3 = u * u * start + 2.0 * u * t * control + t * t * end
		var tangent: Vector3 = 2.0 * u * (control - start) + 2.0 * t * (end - control)
		# Spread the ribbon sideways, perpendicular to both the curve and the
		# line to the eye, so it always faces the camera and never looks edge-on.
		var across: Vector3 = tangent.cross(eye - point).normalized()
		if jitter > 0.0:
			point += across * rng.randf_range(-1.0, 1.0) * jitter * sin(PI * t)
		var side: Vector3 = across * half_width
		mesh.surface_set_uv(Vector2(0.0, t))
		mesh.surface_add_vertex(point - side)
		mesh.surface_set_uv(Vector2(1.0, t))
		mesh.surface_add_vertex(point + side)
	mesh.surface_end()


# ---------------------------------------------------------------- sound

## Eases the whirr and the crackle toward how loud (and, for the whirr, how
## high) they should be right now, every rendered frame.
func _update_sound(delta: float) -> void:
	var ease: float = clampf(delta * SOUND_EASE, 0.0, 1.0)
	var swinging: float = clampf(_point_speed / SWING_FULL_SPEED, 0.0, 1.0) if held != null else 0.0
	_swing = lerpf(_swing, swinging, ease)
	var hum_target: float = db_to_linear(lerpf(HUM_STILL_DB, HUM_SWINGING_DB, _swing)) if held != null else 0.0
	_hum_gain = lerpf(_hum_gain, hum_target, ease)
	_hum.pitch_scale = lerpf(1.0, HUM_SWING_PITCH, _swing)
	_set_loop_level(_hum, _hum_gain)
	var strain_target: float = db_to_linear(STRAIN_DB) if _rejected != null else 0.0
	_strain_gain = lerpf(_strain_gain, strain_target, ease)
	_set_loop_level(_strain, _strain_gain)


## Plays a looping sound at `gain` (0 to 1), and stops it once it has faded
## to nothing, so silent loops don't keep running.
func _set_loop_level(player: AudioStreamPlayer, gain: float) -> void:
	if gain < 0.001:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play()
	player.volume_db = linear_to_db(gain)


## Keeps the glowing aura on whatever the beam has hold of: cyan on a held
## object, red on one it's straining against, none otherwise.
func _update_aura() -> void:
	var target: Prop = held if held != null else _rejected
	if _aura_prop != target:
		if is_instance_valid(_aura_prop):
			_aura_prop.clear_aura()
		_aura_prop = target
	if target != null:
		target.set_aura(HOLD_COLOR if held != null else STRAIN_COLOR)
