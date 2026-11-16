class_name Tutorial
extends Node
## The first-minute lesson on the landing, where every run starts: grab, throw,
## ping, catch. One hint at a time (the HUD shows it), each gone once you've
## done it. Catching the landing's creature swings the door open to the house.
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
## By the bed, once the lesson is over: how to get down and look under it.
const CROUCH_HINT: String = "Hold  C  to crouch"
const PRONE_HINT: String = "Hold  Z  to lie on your tummy"
## How close to the bed's middle (along the floor) the bed hints come up.
const BED_HINT_RANGE: float = 2.0

var step: Step = Step.GRAB
## Which bed hint is up ("" for none), and whether the bed lesson is over:
## it ends the first time you lie flat by the bed.
var _bed_hint: String = ""
var _bed_done: bool = false
## The last lesson hint is still on screen, so the bed hints wait.
var _done_hint_up: bool = false

@onready var _beam: Beam = $"../Player/Head/Camera3D/Beam"
@onready var _ping: Ping = $"../Ping"
@onready var _hud: Hud = $"../HUD"
@onready var _creature: Creature = $"../Landing/LessonCreature"
@onready var _door: AnimatableBody3D = $"../House/LandingDoor/Door"
@onready var _player: CharacterBody3D = $"../Player"
@onready var _bed: Node3D = $"../MainRoomProps/Bed"


func _ready() -> void:
	_beam.grabbed.connect(func(_prop: Prop) -> void: _reach(Step.THROW))
	_beam.thrown.connect(func(_prop: Prop) -> void: _reach(Step.PING))
	_ping.pinged.connect(func() -> void: _reach(Step.FIND))
	_creature.captured.connect(func(_c: Creature) -> void: _finish())
	_hud.show_hint(HINTS[step])


func _process(_delta: float) -> void:
	# The creature has no "found" signal; its state says when it's out.
	if step < Step.CATCH and is_instance_valid(_creature) \
			and _creature.state != Creature.State.HIDDEN:
		_reach(Step.CATCH)
	_update_bed_hint()


## Near the bed: "crouch", then "lie flat" once you're crouched. Walking off
## hides it; lying flat ends it for good. The bed can be dragged about, so
## this goes by where it is now.
func _update_bed_hint() -> void:
	if step != Step.DONE or _done_hint_up or _bed_done:
		return
	var want: String = ""
	var crouch: float = _player.crouch
	if crouch >= 0.99:
		_bed_done = _bed_hint != ""
	elif _near_bed():
		want = PRONE_HINT if crouch >= 0.5 else CROUCH_HINT
	if want == _bed_hint:
		return
	_bed_hint = want
	if want == "":
		_hud.hide_hint()
	else:
		_hud.show_hint(want)


func _near_bed() -> bool:
	if not is_instance_valid(_bed):
		return false
	var offset: Vector3 = _bed.global_position - _player.global_position
	offset.y = 0.0
	return offset.length() < BED_HINT_RANGE


## Moves on to `to`, unless the lesson is already past it.
func _reach(to: Step) -> void:
	if to <= step or step == Step.DONE:
		return
	step = to
	_hud.show_hint(HINTS[step])


func _finish() -> void:
	if step == Step.DONE:
		return
	step = Step.DONE
	_hud.show_hint(DONE_HINT)
	_done_hint_up = true
	get_tree().create_timer(DONE_HINT_TIME, false).timeout.connect(func() -> void:
		_hud.hide_hint()
		_done_hint_up = false)
	open_door()


## Swings the landing door open. The door is an AnimatableBody3D whose origin
## is the hinge, so turning it swings it, and it still pushes whatever it
## meets. (Turning a parent node instead leaves its collision behind.) The tween runs in physics
## ticks, to suit physics interpolation.
func open_door() -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_door, "rotation:y", deg_to_rad(DOOR_OPEN_DEGREES), DOOR_OPEN_TIME)
