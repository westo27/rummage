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

var step: Step = Step.GRAB

@onready var _beam: Beam = $"../Player/Head/Camera3D/Beam"
@onready var _ping: Ping = $"../Ping"
@onready var _hud: Hud = $"../HUD"
@onready var _creature: Creature = $"../Landing/LessonCreature"
@onready var _door: AnimatableBody3D = $"../House/LandingDoor/Door"


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
	get_tree().create_timer(DONE_HINT_TIME, false).timeout.connect(_hud.hide_hint)
	open_door()


## Swings the landing door open. The door is an AnimatableBody3D whose origin
## is the hinge, so turning it swings it, and it still pushes whatever it
## meets. (Turning a parent node instead leaves its collision behind.) The tween runs in physics
## ticks, to suit physics interpolation.
func open_door() -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_door, "rotation:y", deg_to_rad(DOOR_OPEN_DEGREES), DOOR_OPEN_TIME)
