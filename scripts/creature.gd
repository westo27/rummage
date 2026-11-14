class_name Creature
extends CharacterBody3D
## A small blob that hides under/behind props, gives itself away now and then,
## bolts when uncovered, then cowers somewhere new until caught.
##
## States:
##   HIDDEN   - still and uncatchable. Watches the props around it ("covers").
##   FLEEING  - uncovered: hops out and runs away from the player.
##   SEEKING  - runs round to the far side of a nearby object, where the
##              player can't see it, and cowers there.
##   COWERING - still and trembling, catchable. Bolts again if disturbed.
##   CAPTURED - flying into the beam; removed when the animation ends.
##
## Exposed creatures (any state but HIDDEN/CAPTURED) switch on their PickZone, a
## larger invisible sphere on the "creatures" layer that the beam aims at first.

signal captured(creature: Creature)

enum State { HIDDEN, FLEEING, SEEKING, COWERING, CAPTURED }

## Hiding in a drawer: the furniture (a Drawers prop) and which of its
## drawers. The creature sits near the drawer's front, rides along as it's
## pulled, and pops out once it's open far enough. Nothing else reveals it.
@export var drawer_furniture: NodePath
@export var drawer_index: int = 0

## When false, only moving the covering object reveals this creature; flying
## objects bouncing nearby don't. Used under the bed so its gate can't be
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
## creature escapes from under them: books, bins, crates, not bed/bookcase.
const BUMPABLE_RADIUS: float = 0.5
## Give props time to settle after the scene loads before recording covers.
const SETTLE_TIME: float = 0.5
## How far away a fleeing creature will consider props to hide behind.
const HIDE_SEARCH_RADIUS: float = 5.0
## Gap between the creature and the prop it hides behind.
const HIDE_GAP: float = 0.12
## What blocks the player's view: walls, props and clutter.
const MASK_SIGHT: int = 1 | 4 | 16
## How tall the creature is above its centre, for "can the player see my top?".
const TOP_OFFSET: float = 0.048
## The ball's radius, for rolling: it turns one radian per this many metres.
const ROLL_RADIUS: float = 0.054
## Cowering creatures bob up and down happily: this high (m), this often (Hz).
const BOUNCE_HEIGHT: float = 0.021
const BOUNCE_RATE: float = 1.8
## How quickly a stopped creature rolls back upright to look at you (per s).
const SETTLE_RATE: float = 6.0
## While hidden, it now and then peeks out at you: this often, for this long.
const PEEK_GAP_MIN: float = 3.0
const PEEK_GAP_MAX: float = 8.0
const PEEK_SECONDS: float = 1.0
## While cowering, it winks at you about this often.
const WINK_GAP_MIN: float = 2.5
const WINK_GAP_MAX: float = 6.0
## How long a creature passes through a cover that's being lifted off it.
const ESCAPE_SECONDS: float = 1.0
## When found: eyes wide with surprise, then a cheeky squint as it bolts.
const STARTLED_SECONDS: float = 0.35
const CHEEKY_SECONDS: float = 0.6
## How far a drawer must be pulled out (m) before a creature in it pops out:
## far enough that it's clear of the furniture above.
const DRAWER_REVEAL_OUT: float = 0.2
## How far from the drawer's centre toward its front the creature sits (m).
const DRAWER_FRONT_OFFSET: float = 0.09
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
## Which way to go round an obstacle that's dead ahead (+1 or -1).
var _detour_sign: float = 1.0
var _base_pitch: float = 1.0
## Picked at random when the creature spawns. The HUD's marble bag uses it so
## the ball that drops in is the same colour as the creature you caught.
var body_color: Color = Color.WHITE
## Time spent cowering, for the bounce, and a random offset so a group of
## them doesn't bob in step.
var _bounce_time: float = 0.0
var _peek_next: float = 0.0
var _peek_left: float = 0.0
var _wink_next: float = 0.0
## Set when hiding in a drawer (see drawer_furniture).
var _furniture: Prop = null
var _drawer: Prop = null
## Where the creature sits, in the drawer's own coordinates.
var _drawer_spot: Transform3D
## Seconds left heading straight out of the drawer before it starts steering
## away from the player (which could mean back through the furniture).
var _escape_left: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _eyes: CreatureEyes = $Visual/Eyes
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
	_peek_next = randf_range(PEEK_GAP_MIN, PEEK_GAP_MAX)
	_wink_next = randf_range(WINK_GAP_MIN, WINK_GAP_MAX)
	if not drawer_furniture.is_empty():
		# Deferred so the furniture has found its drawers (its own _ready).
		_settle_in_drawer.call_deferred()


## Moves into the drawer: sitting on its floor, toward the front.
func _settle_in_drawer() -> void:
	# get_node_or_null: tests load the creatures without the furniture. Then
	# it's just an ordinary hidden creature.
	_furniture = get_node_or_null(drawer_furniture) as Prop
	if _furniture == null:
		return
	_drawer = _furniture.drawers[drawer_index]
	var floor_shape := _drawer.get_node("FloorShape") as CollisionShape3D
	var floor_top: float = floor_shape.position.y + (floor_shape.shape as BoxShape3D).size.y * 0.5
	var radius: float = ((get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D).radius
	var spot := Vector3(0.0, floor_top + radius + 0.003, DRAWER_FRONT_OFFSET)
	_drawer_spot = Transform3D(Basis.IDENTITY, spot)
	global_transform = _drawer.global_transform * _drawer_spot
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_update_eyes(delta)
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

## The eyes carry the creature's character (see creature_eyes.gd). Hidden, it
## peeks out at you now and then; once found, it keeps an eye on you as it
## runs, and winks while it waits to be caught.
func _update_eyes(delta: float) -> void:
	match state:
		State.HIDDEN:
			_peek_next -= delta
			if _peek_next <= 0.0:
				_peek_next = randf_range(PEEK_GAP_MIN, PEEK_GAP_MAX)
				_peek_left = PEEK_SECONDS
			_peek_left = maxf(_peek_left - delta, 0.0)
			_eyes.look_target = _player_eye() if _peek_left > 0.0 else Vector3.ZERO
		State.FLEEING, State.SEEKING:
			_eyes.look_target = _player_eye()
		State.COWERING:
			_eyes.look_target = _player_eye()
			_wink_next -= delta
			if _wink_next <= 0.0:
				_wink_next = randf_range(WINK_GAP_MIN, WINK_GAP_MAX)
				_eyes.wink()
		State.CAPTURED:
			_eyes.look_target = Vector3.ZERO
	_eyes.step(delta)


func _update_hidden(delta: float) -> void:
	if _drawer != null:
		_update_in_drawer(delta)
		return
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


## Rides the drawer, and pops out when it's pulled open. Knocks and nearby
## props don't count: it's shut in, and would be stuck if it bolted.
func _update_in_drawer(delta: float) -> void:
	global_transform = _drawer.global_transform * _drawer_spot
	if _furniture.drawer_out(drawer_index) > DRAWER_REVEAL_OUT:
		_pop_out_of_drawer()
		return
	_tell_left -= delta
	if _tell_left <= 0.0:
		_tell_left = randf_range(Game.tune.tell_interval_min, Game.tune.tell_interval_max)
		# Only tells that fit in a drawer: no hop, no shuffling a cover.
		squeak(1.0)
		_eyes.glint()
		flash()


func _pop_out_of_drawer() -> void:
	# Through the drawer and the furniture for a moment, so the front panel
	# doesn't catch it on the way up and out.
	for body: Prop in [_drawer, _furniture]:
		add_collision_exception_with(body)
		get_tree().create_timer(ESCAPE_SECONDS, false, true).timeout.connect(
			func() -> void:
				if is_instance_valid(body) and is_inside_tree():
					remove_collision_exception_with(body))
	var out_dir: Vector3 = _flat(_drawer.global_basis.z)
	_drawer = null
	_reveal()
	# Out over the front of the drawer, higher than a normal startled hop.
	_flee_dir = out_dir
	velocity = out_dir * Game.tune.flee_speed + Vector3.UP * Game.tune.pop_speed * 1.2
	_escape_left = 0.6


func _update_fleeing(delta: float) -> void:
	_state_left -= delta
	if _escape_left > 0.0:
		_escape_left -= delta
		_move(_flee_dir, Game.tune.flee_speed, delta)
		return
	# Turn gradually toward "away from the player", so it curves rather than snaps.
	var away: Vector3 = _away_from_player()
	if _flee_dir.dot(away) < -0.9:
		# Blending between two directions can't turn one that points straight
		# back the other way: halfway between them is still the same line. A
		# sideways nudge first gives the turn a side to swing round.
		_flee_dir = _flat(_flee_dir + away.cross(Vector3.UP))
	_flee_dir = _flat(_flee_dir.lerp(away, 3.0 * delta))
	if is_on_wall():
		# Slide along the wall and push off it a little, so it doesn't stick.
		var normal: Vector3 = _flat(get_wall_normal())
		_flee_dir = _flat(_flee_dir.slide(normal) + normal * 0.5)
	_move(_flee_dir, Game.tune.flee_speed, delta)
	if _state_left <= 0.0:
		_start_seeking()


func _update_seeking(delta: float) -> void:
	_state_left -= delta
	if not is_instance_valid(_seek_target) or _seek_target.is_held:
		_start_cowering()
		return
	# Recomputed every tick, because "behind" depends on where the player is now.
	var to_target: Vector3 = _hide_point(_seek_target, _player_eye()) - global_position
	to_target.y = 0.0
	if to_target.length() < 0.12 or _state_left <= 0.0:
		_start_cowering()
		return
	var dir: Vector3 = to_target.normalized()
	if is_on_wall():
		# move_and_slide already slides along whatever we bumped, but if we're
		# running straight into it that leaves no sideways motion, so pick a side.
		var normal: Vector3 = _flat(get_wall_normal())
		var along: Vector3 = dir.slide(normal)
		if along.length() < 0.3:
			along = normal.cross(Vector3.UP) * _detour_sign
		dir = _flat(along)
	_move(dir, Game.tune.flee_speed * 0.7, delta)


func _update_cowering(delta: float) -> void:
	_move(Vector3.ZERO, 0.0, delta)  # just gravity, in case it's on something
	# A happy bounce, and roll back upright to look at the player. Done here in
	# the physics tick rather than per frame because physics interpolation only
	# expects transforms to change in ticks.
	_bounce_time += delta
	_visual.position.y = absf(sin(_bounce_time * BOUNCE_RATE * PI)) * BOUNCE_HEIGHT
	var player := _player()
	if player != null:
		var to_player: Vector3 = _flat(player.global_position - global_position)
		if to_player.length() > 0.01:
			# Slerp turns smoothly from one orientation to another.
			var facing := Basis.looking_at(to_player, Vector3.UP)
			_visual.basis = _visual.basis.orthonormalized().slerp(facing, minf(SETTLE_RATE * delta, 1.0))
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
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
	_slip_out_of_lifted_covers()
	squeak(1.25)
	_eyes.show_mood(CreatureEyes.Mood.WIDE, STARTLED_SECONDS, CreatureEyes.Mood.SQUINT, CHEEKY_SECONDS)


## If the creature bolts while still under something (a crate it was startled in
## by a knock, say), it would be trapped inside. So it bumps small covers that
## sit over it: an upward shove applied at the edge it's running toward, which
## tips that edge up and lets it out. Big things (bed, bookcase) are left alone.
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


## A cover being lifted by the beam (an upturned crate, say) would otherwise
## scoop the creature up inside it as it pops. It passes through such covers
## for a moment while it escapes.
func _slip_out_of_lifted_covers() -> void:
	for prop: Prop in _covers:
		if not is_instance_valid(prop) or not prop.is_held:
			continue
		add_collision_exception_with(prop)
		# A timer that runs on physics ticks; when it's done, collide again.
		get_tree().create_timer(ESCAPE_SECONDS, false, true).timeout.connect(
			func() -> void:
				if is_instance_valid(prop) and is_inside_tree():
					remove_collision_exception_with(prop))


func _start_seeking() -> void:
	state = State.SEEKING
	_state_left = Game.tune.seek_time
	_seek_target = _best_hiding_prop()
	_detour_sign = 1.0 if randf() < 0.5 else -1.0


func _start_cowering() -> void:
	state = State.COWERING
	velocity = Vector3.ZERO
	_record_covers(COVER_RADIUS_COWERING)
	_check_left = CHECK_INTERVAL
	_bounce_time = randf() * 2.0


## Called by the beam. The creature is sucked into the beam's hand
## (`toward`): it turns to face it and stretches toward it as it's pulled in,
## speeding up as it goes, like being sucked through a straw. Then it emits
## `captured` and is removed.
func capture(toward: Vector3) -> void:
	if state == State.CAPTURED:
		return
	state = State.CAPTURED
	_eyes.show_mood(CreatureEyes.Mood.HAPPY, 0.0)  # and it stays happy
	_set_catchable(false)
	collision_layer = 0
	collision_mask = 0
	# Sparkles where it was caught. Added to the room rather than to the
	# creature, so they outlive it.
	CatchSparkles.burst(get_parent(), _visual.global_position + Vector3.UP * 0.05, body_color)

	var to_hand: Vector3 = toward - _visual.global_position
	if to_hand.length() > 0.01 and absf(to_hand.normalized().y) < 0.98:
		_visual.look_at(toward, Vector3.UP)  # -Z, its face, toward the hand
	# A tween animates properties over time without writing a per-frame loop.
	# Tweeners run one after another unless joined with parallel().
	# TWEEN_PROCESS_PHYSICS steps it in physics ticks, which is what physics
	# interpolation expects for anything that moves.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_visual, "global_position", toward, 0.25) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_visual, "scale", Vector3(0.5, 0.5, 2.2), 0.15)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.05)
	tween.tween_callback(_finish_capture)


func _finish_capture() -> void:
	captured.emit(self)
	# queue_free deletes the node at the end of this frame (safely, after any
	# other code still using it this frame has finished).
	queue_free()


# ---------------------------------------------------------------- tells

## A hidden creature gives itself away: always a squeak, plus one visible clue.
func _give_tell() -> void:
	squeak(1.0)
	_eyes.glint()
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
	_eyes.glint()


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


## Picks the prop to hide behind. Every nearby prop on the floor is scored by
## how far away its hiding spot is, with big penalties for spots the player can
## see from where they're standing, or that are close enough to the player to
## startle us straight away. Low things like books don't block the view, so
## they lose to anything that does.
func _best_hiding_prop() -> Prop:
	var eye: Vector3 = _player_eye()
	var player := _player()
	var best: Prop = null
	var best_score: float = INF
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop.is_held:
			continue
		# Only things standing on the floor. Anything on a shelf or a table
		# has its "spot behind" somewhere unreachable, like between a
		# bookcase and the wall. Height alone can't tell: the bottom shelf is
		# lower than a crate's middle. The cheap test first, then the sure one.
		if prop.global_position.y > prop.hold_radius + 0.25:
			continue
		if global_position.distance_to(prop.global_position) > HIDE_SEARCH_RADIUS:
			continue
		if not _stands_on_floor(prop):
			continue
		var spot: Vector3 = _hide_point(prop, eye)
		if spot == Vector3.INF:
			continue  # the far side is a wall
		var score: float = global_position.distance_to(spot)
		if not _hidden_at(spot, eye):
			score += 100.0
		if player != null and _flat_distance(spot, player.global_position) < Game.tune.startle_distance + 0.4:
			score += 50.0
		if score < best_score:
			best = prop
			best_score = score
	return best


## The spot just behind `prop` as seen from `eye`, at floor level, found by
## feeling for the prop's far surface with a ray (so long beds and thin boxes
## both work). Returns Vector3.INF if that spot is inside or past a wall.
func _hide_point(prop: Prop, eye: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var centre := Vector3(prop.global_position.x, global_position.y, prop.global_position.z)
	var away: Vector3 = _flat(centre - eye)
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	# Cast from beyond the prop back toward its centre; the first thing hit on
	# the way in is the prop's back face.
	var outside: Vector3 = centre + away * (prop.hold_radius + 1.0)
	var query := PhysicsRayQueryParameters3D.create(outside, centre, MASK_PROPS)
	var hit: Dictionary = space.intersect_ray(query)
	var spot: Vector3
	if not hit.is_empty() and hit.collider == prop:
		spot = Vector3(hit.position.x, centre.y, hit.position.z) + away * (0.09 + HIDE_GAP)
	else:
		spot = centre + away * (prop.hold_radius + HIDE_GAP)
	# Is there a wall between the prop and that spot (prop pushed against a wall)?
	var wall_query := PhysicsRayQueryParameters3D.create(centre, spot + away * 0.09, 1)
	if not space.intersect_ray(wall_query).is_empty():
		return Vector3.INF
	return spot


## True if something blocks the view from `eye` to both the middle and the top
## of a creature standing at `spot`.
func _hidden_at(spot: Vector3, eye: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for point: Vector3 in [spot, spot + Vector3.UP * TOP_OFFSET]:
		var query := PhysicsRayQueryParameters3D.create(eye, point, MASK_SIGHT)
		if space.intersect_ray(query).is_empty():
			return false
	return true


## True if the first thing straight below the prop is the floor (or a wall),
## not another prop it's resting on.
func _stands_on_floor(prop: Prop) -> bool:
	var from: Vector3 = prop.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0,
		1 | MASK_PROPS, [prop.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and not (hit.collider is Prop)


## Where the player sees from (their head), or a point high in the room.
func _player_eye() -> Vector3:
	var player := _player()
	if player == null:
		return Vector3(0.0, 1.6, 0.0)
	var head := player.get_node_or_null("Head") as Node3D
	return head.global_position if head != null else player.global_position + Vector3.UP * 1.55


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _move(direction: Vector3, speed: float, delta: float) -> void:
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= Game.tune.gravity * delta
	var before: Vector3 = global_position
	move_and_slide()
	# Roll like a marble: turn the ball (eyes and all) about the axis that's
	# sideways to its travel, by the distance covered over its radius.
	var travelled: Vector3 = global_position - before
	travelled.y = 0.0
	if travelled.length() > 0.0005:
		var axis: Vector3 = Vector3.UP.cross(travelled.normalized())
		_visual.basis = (Basis(axis, travelled.length() / ROLL_RADIUS) * _visual.basis).orthonormalized()


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


func is_catchable() -> bool:
	return _pick_zone.collision_layer != 0


func _apply_random_color() -> void:
	var body := $Visual/Body as MeshInstance3D
	var color: Color = BODY_COLORS.pick_random()
	body_color = color
	# duplicate() so each creature gets its own colour instead of sharing one material.
	var mat := body.material_override.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	mat.emission = color
	body.material_override = mat
	_glow.light_color = color
