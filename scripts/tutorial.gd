class_name Tutorial
extends Node
## The first-minute lesson on the landing, where every run starts: grab, throw,
## ping, catch. One hint at a time (the HUD shows it), each gone once you've
## done it. Catching the landing's creature swings the door open to the house,
## and it shuts behind you once you're through.
##
## Two more hints wait in the house: "crouch" at the low doorway into the
## bedroom, and "lie flat" by the bed. And once, if you go a while without
## finding anything, a reminder that you can ping.
##
## Doing things early just skips ahead: lift the bin first and you go straight
## to "catch it".

enum Step { GRAB, THROW, PING, FIND, CATCH, DONE }

const HINTS: Dictionary = {
	Step.GRAB: "Hold  Left Mouse  to grab",
	Step.THROW: "Right Mouse  or  F  to throw",
	Step.PING: "Something's hiding!  Press  Q  to ping",
	Step.FIND: "What was that?",
	Step.CATCH: "Click it to catch it!",
}
const DONE_HINT: String = "Go find them all!"
## How long the last hint stays up before fading.
const DONE_HINT_TIME: float = 4.0
## The door swings into the playroom by this much, over this long.
const DOOR_OPEN_DEGREES: float = 100.0
const DOOR_OPEN_TIME: float = 1.4
## How far into the playroom you have to be before the door shuts behind
## you: clear of its swing, measured from the hinge.
const DOOR_SHUT_CLEARANCE: float = 1.4
## Anything further south than this is on the landing. Where a creature
## caught in there when the door shuts is put back, just inside the playroom.
const LANDING_EDGE_Z: float = 2.25
const PLAYROOM_BY_DOOR: Vector3 = Vector3(-2.6, 0.3, 1.2)

## The low doorway from the playroom to the bedroom, and how near it (along
## the floor) the crouch hint comes up. Once you're this far past it, into the
## bedroom, you've learnt it.
const CROUCH_HINT: String = "Hold  C  to crouch"
const DOORWAY: Vector3 = Vector3(0.0, 0.0, 0.0)
const DOORWAY_HINT_RANGE: float = 1.8
const DOORWAY_PASSED_X: float = 0.6
## By the bed: how to get down and look under it.
const PRONE_HINT: String = "Hold  Z  to lie on your tummy"
const BED_HINT_RANGE: float = 2.0
## The ping reminder: shown once, when nothing has been found for this long
## and the ping is ready. It goes when you ping, or after a while.
const PING_HINT: String = "Press  Q  to ping"
const PING_HINT_AFTER: float = 10.0
const PING_HINT_TIME: float = 6.0

var step: Step = Step.GRAB
## The hint this script last put up ("" once it has hidden it).
var _shown: String = ""
## Which house hint is up ("" for none). Each is over for good once done:
## through the doorway, and flat on the floor by the bed.
var _house_hint: String = ""
var _crouch_done: bool = false
var _prone_done: bool = false
## The landing door is open and waiting to shut behind you.
var _door_open: bool = false
## Seconds since a creature was last found, how many are still hidden (to
## notice one being found), and whether the reminder has had its go.
var _since_found: float = 0.0
var _hidden_count: int = -1
var _ping_hint_done: bool = false

@onready var _beam: Beam = $"../Player/Head/Camera3D/Beam"
@onready var _ping: Ping = $"../Ping"
@onready var _hud: Hud = $"../HUD"
@onready var _creature: Creature = $"../Landing/LessonCreature"
@onready var _door: AnimatableBody3D = $"../House/LandingDoor/Door"
@onready var _player: CharacterBody3D = $"../Player"
## Null in a house without one.
@onready var _bed: Node3D = get_node_or_null("../MainRoomProps/Bed")


func _ready() -> void:
	_beam.grabbed.connect(func(_prop: Prop) -> void: _reach(Step.THROW))
	_beam.thrown.connect(func(_prop: Prop) -> void: _reach(Step.PING))
	_ping.pinged.connect(func() -> void: _reach(Step.FIND))
	_ping.pinged.connect(_on_pinged_in_house)
	_creature.captured.connect(func(_c: Creature) -> void: _finish())
	_show(HINTS[step])


func _process(delta: float) -> void:
	# The creature has no "found" signal; its state says when it's out.
	if step < Step.CATCH and is_instance_valid(_creature) \
			and _creature.state != Creature.State.HIDDEN:
		_reach(Step.CATCH)
	if step == Step.DONE:
		_update_door()
		_update_house_hints()
		_update_ping_hint(delta)


## Shuts the door once you're in the playroom and clear of its swing.
func _update_door() -> void:
	if not _door_open:
		return
	var hinge: Vector3 = _door.global_position
	var from_hinge: Vector3 = _player.global_position - hinge
	from_hinge.y = 0.0
	if _player.global_position.z < hinge.z - 0.15 and from_hinge.length() > DOOR_SHUT_CLEARANCE:
		shut_door()


## "Crouch" at the low doorway until you've been through it, then "lie flat"
## by the bed until you have. Walking off hides either. The bed can be dragged
## about, so that one goes by where it is now.
func _update_house_hints() -> void:
	var want: String = ""
	var crouch: float = _player.crouch
	if not _crouch_done:
		if _player.global_position.x > DOORWAY_PASSED_X:
			_crouch_done = true
		elif crouch < 0.5 and _near(DOORWAY, DOORWAY_HINT_RANGE):
			want = CROUCH_HINT
	if want == "" and not _prone_done and is_instance_valid(_bed) \
			and _near(_bed.global_position, BED_HINT_RANGE):
		if crouch >= 0.99:
			_prone_done = true
		else:
			want = PRONE_HINT
	if want == _house_hint:
		return
	_house_hint = want
	if want == "":
		_hide()
	else:
		_show(want)


## Counts up while nothing new is found. Creatures have no "found" signal, so
## this watches how many are still hidden. It waits its turn behind any other
## hint.
func _update_ping_hint(delta: float) -> void:
	if _ping_hint_done:
		return
	var hidden: int = 0
	for node in get_tree().get_nodes_in_group("creatures"):
		if (node as Creature).state == Creature.State.HIDDEN:
			hidden += 1
	if hidden != _hidden_count:
		_hidden_count = hidden
		_since_found = 0.0
	_since_found += delta
	if _since_found < PING_HINT_AFTER or hidden == 0 or not _ping.is_ready() or _shown != "":
		return
	_ping_hint_done = true
	_show(PING_HINT)
	get_tree().create_timer(PING_HINT_TIME, false).timeout.connect(func() -> void:
		if _shown == PING_HINT:
			_hide())


func _on_pinged_in_house() -> void:
	_since_found = 0.0
	if _shown == PING_HINT:
		_hide()


func _near(spot: Vector3, distance: float) -> bool:
	var offset: Vector3 = spot - _player.global_position
	offset.y = 0.0
	return offset.length() < distance


func _show(text: String) -> void:
	_shown = text
	_hud.show_hint(text)


func _hide() -> void:
	_shown = ""
	_hud.hide_hint()


## Moves on to `to`, unless the lesson is already past it.
func _reach(to: Step) -> void:
	if to <= step or step == Step.DONE:
		return
	step = to
	_show(HINTS[step])


func _finish() -> void:
	if step == Step.DONE:
		return
	step = Step.DONE
	_show(DONE_HINT)
	# Fades after a while, unless a house hint has taken its place by then.
	get_tree().create_timer(DONE_HINT_TIME, false).timeout.connect(func() -> void:
		if _shown == DONE_HINT:
			_hide())
	open_door()


## Swings the landing door open. The door is an AnimatableBody3D whose origin
## is the hinge, so turning it swings it, and it still pushes whatever it
## meets. (Turning a parent node instead leaves its collision behind.) The tween runs in physics
## ticks, to suit physics interpolation.
func open_door() -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_door, "rotation:y", deg_to_rad(DOOR_OPEN_DEGREES), DOOR_OPEN_TIME)
	_door_open = true


## Swings it shut again, for good: the landing is done with.
func shut_door() -> void:
	_door_open = false
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_door, "rotation:y", 0.0, DOOR_OPEN_TIME)
	tween.tween_callback(_clear_landing)


## A creature shut in on the landing could never be caught, so any that
## slipped in while the door was open are put back in the playroom.
func _clear_landing() -> void:
	for node in get_tree().get_nodes_in_group("creatures"):
		var creature := node as Creature
		if creature.state == Creature.State.CAPTURED or creature.global_position.z < LANDING_EDGE_Z:
			continue
		creature.global_position = PLAYROOM_BY_DOOR
		creature.velocity = Vector3.ZERO
		creature.reset_physics_interpolation()  # teleport: don't draw a glide
