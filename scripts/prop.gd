class_name Prop
extends RigidBody3D
## Any physics object the beam can pick up, or try to.
##
## The beam (beam.gd) does the moving; this script only keeps per-object state:
## whether it's held, the "too heavy" shudder, and the temporary rule that a
## held object passes through the player.
##
## Each prop scene (scenes/props/*.tscn) is a RigidBody3D with this script and
## plain MeshInstance3D + CollisionShape3D children built from boxes/spheres.

## Roughly how far the object sticks out from its centre. The beam holds it at
## least this much further away, so a bed doesn't fill your view.
@export var hold_radius: float = 0.3
## 0 = every copy looks identical. Higher = random colour variety per copy,
## which makes a row of books readable as separate objects.
@export var tint_variation: float = 0.0
## Stops the object tipping over (it can still slide and turn) until the beam
## first lifts it. Used for the bed and wardrobe, so a lucky throw can't topple
## a gated object and skip the gate.
@export var keep_upright_until_grabbed: bool = false
## Holds it fixed in place (a static body) until the beam first lifts it:
## pictures on the wall, and the wardrobe, so pulling its doors can't drag it
## off the doorway before its gate opens.
@export var frozen_until_grabbed: bool = false
## What it's made of, which picks its knock when it hits something.
@export var impact_material: Tones.ImpactMaterial = Tones.ImpactMaterial.WOOD

## Collision layer bit values: layer N has value 2^(N-1). See NOTES.md.
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_PROPS: int = 4
const LAYER_CLUTTER: int = 16
const LAYER_RUG: int = 32

const SHUDDER_SECONDS: float = 0.35
const SHUDDER_AMOUNT: float = 0.035
## At most one knock per object this often (seconds), so a box rattling on
## the floor doesn't buzz.
const KNOCK_COOLDOWN: float = 0.07
## No knocks for this long after the room loads, while everything settles.
const QUIET_AFTER_LOAD: float = 1.2

var is_held: bool = false
## Where it stood when the beam first took hold of it. Furniture can only be
## dragged a short way from here (Game.tune.drag_range).
var home: Vector3
var _has_home: bool = false
## For a moving part (a drawer, a door): the furniture it's jointed to.
var part_of: Prop = null
## How many held parts are pinning this furniture down (see plant()), and
## whether it was already frozen before the first one did.
var _plant_count: int = 0
var _was_frozen: bool = false

## How hard the contacts were pushing last physics tick. A knock is a sudden
## jump above this, so steady pushes (resting on the floor, being dragged
## along it) make no sound however hard they press.
var _last_contact_push: float = 0.0
var _knock_ready_at: float = 0.0
## A hit is gathered over a few ticks before it's played, because something
## big lands corner by corner rather than all at once. While gathering:
## ticks left, the push it was resting with before the hit, and the extra
## push added up so far.
var _gather_ticks: int = 0
var _gather_baseline: float = 0.0
var _gather_total: float = 0.0

const AURA_SHADER: Shader = preload("res://shaders/beam_aura.gdshader")
## How much bigger the aura blob is than the object: a share of its size,
## plus a fixed margin in metres, so small things still get a visible halo.
const AURA_GROWTH: float = 1.35
const AURA_PADDING: float = 0.25

var _meshes: Array[MeshInstance3D] = []
## The aura blob, made the first time the beam needs it.
var _aura: MeshInstance3D = null
var _mesh_rest_positions: Array[Vector3] = []
var _shudder_left: float = 0.0
var _shudder_scale: float = 1.0
## The player body we are currently ignoring collisions with, if any.
var _ignored_body: PhysicsBody3D = null


func _ready() -> void:
	# Groups are tags: any script can later ask for get_tree().get_nodes_in_group("props").
	add_to_group("props")
	_assign_collision_layer()
	for child in get_children():
		if child is MeshInstance3D:
			_meshes.append(child)
			_mesh_rest_positions.append(child.position)
	if tint_variation > 0.0:
		_apply_random_tint()
	if frozen_until_grabbed:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
	if keep_upright_until_grabbed:
		axis_lock_angular_x = true
		axis_lock_angular_z = true
	# Contacts are only reported to _integrate_forces with monitoring on.
	contact_monitor = true
	max_contacts_reported = 4
	_knock_ready_at = _now() + QUIET_AFTER_LOAD
	# _physics_process runs every tick once enabled. Most props sit still, so it
	# stays off until a shudder or a player-collision check needs it.
	set_physics_process(false)


## Wraps the object in the beam's glowing aura (shaders/beam_aura.gdshader),
## in `color`. Called by the beam while it holds or strains against this.
## The aura is a soft ellipsoid fitted round the object, made the first time
## it's needed. As a child it moves with the object by itself.
func set_aura(color: Color) -> void:
	if _aura == null:
		_aura = _make_aura()
	(_aura.material_override as ShaderMaterial).set_shader_parameter("glow_color", color)
	_aura.visible = true


func clear_aura() -> void:
	if _aura != null:
		_aura.visible = false


## An ellipsoid a bit bigger than the object in every direction, centred on
## it: the box around all its parts, scaled up and padded.
func _make_aura() -> MeshInstance3D:
	var bounds := AABB()
	for i in _meshes.size():
		var part: AABB = _meshes[i].transform * _meshes[i].get_aabb()
		bounds = part if i == 0 else bounds.merge(part)
	var sphere := SphereMesh.new()  # a ball 1 m across, stretched to fit below
	sphere.radius = 0.5
	sphere.height = 1.0
	var material := ShaderMaterial.new()
	material.shader = AURA_SHADER
	var aura := MeshInstance3D.new()
	aura.name = "Aura"
	aura.mesh = sphere
	aura.material_override = material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = bounds.get_center()
	aura.scale = bounds.size * AURA_GROWTH + Vector3.ONE * AURA_PADDING
	add_child(aura)
	return aura


## Called by the beam when it picks this object up.
func start_hold(holder: PhysicsBody3D) -> void:
	is_held = true
	if not _has_home:
		home = global_position
		_has_home = true
	freeze = false
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	# A collision exception means "these two bodies pass through each other".
	# Set on both sides to be certain neither one pushes the other.
	_ignored_body = holder
	add_collision_exception_with(holder)
	holder.add_collision_exception_with(self)


## Why the beam can't lift this right now, whatever its weight, or "" if it
## can. The rug's grip says so while something heavy stands on the rug.
func why_stuck() -> String:
	return ""


## Called by the beam just before it grabs this, with the spot it grabs.
## Does nothing here; the rug's grip uses it to jump to that spot.
func prepare_grab(_point: Vector3) -> void:
	pass


## For props with moving parts that are bodies of their own, joined on by a
## joint (the bedside table's drawer, the wardrobe's doors). A physics body
## under another would be dragged about by its parent's transform as well as
## by physics; top_level cuts that tie, keeping the part where it is.
func _detach_part(part: Node3D) -> void:
	var placed: Transform3D = part.global_transform
	part.top_level = true
	part.global_transform = placed
	part.reset_physics_interpolation()
	if part is Prop:
		(part as Prop).part_of = self


## Holds this furniture fixed (a static body) while the beam has one of its
## parts but couldn't lift the furniture itself, so pulling a drawer can't
## drag or tip a table that's too heavy for you. unplant() undoes it.
func plant() -> void:
	if _plant_count == 0:
		_was_frozen = freeze
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
	_plant_count += 1


func unplant() -> void:
	_plant_count = maxi(_plant_count - 1, 0)
	if _plant_count == 0 and not _was_frozen:
		freeze = false
		sleeping = false


## Called by the beam when it lets go (dropped, thrown, or snapped off).
func end_hold() -> void:
	is_held = false
	# Don't restore collisions with the player straight away: if the object is
	# overlapping them, the physics engine would shove the two apart violently.
	# _physics_process restores it once the object is clear of the player.
	set_physics_process(true)


## The "too heavy" wobble. Only the meshes move, not the body, so trying to lift
## the bed can't nudge it and disturb what's hiding under it.
## amount scales how hard it shakes (a marble's bump is gentler than the beam).
func shudder(amount: float = 1.0) -> void:
	_shudder_left = SHUDDER_SECONDS
	_shudder_scale = amount
	set_physics_process(true)


# Runs only while there's something to do (see the end), then switches itself off.
# The shudder is done here in the physics tick rather than per frame because
# physics interpolation (see player.gd) only expects transforms to change in ticks.
func _physics_process(delta: float) -> void:
	if _shudder_left > 0.0:
		_update_shudder(delta)
	if _ignored_body != null and not is_held:
		_restore_player_collision_when_clear()
	var waiting_for_player: bool = _ignored_body != null and not is_held
	if _shudder_left <= 0.0 and not waiting_for_player:
		set_physics_process(false)


## Called by the physics engine during each step, for awake bodies only, with
## that step's contacts. Used here just to listen for hits.
##
## Each contact reports the impulse (push) it gave this tick. Divided by
## mass, pushes measure how much a hit changed the object's velocity, so a
## book and a wardrobe are on the same scale.
##
## A hit starts when the push jumps sharply above what it was the tick
## before. From then, the extra push over the next GATHER_TICKS ticks is
## added up and played as one knock, so a bed landing leg by leg sounds as
## hard as it really was.
const GATHER_TICKS: int = 3


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var push: float = 0.0
	for i in state.get_contact_count():
		push += state.get_contact_impulse(i).length()
	var jump: float = (push - _last_contact_push) / mass
	_last_contact_push = push

	if _gather_ticks > 0:
		_gather_total += maxf(push - _gather_baseline, 0.0)
		_gather_ticks -= 1
		if _gather_ticks == 0:
			Game.impacts.play(impact_material, state.transform.origin, _gather_total / mass, mass)
		return

	if jump < Game.tune.impact_min_speed:
		return
	var now: float = _now()
	if now < _knock_ready_at:
		return
	_knock_ready_at = now + KNOCK_COOLDOWN
	_gather_baseline = push - jump * mass  # what it was pushing with before
	_gather_total = push - _gather_baseline
	_gather_ticks = GATHER_TICKS - 1


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _update_shudder(delta: float) -> void:
	_shudder_left -= delta
	var strength: float = maxf(_shudder_left, 0.0) / SHUDDER_SECONDS * SHUDDER_AMOUNT * _shudder_scale
	for i in _meshes.size():
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength
		_meshes[i].position = _mesh_rest_positions[i] + jitter


func _restore_player_collision_when_clear() -> void:
	var player_centre: Vector3 = _ignored_body.global_position + Vector3.UP * 0.85
	var clear_distance: float = hold_radius + 0.9
	if global_position.distance_to(player_centre) > clear_distance:
		remove_collision_exception_with(_ignored_body)
		_ignored_body.remove_collision_exception_with(self)
		_ignored_body = null


## Light props go on the "clutter" layer, which the player's movement ignores
## (player.gd kicks them aside instead). Without this, a 1 kg book on its edge
## stops the player dead, because a CharacterBody3D treats every rigid body as
## an immovable wall. Heavier props stay on "props" and block the player.
##
## Two bodies collide if either one's mask includes the other's layer, so the
## clutter mask must leave out the player for the player to pass through.
## This overrides the layer/mask written in the prop's .tscn.
func _assign_collision_layer() -> void:
	if mass <= Game.tune.player_push_max_mass:
		collision_layer = LAYER_CLUTTER
		collision_mask = LAYER_WORLD | LAYER_PROPS | LAYER_CLUTTER
	else:
		collision_layer = LAYER_PROPS
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_PROPS | LAYER_CLUTTER


func _apply_random_tint() -> void:
	# One random shift per object, applied to all its parts, so a crate's panels match.
	var hue_shift: float = randf_range(-tint_variation, tint_variation) * 0.5
	var value_shift: float = randf_range(-0.15, 0.15) * tint_variation
	for mesh in _meshes:
		var base := mesh.material_override as StandardMaterial3D
		if base == null:
			continue
		# Materials are shared between every copy of the scene by default, so
		# changing one would recolour them all. duplicate() gives this copy its own.
		var mat := base.duplicate() as StandardMaterial3D
		var c: Color = mat.albedo_color
		var hue: float = fposmod(c.h + hue_shift, 1.0)
		var value: float = clampf(c.v + value_shift, 0.1, 1.0)
		mat.albedo_color = Color.from_hsv(hue, c.s, value)
		mesh.material_override = mat
