class_name Creature
extends CharacterBody3D
## A small blob that hides under/behind props, gives itself away now and then,
## bolts when uncovered, then cowers somewhere new until caught.
##
## States:
##   HIDDEN   - still and uncatchable. Watches the props around it ("covers").
##   FLEEING  - uncovered: hops out and runs away from the player.
##   SEEKING  - runs to the nearest object to cower beside.
##   COWERING - still and trembling, catchable. Bolts again if disturbed.
##   CAPTURED - flying into the beam; removed when the animation ends.
##
## Exposed creatures (any state but HIDDEN/CAPTURED) switch on their PickZone, a
## larger invisible sphere on the "creatures" layer that the beam aims at first.

signal captured(creature: Creature)

enum State { HIDDEN, FLEEING, SEEKING, COWERING, CAPTURED }

## When false, only moving the covering object reveals this creature; flying
## objects bouncing nearby don't. Used under the sofa so its gate can't be
## skipped by throwing things at it.
@export var reveal_on_knock: bool = true

const LAYER_CREATURES: int = 8
const MASK_PROPS: int = 4 | 16  # heavy props and light "clutter" props
## How far around a hidden creature to look for the props that cover it.
const COVER_RADIUS_HIDDEN: float = 0.3
## Cowering creatures watch a wider area, so things landing near them count.
const COVER_RADIUS_COWERING: float = 0.6
## Hidden creatures check their covers 10 times a second, not every tick.
const CHECK_INTERVAL: float = 0.1
## Covers no bigger than this (their hold_radius) get bumped aside when the
## creature escapes from under them: books, bins, crates, not sofa/bookcase.
const BUMPABLE_RADIUS: float = 0.5
## Give props time to settle after the scene loads before recording covers.
const SETTLE_TIME: float = 0.5
const BODY_COLORS: Array[Color] = [
	Color(0.45, 0.95, 0.4), Color(1.0, 0.55, 0.75), Color(1.0, 0.85, 0.25),
	Color(0.45, 0.8, 1.0), Color(0.85, 0.55, 1.0), Color(1.0, 0.6, 0.3),
]

var state: State = State.HIDDEN

## Each nearby prop → its transform when we started watching it.
var _covers: Dictionary = {}
var _covers_recorded: bool = false
var _check_left: float = SETTLE_TIME
var _tell_left: float = 0.0
var _state_left: float = 0.0
var _flee_dir: Vector3 = Vector3.ZERO
var _seek_target: Prop = null
var _base_pitch: float = 1.0

@onready var _visual: Node3D = $Visual
@onready var _pick_zone: Area3D = $PickZone
@onready var _glow: OmniLight3D = $Glow
@onready var _voice: AudioStreamPlayer3D = $Voice


func _ready() -> void:
	add_to_group("creatures")
	_tell_left = randf_range(Game.tune.tell_interval_min, Game.tune.tell_interval_max)
	_base_pitch = randf_range(0.85, 1.35)
	_voice.stream = Tones.squeak()
	_voice.volume_db = Game.tune.squeak_volume_db
	_apply_random_color()


func _physics_process(delta: float) -> void:
	match state:
		State.HIDDEN:
			_update_hidden(delta)
		State.FLEEING:
			_update_fleeing(delta)
		State.SEEKING:
			_update_seeking(delta)
		State.COWERING:
			_update_cowering(delta)
		State.CAPTURED:
			return
	if global_position.y < Game.tune.fall_reset_y:
		global_position = Vector3(0.0, 0.3, 0.0)
		velocity = Vector3.ZERO
		reset_physics_interpolation()  # teleport: don't draw a glide


# ---------------------------------------------------------------- states

func _update_hidden(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		if not _covers_recorded:
			_record_covers(COVER_RADIUS_HIDDEN)
			_covers_recorded = true
		elif _is_disturbed():
			_reveal()
			return

	_tell_left -= delta
	if _tell_left <= 0.0:
		_tell_left = randf_range(Game.tune.tell_interval_min, Game.tune.tell_interval_max)
		_give_tell()


func _update_fleeing(delta: float) -> void:
	_state_left -= delta
	# Turn gradually toward "away from the player", so it curves rather than snaps.
	_flee_dir = _flat(_flee_dir.lerp(_away_from_player(), 3.0 * delta))
	if is_on_wall():
		# Slide along the wall and push off it a little, so it doesn't stick.
		var normal: Vector3 = _flat(get_wall_normal())
		_flee_dir = _flat(_flee_dir.slide(normal) + normal * 0.5)
	_move(_flee_dir, Game.tune.flee_speed, delta)
	if _state_left <= 0.0:
		_start_seeking()


func _update_seeking(delta: float) -> void:
	_state_left -= delta
	if not is_instance_valid(_seek_target):
		_start_cowering()
		return
	var to_target: Vector3 = _seek_target.global_position - global_position
	to_target.y = 0.0
	var arrived: bool = to_target.length() < _seek_target.hold_radius + 0.2
	# Bumping into anything also counts as "found somewhere".
	if arrived or is_on_wall() or _state_left <= 0.0:
		_start_cowering()
		return
	_move(to_target.normalized(), Game.tune.flee_speed * 0.7, delta)


func _update_cowering(delta: float) -> void:
	_move(Vector3.ZERO, 0.0, delta)  # just gravity, in case it's on something
	# Tremble (visual only). Done here in the physics tick rather than per frame
	# because physics interpolation only expects transforms to change in ticks.
	_visual.position = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 0.01
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var player := _player()
	var too_close: bool = player != null and \
		global_position.distance_to(player.global_position) < Game.tune.startle_distance
	if too_close or _is_disturbed():
		_reveal()


# ---------------------------------------------------------------- transitions

func _reveal() -> void:
	state = State.FLEEING
	_set_catchable(true)
	_visual.position = Vector3.ZERO
	_state_left = randf_range(Game.tune.flee_time_min, Game.tune.flee_time_max)
	_flee_dir = _away_from_player()
	velocity = _flee_dir * Game.tune.flee_speed + Vector3.UP * Game.tune.pop_speed
	_bump_covers_out_of_the_way()
	squeak(1.25)


## If the creature bolts while still under something (a crate it was startled in
## by a knock, say), it would be trapped inside. So it bumps small covers that
## sit over it: an upward shove applied at the edge it's running toward, which
## tips that edge up and lets it out. Big things (sofa, bookcase) are left alone.
func _bump_covers_out_of_the_way() -> void:
	for prop: Prop in _covers:
		if not is_instance_valid(prop) or prop.is_held or prop.hold_radius > BUMPABLE_RADIUS:
			continue
		var offset: Vector3 = prop.global_position - global_position
		var above: bool = offset.y > 0.0
		var over: bool = Vector2(offset.x, offset.z).length() < 0.35
		if above and over:
			var shove: Vector3 = (Vector3.UP * 3.0 + _flee_dir * 1.0) * prop.mass
			# apply_impulse's second argument is where on the body to push,
			# relative to its centre; pushing off-centre also makes it tip.
			prop.apply_impulse(shove, _flee_dir * 0.2)


func _start_seeking() -> void:
	state = State.SEEKING
	_state_left = Game.tune.seek_time
	_seek_target = _nearest_prop()


func _start_cowering() -> void:
	state = State.COWERING
	velocity = Vector3.ZERO
	_record_covers(COVER_RADIUS_COWERING)
	_check_left = CHECK_INTERVAL


## Called by the beam. Flies into the beam's origin (`toward`), then is removed.
func capture(toward: Vector3) -> void:
	if state == State.CAPTURED:
		return
	state = State.CAPTURED
	_set_catchable(false)
	collision_layer = 0
	collision_mask = 0
	# A tween animates properties over time without writing a per-frame loop.
	# set_parallel runs both animations at once; chain() then waits for them.
	# TWEEN_PROCESS_PHYSICS steps it in physics ticks, which is what physics
	# interpolation expects for anything that moves.
	var tween := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_visual, "global_position", toward, 0.25)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.15, 0.25)
	tween.chain().tween_callback(_finish_capture)


func _finish_capture() -> void:
	captured.emit(self)
	# queue_free deletes the node at the end of this frame (safely, after any
	# other code still using it this frame has finished).
	queue_free()


# ---------------------------------------------------------------- tells

## A hidden creature gives itself away: always a squeak, plus one visible clue.
func _give_tell() -> void:
	squeak(1.0)
	match randi() % 3:
		0:
			var cover: Prop = _nearest_cover()
			if cover != null:
				cover.shudder()
			else:
				hop()
		1:
			flash()
		2:
			hop()


## Called by the ping (Q): squeak and glow, without revealing.
func answer_ping() -> void:
	if state != State.HIDDEN:
		return
	squeak(1.1)
	flash()


func squeak(pitch: float) -> void:
	_voice.pitch_scale = _base_pitch * pitch
	_voice.play()


## A pulse of coloured light. Lights without shadows shine through objects, so
## the glow shows on the floor and on whatever is covering the creature.
func flash() -> void:
	_glow.visible = true
	var tween := create_tween()
	tween.tween_property(_glow, "light_energy", 2.5, 0.12)
	tween.tween_property(_glow, "light_energy", 0.0, 0.5)
	tween.tween_callback(_glow.hide)


func hop() -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_visual, "position:y", 0.08, 0.1)
	tween.tween_property(_visual, "position:y", 0.0, 0.12)


# ---------------------------------------------------------------- helpers

## Remembers which props are around us now, and where they are.
func _record_covers(radius: float) -> void:
	_covers.clear()
	for prop in _props_near(radius):
		_covers[prop] = prop.global_transform


func _is_disturbed() -> bool:
	for prop: Prop in _covers:
		if not is_instance_valid(prop):
			continue
		if prop.is_held:
			return true
		var before: Transform3D = _covers[prop]
		if prop.global_position.distance_to(before.origin) > Game.tune.disturb_distance:
			return true
		# Tipped or turned by more than ~8 degrees also counts.
		if prop.global_basis.y.angle_to(before.basis.y) > 0.15 or prop.global_basis.z.angle_to(before.basis.z) > 0.15:
			return true
	if reveal_on_knock or state != State.HIDDEN:
		# Knocks: a cover that's been jolted (suddenly moving, even if it hasn't
		# gone far yet), or anything flying past close by.
		for prop: Prop in _covers:
			if is_instance_valid(prop) and prop.linear_velocity.length() > Game.tune.jolt_speed:
				return true
		for prop in _props_near(COVER_RADIUS_HIDDEN + 0.3):
			if prop.linear_velocity.length() > Game.tune.knock_speed:
				return true
	return false


## Asks the physics engine which props overlap a sphere around us. This is a
## one-off query, cheaper than keeping an Area3D permanently watching.
func _props_near(radius: float) -> Array[Prop]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = MASK_PROPS
	var found: Array[Prop] = []
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var prop := hit.collider as Prop
		if prop != null and not found.has(prop):
			found.append(prop)
	return found


func _nearest_cover() -> Prop:
	var best: Prop = null
	for prop: Prop in _covers:
		if is_instance_valid(prop) and (best == null or \
				global_position.distance_to(prop.global_position) < global_position.distance_to(best.global_position)):
			best = prop
	return best


## The closest prop on or near the floor that isn't being held.
func _nearest_prop() -> Prop:
	var best: Prop = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop.is_held or prop.global_position.y > 1.2:
			continue
		var d: float = global_position.distance_to(prop.global_position)
		if d < best_distance:
			best = prop
			best_distance = d
	return best


func _move(direction: Vector3, speed: float, delta: float) -> void:
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= Game.tune.gravity * delta
	move_and_slide()
	if direction.length() > 0.1:
		# Face where we're running. The eyes are on the Visual's -Z side.
		_visual.rotation.y = atan2(-direction.x, -direction.z)


func _away_from_player() -> Vector3:
	var player := _player()
	if player == null:
		return Vector3.FORWARD
	var away: Vector3 = _flat(global_position - player.global_position)
	return away if away != Vector3.ZERO else Vector3.FORWARD


## Horizontal, unit-length version of a vector (or zero).
func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _set_catchable(on: bool) -> void:
	_pick_zone.collision_layer = LAYER_CREATURES if on else 0


func _apply_random_color() -> void:
	var body := $Visual/Body as MeshInstance3D
	var color: Color = BODY_COLORS.pick_random()
	# duplicate() so each creature gets its own colour instead of sharing one material.
	var mat := body.material_override.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	body.material_override = mat
	_glow.light_color = color
