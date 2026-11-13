extends Node3D
## Root of the main scene and the game's flow: physics setup, wiring systems to
## the HUD, counting catches, the timer, gate announcements, winning, restart.

@onready var _beam: Beam = $Player/Head/Camera3D/Beam
@onready var _hud: Hud = $HUD
@onready var _ping: Ping = $Ping

var _caught: int = 0
var _total_creatures: int = 0
var _elapsed: float = 0.0
var _won: bool = false
## Props too heavy to lift at the start (the sofa and wardrobe). When the lift
## limit first reaches one, the HUD announces it, then it's removed from here.
var _locked_props: Array[Prop] = []


# Godot calls _ready on children before their parent, so by the time this runs
# the beam, HUD, props and creatures have already set themselves up.
func _ready() -> void:
	# Gravity for rigid bodies lives on the physics "space" (the simulated world),
	# not on each body. Setting it here means the value comes from tunables.tres
	# instead of a second copy in Project Settings.
	var space: RID = get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, Game.tune.gravity)

	# connect() subscribes a function to a signal: whenever the beam emits
	# aim_changed, hud.set_aim is called with the same arguments.
	_beam.aim_changed.connect(_hud.set_aim)
	_beam.lift_limit_changed.connect(_hud.set_lift_limit)
	_ping.cooldown_changed.connect(_hud.set_ping_cooldown)
	_hud.set_lift_limit(_beam.lift_limit)

	# Each creature added itself to the "creatures" group in its own _ready.
	for creature: Creature in get_tree().get_nodes_in_group("creatures"):
		creature.captured.connect(_on_creature_captured)
		_total_creatures += 1
	_hud.set_caught(_caught, _total_creatures)

	for prop: Prop in get_tree().get_nodes_in_group("props"):
		if prop.mass > _beam.lift_limit:
			_locked_props.append(prop)


func _process(delta: float) -> void:
	if not _won:
		_elapsed += delta
		_hud.set_time(_elapsed)


# _unhandled_input only receives events nothing else (such as UI) has consumed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# Throws away the whole scene tree under Main and loads it fresh from the
		# .tscn file. The Game autoload is not part of the scene, so it survives.
		get_tree().reload_current_scene()


func _on_creature_captured(_creature: Creature) -> void:
	_caught += 1
	_beam.add_lift(Game.tune.lift_per_capture)
	_hud.set_caught(_caught, _total_creatures)
	_announce_unlocked_props()
	if _caught >= _total_creatures:
		_won = true
		_end_play()
		_hud.show_win(_elapsed, _total_creatures)


## Once everything is caught the win screen has buttons to click, so stop the
## things that would otherwise react to the mouse or Esc: the player (who
## recaptures the cursor on any click), the beam (which grabs on click) and the
## pause menu. R still restarts, because that's handled here.
func _end_play() -> void:
	$Player.set_process_input(false)
	_beam.set_process_unhandled_input(false)
	$PauseMenu.set_process_unhandled_input(false)


func _announce_unlocked_props() -> void:
	# Loop over a copy, because we remove items from the real list as we go.
	for prop in _locked_props.duplicate():
		if prop.mass <= _beam.lift_limit:
			_locked_props.erase(prop)
			_hud.show_toast("Your beam can lift the %s now  (%.0f kg)" % [prop.name.to_lower(), prop.mass])
