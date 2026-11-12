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
## least this much further away, so a sofa doesn't fill your view.
@export var hold_radius: float = 0.3
## 0 = every copy looks identical. Higher = random colour variety per copy,
## which makes a row of books readable as separate objects.
@export var tint_variation: float = 0.0
## Stops the object tipping over (it can still slide and turn) until the beam
## first lifts it. Used for the sofa and wardrobe, so a lucky throw can't topple
## a gated object and skip the gate.
@export var keep_upright_until_grabbed: bool = false

## Collision layer bit values: layer N has value 2^(N-1). See NOTES.md.
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_PROPS: int = 4
const LAYER_CLUTTER: int = 16

const SHUDDER_SECONDS: float = 0.35
const SHUDDER_AMOUNT: float = 0.035

var is_held: bool = false

var _meshes: Array[MeshInstance3D] = []
var _mesh_rest_positions: Array[Vector3] = []
var _shudder_left: float = 0.0
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
	if keep_upright_until_grabbed:
		axis_lock_angular_x = true
		axis_lock_angular_z = true
	# These two callbacks run every frame/tick once enabled. Most props sit still,
	# so they stay off until something needs them.
	set_process(false)
	set_physics_process(false)


## Called by the beam when it picks this object up.
func start_hold(holder: PhysicsBody3D) -> void:
	is_held = true
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	# A collision exception means "these two bodies pass through each other".
	# Set on both sides to be certain neither one pushes the other.
	_ignored_body = holder
	add_collision_exception_with(holder)
	holder.add_collision_exception_with(self)
	set_physics_process(false)


## Called by the beam when it lets go (dropped, thrown, or snapped off).
func end_hold() -> void:
	is_held = false
	# Don't restore collisions with the player straight away: if the object is
	# overlapping them, the physics engine would shove the two apart violently.
	# _physics_process restores it once the object is clear of the player.
	set_physics_process(true)


## The "too heavy" wobble. Only the meshes move, not the body, so trying to lift
## the sofa can't nudge it and disturb what's hiding under it.
func shudder() -> void:
	_shudder_left = SHUDDER_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	_shudder_left -= delta
	var strength: float = maxf(_shudder_left, 0.0) / SHUDDER_SECONDS * SHUDDER_AMOUNT
	for i in _meshes.size():
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * strength
		_meshes[i].position = _mesh_rest_positions[i] + jitter
	if _shudder_left <= 0.0:
		set_process(false)


func _physics_process(_delta: float) -> void:
	if _ignored_body == null:
		set_physics_process(false)
		return
	var player_centre: Vector3 = _ignored_body.global_position + Vector3.UP * 0.85
	var clear_distance: float = hold_radius + 0.9
	if global_position.distance_to(player_centre) > clear_distance:
		remove_collision_exception_with(_ignored_body)
		_ignored_body.remove_collision_exception_with(self)
		_ignored_body = null
		set_physics_process(false)


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
