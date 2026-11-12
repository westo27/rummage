extends Node3D
## Root of the main scene. Applies world settings, connects systems to the HUD,
## and handles restart.

@onready var _beam: Beam = $Player/Head/Camera3D/Beam
@onready var _hud: Hud = $HUD

var _caught: int = 0
var _total_creatures: int = 0


# Godot calls _ready on children before their parent, so by the time this runs
# the beam and HUD have already set themselves up.
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
	_hud.set_lift_limit(_beam.lift_limit)

	# Each creature added itself to the "creatures" group in its own _ready.
	for creature: Creature in get_tree().get_nodes_in_group("creatures"):
		creature.captured.connect(_on_creature_captured)
		_total_creatures += 1
	_hud.set_caught(_caught, _total_creatures)


func _on_creature_captured(_creature: Creature) -> void:
	_caught += 1
	_beam.add_lift(Game.tune.lift_per_capture)
	_hud.set_caught(_caught, _total_creatures)


# _unhandled_input only receives events nothing else (such as UI) has consumed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		# Throws away the whole scene tree under Main and loads it fresh from the
		# .tscn file. The Game autoload is not part of the scene, so it survives.
		get_tree().reload_current_scene()
